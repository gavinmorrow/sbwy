import eflame
import ewe
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/result
import gleam/string
import logging
import repeatedly
import tzif/database as tzif
import wisp
import wisp/wisp_ewe

import subway_gleam/gtfs/env as gtfs_env
import subway_gleam/gtfs/st
import subway_gleam/gtfs/st/schedule_sample
import subway_gleam/server/env
import subway_gleam/server/gtfs/fetch_st
import subway_gleam/server/log
import subway_gleam/server/normalize_path_trailing_slash.{
  normalize_path_trailing_slash,
}
import subway_gleam/server/route
import subway_gleam/server/route/stop
import subway_gleam/server/route/train
import subway_gleam/server/sse_gtfs.{sse_gtfs}
import subway_gleam/server/st_extra
import subway_gleam/server/state
import subway_gleam/server/state/gtfs_store
import subway_gleam/shared/route/stop as shared_stop
import subway_gleam/shared/route/train as shared_train

pub fn main() -> Nil {
  // The application is already running by the time this is called, so all main
  // has left to do is keep the node alive.
  log.debug("Main process sleeping forever...", with: log.new_context())
  process.sleep_forever()
}

pub fn start(_type: a, _args: b) -> Result(process.Pid, actor.StartError) {
  let server = server()
  let supervisor =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(ewe.supervised(server))
    |> supervisor.start

  case supervisor {
    Ok(actor.Started(pid:, data: _)) -> Ok(pid)
    Error(reason) -> Error(reason)
  }
}

pub fn stop(_state: a) -> Atom {
  atom.create("ok")
}

// The sleeping_after parameter exists so that the server automatically shuts
// down after a given amount of time when profiling.
pub fn server() -> ewe.Builder {
  wisp.configure_logger()
  configure_logger()

  log.notice(
    "Starting sbwy...",
    with: log.context([
      #("local_gtfs_st", gtfs_env.use_local_st() |> string.inspect),
      #("local_gtfs_rt", gtfs_env.use_local_rt() |> string.inspect),
      #("save_fetched_st", gtfs_env.save_fetched_st() |> string.inspect),
      #("save_fetched_rt", gtfs_env.save_fetched_rt() |> string.inspect),
      #("gtfs_rt_fetch_time", gtfs_env.rt_time() |> string.inspect),
      #("host", env.host()),
      #("port", env.port() |> string.inspect),
      #("log_level", env.log_level() |> string.inspect),
      #("log_tz_offset", env.log_tz_offset() |> string.inspect),
      #("profile_pages", env.profile_pages() |> string.inspect),
    ]),
  )

  let assert Ok(priv_dir) = wisp.priv_directory("subway_gleam")
  let st_extra_data = st_extra.load_data()
  let assert Ok(schedule) = {
    case gtfs_env.use_local_st() {
      True -> schedule_sample.schedule()
      False ->
        fetch_st.fetch_bin(st.Regular)
        |> result.map_error(st.HttpError)
        |> result.try(st.parse(_, st_extra_data))
    }
  }
  let assert Ok(gtfs_store) = gtfs_store.new()
  let assert Ok(tz_db) = tzif.load_from_os()
  let state = state.State(priv_dir:, schedule:, gtfs_store:, tz_db:)
  let state = state.ref(from: state)

  log.debug("Setup initial state.", with: log.new_context())

  repeatedly.call(10 * 1000, Nil, fn(_state, _i) {
    let state = state.get(state)
    gtfs_store.update(state.gtfs_store)
  })

  let secret_key_base = wisp.random_string(64)
  let wisp_handler = wisp_ewe.handler(handler(state, _), secret_key_base)

  let host = env.host()
  let port = env.port()
  log.debug(
    "Starting server...",
    with: log.context([
      #("host", host),
      #("port", port |> int.to_string),
    ]),
  )

  let listener_name = process.new_name("sbwy_listener")
  let connection_factory_name = process.new_name("sbwy_connection_factory")
  let handler = ewe_handler(_, state, wisp_handler)

  ewe.new(listener_name:, connection_factory_name:, handler:)
  |> ewe.bind(to: host)
  |> ewe.with_http2(
    ewe.Http2Options(..ewe.default_http2_options(), websocket: True),
  )
  |> ewe.listening(on: port)
  |> ewe.on_start(fn(scheme, address) {
    // Mostly copied from ewe, but modified to use our log functions.
    case address {
      ewe.TcpSocketAddress(ip_address:, port:) -> {
        let host = case ip_address {
          ewe.IpV6(..) -> "[" <> ewe.ip_address_to_string(ip_address) <> "]"
          ewe.IpV4(..) -> ewe.ip_address_to_string(ip_address)
        }

        let url =
          http.scheme_to_string(scheme)
          <> "://"
          <> host
          <> ":"
          <> int.to_string(port)
        log.notice("Server listening.", log.context([#("url", url)]))
      }
      ewe.UnixSocketAddress(path:) ->
        log.notice("Server listening.", log.context([#("unix", path)]))
    }
  })
}

// This is done b/c wisp doesn't support some features (e.g. websockets,
// server-sent events). So for routes that use the features wisp does support,
// they go in the wisp handler. Otherwise, they go here.
fn ewe_handler(
  req: request.Request(ewe.Connection),
  state_ref: state.Ref,
  wisp_handler: fn(request.Request(ewe.Connection)) ->
    response.Response(ewe.Body),
) -> response.Response(ewe.Body) {
  use <- log.time("mist_handler")
  let state = state.get(state_ref)
  case request.path_segments(req) {
    // TODO: figure out some abstraction for this. also move out of this file
    ["stop", stop_id, "model_stream"] ->
      sse_gtfs(req, state_ref, fn() {
        stop.model(state, stop_id, option.None)
        |> result.map(shared_stop.model_to_json)
      })
    ["train", train_id, "model_stream"] ->
      sse_gtfs(req, state_ref, fn() {
        train.model(state, train_id, req.query)
        |> result.map(shared_train.model_to_json)
      })
    // I don't love the hard coded path but c'est la vie
    ["static", "service-worker.js"] ->
      wisp_handler(req)
      |> wisp.set_header("Service-Worker-Allowed", "/")
    _ -> wisp_handler(req)
  }
}

fn handler(state: state.Ref, req: wisp.Request) -> wisp.Response {
  use <- log.time("wisp_handler")
  use <- wisp.rescue_crashes
  use req <- wisp.csrf_known_header_protection(req)

  let state = state.get(state)

  use <- wisp.serve_static(req, under: "/static", from: state.priv_dir)

  // Only apply this to non-static files
  // 
  // Doing this because it allows routes to use relative paths to drill down
  // into details. e.g. the stop route has a link, `./alerts`, that will
  // redirect to the alerts page for the stop.
  use req <- normalize_path_trailing_slash(req)

  // TODO: pass context to routes for logging
  use req, _context <- log.request(req)

  case wisp.path_segments(req) {
    [] -> route.index(req)
    ["health"] -> route.health(req)
    ["favicon.ico"] -> wisp.redirect(to: "/static/icons/192.png")
    ["map"] -> route.map(req)
    ["stops"] ->
      case env.profile_pages() |> list.contains("stops") {
        True -> eflame.profile("stops", fn() { route.stops(req, state) })
        False -> route.stops(req, state)
      }
    ["stop", stop_id] ->
      case env.profile_pages() |> list.contains("stop") {
        True -> eflame.profile("stop", fn() { route.stop(req, state, stop_id) })
        False -> route.stop(req, state, stop_id)
      }
    ["stop", _stop_id, "alerts"] ->
      // slightly hacky, but this works b/c if the route is unrecognized, then
      // it'll show the alerts for all routes.
      wisp.permanent_redirect(to: req.path <> "all/")
    ["stop", stop_id, "alerts", route_id] ->
      case env.profile_pages() |> list.contains("stop_alerts") {
        True ->
          eflame.profile("stop_alerts", fn() {
            route.stop_alerts(req, state, stop_id, option.Some(route_id))
          })
        False -> route.stop_alerts(req, state, stop_id, option.Some(route_id))
      }
    ["train", trip_id] ->
      case env.profile_pages() |> list.contains("train") {
        True ->
          eflame.profile("train", fn() { route.train(req, state, trip_id) })
        False -> route.train(req, state, trip_id)
      }
    ["line", route_id] -> route.line(req, state, route_id)
    _ -> route.not_found(req)
  }
}

fn configure_logger() -> Nil {
  case env.log_level() {
    Ok(logging.Info) -> configure_logger_level_info()
    _ -> configure_logger_level_all()
  }
}

@external(erlang, "logger_config_ffi", "configure_level_info")
fn configure_logger_level_info() -> Nil

@external(erlang, "logger_config_ffi", "configure_level_all")
fn configure_logger_level_all() -> Nil

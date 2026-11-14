import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/pair
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/time/timestamp
import gleam/uri
import lustre/attribute
import lustre/element/html
import wisp

import subway_gleam/gtfs/rt
import subway_gleam/gtfs/st
import subway_gleam/gtfs/st/route.{type Route}
import subway_gleam/server/arrival
import subway_gleam/server/connecting_trains
import subway_gleam/server/hydration_scripts.{hydration_scripts}
import subway_gleam/server/log
import subway_gleam/server/lustre_middleware.{Document, try_lustre_res}
import subway_gleam/server/state
import subway_gleam/server/state/gtfs_store
import subway_gleam/server/time_zone
import subway_gleam/shared/component/arrival.{type Arrival} as _
import subway_gleam/shared/component/connecting_train.{type ConnectingTrain}
import subway_gleam/shared/component/route_bullet
import subway_gleam/shared/route/station
import subway_gleam/shared/util
import subway_gleam/shared/util/live_status
import subway_gleam/shared/util/time

pub fn station(
  req: wisp.Request,
  state: state.State,
  stop_id: String,
) -> wisp.Response {
  use <- log.time("station route")

  use req <- try_lustre_res(req)

  case model(state, stop_id, req.query) {
    Ok(model) -> {
      use <- log.time("post-model")

      let head = [
        html.title([], "Trains at " <> model.name),
        hydration_scripts("station", station.model_to_json(model)),
      ]
      let body = [
        html.div([attribute.id("app")], [
          station.view(model, Nil),
        ]),
      ]

      Ok(#(Document(head:, body:), wisp.response(200)))
    }
    Error(InvalidStopId(stop_id)) -> Error(error_invalid_stop_id(stop_id))
    Error(UnknownStation(stop_id)) -> Error(error_unknown_station(stop_id))
  }
}

pub fn model(
  state: state.State,
  stop_id: String,
  query: option.Option(String),
) -> Result(station.Model, Error) {
  use <- log.time("model")

  // TODO: make this a function?
  let query =
    query
    |> option.to_result(Nil)
    |> result.try(uri.parse_query)
    |> result.unwrap(or: [])
  let highlighted_train =
    query
    |> list.key_find("train_id")
    |> result.map(rt.TripId)
    |> option.from_result
  let connecting_trains = connecting_trains.from_query_params(query, state)

  use stop_id <- result.try(
    st.parse_stop_id_no_direction(stop_id)
    |> result.replace_error(InvalidStopId(stop_id)),
  )
  use station <- result.try(
    state.schedule.stations
    |> dict.get(stop_id)
    |> result.replace_error(UnknownStation(stop_id)),
  )

  let transfers =
    transfers(
      state.schedule,
      station,
      connecting_trains.to_string(connecting_trains),
    )

  let data = state.fetch_gtfs(state)

  let #(alerted_routes, alert_summary) = alerts(data, stop_id, state.schedule)
  let #(uptown, downtown) =
    arrivals(data, stop_id, state.schedule, connecting_trains)

  let cur_time = time_zone.now(state.tz_db)
  let last_updated =
    gtfs_store.last_updated(data)
    |> result.unwrap(or: timestamp.unix_epoch)
  let last_updated =
    time.Time(
      last_updated,
      state.tz_db |> time_zone.new_york_offset(at: last_updated),
    )

  Ok(station.Model(
    id: station.id,
    name: station.name,
    last_updated:,
    transfers:,
    alerted_routes:,
    alert_summary:,
    uptown:,
    downtown:,
    north_direction_label: station.north_direction_label,
    south_direction_label: station.south_direction_label,
    highlighted_train:,
    connecting_trains:,
    event_source: live_status.Unavailable,
    cur_time:,
    is_fav: False,
  ))
}

fn transfers(
  schedule: st.Schedule,
  station: st.Station,
  connecting_trains: Result(String, Nil),
) -> List(station.Transfer) {
  schedule.transfers
  |> dict.get(station.id)
  |> result.unwrap(or: set.new())
  |> set.map(fn(transfer) {
    let st.StopId(desination_id) = transfer.destination
    let routes =
      schedule
      |> st.daytime_routes(for: transfer.destination)
      |> set.map(fn(route_id) {
        let assert Ok(route) = schedule.routes |> dict.get(route_id)
        route
      })
      |> set.to_list
      |> list.sort(st.route_compare)
      |> list.map(route_bullet.from_route_data)

    let query = case connecting_trains {
      Ok(connecting_trains) -> "?connecting_trains=" <> connecting_trains
      Error(Nil) -> ""
    }
    station.Transfer(
      // TODO: url function
      destination_url: "/stop/" <> desination_id <> "/" <> query,
      routes:,
      highlighted: transfer.destination == station.id,
    )
  })
  // TODO: also need to sort each group in sort order
  |> set.to_list
}

fn alerts(
  data: gtfs_store.Data,
  stop_id: st.StopId,
  schedule: st.Schedule,
) -> #(List(route_bullet.RouteBullet), String) {
  // Add in alerts from arrivals.
  // Needed b/c if a train is rerouted then alerts from that train should be
  // shown at this station.
  let routes =
    set.union(
      of: st.daytime_routes(in: schedule, for: stop_id),
      and: gtfs_store.arrivals(data, for: stop_id) |> rt.routes_arriving,
    )

  let alerts =
    gtfs_store.alerts(data)
    |> result.map(filter_alerts(_, routes, stop_id))
    |> result.unwrap(or: [])
  let alerted_routes =
    list.fold(over: alerts, from: set.new(), with: fn(acc, alert) {
      set.union(of: acc, and: rt.routes_in_alert(alert))
    })
    |> set.map(st.route_data(in: schedule, for: _))
    |> set.to_list
    |> list.sort(by: fn(a, b) { int.compare(a.sort_order, b.sort_order) })
    |> list.map(route_bullet.from_route_data)
  let alert_summary =
    alerts
    |> list.map(fn(alert) { option.unwrap(alert.alert_type, or: "Alert") })
    |> list.unique
    |> string.join(with: ", ")
  let alert_summary = case list.length(alerts) {
    0 -> "0 Alerts"
    1 -> "1 Alert: " <> alert_summary
    num -> int.to_string(num) <> " Alerts: " <> alert_summary
  }

  #(alerted_routes, alert_summary)
}

fn arrivals(
  data: gtfs_store.Data,
  stop_id: st.StopId,
  schedule: st.Schedule,
  connecting_trains: List(ConnectingTrain),
) -> #(List(Arrival), List(Arrival)) {
  gtfs_store.arrivals(data, for: stop_id)
  |> result.unwrap(or: [])
  |> list.sort(by: fn(a, b) {
    timestamp.compare(a.1.time, b.1.time) |> order.negate
  })
  |> list.fold(from: #([], []), with: fn(acc, update) {
    let #(uptown_acc, downtown_acc) = acc
    let li =
      arrival.arrival(
        update,
        schedule,
        gtfs_store.final_stop(data, for: _),
        connecting_trains,
      )
    case update.1.direction {
      st.North -> #([li, ..uptown_acc], downtown_acc)
      st.South -> #(uptown_acc, [li, ..downtown_acc])
    }
  })
}

// TODO: do this processing for every alert as part of processing rt data.
//       it adds slightly noticable lag to each request
pub fn filter_alerts(
  alerts: List(rt.Alert),
  routes: Set(Route),
  stop_id: st.StopId,
) -> List(rt.Alert) {
  let current_time = util.current_time()
  let alerts =
    alerts
    |> list.filter(fn(alert) {
      use period <- list.any(in: alert.active_periods)

      let after_start = case period.start {
        option.Some(start) -> {
          let start = timestamp.subtract(start, alert.display_before_active)
          timestamp.compare(start, current_time) != order.Gt
        }
        option.None -> True
      }
      let before_end = case period.end {
        option.Some(end) -> timestamp.compare(current_time, end) != order.Gt
        option.None -> True
      }

      after_start && before_end
    })
    |> list.filter(fn(alert) {
      use target <- list.any(in: alert.targets)

      let matches_route_id =
        target.route_id
        |> option.to_result(Nil)
        |> result.try(fn(id) { route.parse(id) |> result.replace_error(Nil) })
        |> result.map(set.contains(_, in: routes))
        |> result.unwrap(or: False)

      let matches_station =
        target.stop_id
        |> option.to_result(Nil)
        |> result.try(st.parse_stop_id)
        |> result.map(pair.first)
        |> result.map(fn(target_stop_id) { target_stop_id == stop_id })
        |> result.unwrap(or: False)

      matches_route_id || matches_station
    })
  alerts
}

pub type Error {
  InvalidStopId(stop_id: String)
  UnknownStation(stop_id: st.StopId)
}

pub fn error_invalid_stop_id(
  stop_id: String,
) -> #(lustre_middleware.LustreRes(a), wisp.Response) {
  #(
    Document(head: [html.title([], "Error: Invalid stop")], body: [
      html.p([], [html.text("Error: Invalid stop id: " <> stop_id)]),
    ]),
    wisp.response(400),
  )
}

pub fn error_unknown_station(
  stop_id: st.StopId,
) -> #(lustre_middleware.LustreRes(b), wisp.Response) {
  #(
    Document(head: [html.title([], "Error: Unknown station")], body: [
      html.p([], [
        html.text(
          "Error: Could not find station "
          <> st.stop_id_to_string(stop_id, option.None),
        ),
      ]),
    ]),
    wisp.response(404),
  )
}

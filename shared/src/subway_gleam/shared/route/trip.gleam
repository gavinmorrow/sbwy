import gleam/bool
import gleam/dynamic/decode
import gleam/float
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed

import subway_gleam/gtfs/rt
import subway_gleam/gtfs/st
import subway_gleam/shared/component/arrival.{type Arrival}
import subway_gleam/shared/component/last_updated
import subway_gleam/shared/component/route_bullet.{
  type RouteBullet, route_bullet,
}
import subway_gleam/shared/util/live_status.{type LiveStatus}
import subway_gleam/shared/util/time.{type Time}

pub type Model {
  Model(
    connections: List(Connection),
    last_updated: Time,
    current_time: Time,
    event_source: LiveStatus,
  )
}

pub fn model_decoder() -> decode.Decoder(Model) {
  use connections <- decode.field(
    "connections",
    decode.list(of: connection_decoder()),
  )
  use last_updated <- decode.field("last_updated", time.decoder())
  use current_time <- decode.field("current_time", time.decoder())

  Model(
    connections:,
    last_updated:,
    current_time:,
    event_source: live_status.Unavailable,
  )
  |> decode.success
}

pub fn model_to_json(model: Model) -> json.Json {
  let Model(connections:, last_updated:, current_time:, event_source: _) = model
  json.object([
    #("connections", json.array(connections, of: connection_to_json)),
    #("last_updated", time.to_json(last_updated)),
    #("current_time", time.to_json(current_time)),
  ])
}

pub type Connection {
  Connection(
    train: Train,
    departing_stop: Option(Stop),
    arriving_stop: Option(Stop),
  )
}

fn connection_decoder() -> decode.Decoder(Connection) {
  use train <- decode.field("train", train_decoder())
  use departing_stop <- decode.field(
    "departing_stop",
    decode.optional(stop_decoder()),
  )
  use arriving_stop <- decode.field(
    "arriving_stop",
    decode.optional(stop_decoder()),
  )
  Connection(train:, departing_stop:, arriving_stop:) |> decode.success
}

fn connection_to_json(connection: Connection) -> json.Json {
  let Connection(train:, departing_stop:, arriving_stop:) = connection
  json.object([
    #("train", train_to_json(train)),
    #("departing_stop", json.nullable(departing_stop, stop_to_json)),
    #("arriving_stop", json.nullable(arriving_stop, stop_to_json)),
  ])
}

pub type Train {
  Train(
    id: rt.TripId,
    url: String,
    route: RouteBullet,
    headsign: Option(String),
  )
}

fn train_decoder() -> decode.Decoder(Train) {
  use id <- decode.field("id", decode.string |> decode.map(rt.TripId))
  use url <- decode.field("url", decode.string)
  use route <- decode.field("route", route_bullet.decoder())
  use headsign <- decode.field("headsign", decode.optional(decode.string))
  Train(id:, url:, route:, headsign:) |> decode.success
}

fn train_to_json(train: Train) -> json.Json {
  let Train(id:, url:, route:, headsign:) = train
  json.object([
    #("id", json.string(rt.trip_id_to_string(id))),
    #("url", json.string(url)),
    #("route", route_bullet.to_json(route)),
    #("headsign", json.nullable(headsign, json.string)),
  ])
}

pub type Stop {
  Stop(
    id: st.StopId,
    name: Option(String),
    /// Arrivals that are close in time to the transfer
    arrivals: List(Arrival),
    time: Timestamp,
  )
}

fn stop_decoder() -> decode.Decoder(Stop) {
  use id <- decode.field("id", decode.string |> decode.map(st.StopId))
  use name <- decode.field("name", decode.optional(decode.string))
  use arrivals <- decode.field("arrivals", decode.list(of: arrival.decoder()))
  use time <- decode.field(
    "time",
    decode.int |> decode.map(timestamp.from_unix_seconds),
  )
  Stop(id:, name:, arrivals:, time:) |> decode.success
}

fn stop_to_json(stop: Stop) -> json.Json {
  let Stop(id: st.StopId(id), name:, arrivals:, time:) = stop
  json.object([
    #("id", json.string(id)),
    #("name", json.nullable(name, json.string)),
    #("arrivals", json.array(arrivals, of: arrival.to_json)),
    #("time", json.int(timestamp.to_unix_seconds(time) |> float.round)),
  ])
}

pub fn view(model: Model) -> Element(msg) {
  let Model(connections:, last_updated:, current_time:, event_source:) = model

  let live_status = case event_source {
    live_status.Connecting(_) -> element.text("Conecting...")
    live_status.Live(_) -> element.text("Live!")
    live_status.Unavailable -> element.text("Live not available.")
  }

  html.div([], [
    html.h1([], [html.text("Your Trip")]),
    html.aside([], [
      last_updated.last_updated(at: last_updated, cur_time: current_time),
      html.br([]),
      live_status,
    ]),
    html.main([attribute.id("connecting-trains")], [
      html.ol([], list.filter_map(connections, connection_li(_, current_time))),
    ]),
  ])
}

fn connection_li(
  connection: Connection,
  current_time: Time,
) -> Result(Element(msg), Nil) {
  let Connection(train:, departing_stop:, arriving_stop:) = connection

  // Ensure that there's no nothing transfers
  use <- bool.guard(
    when: option.is_none(departing_stop) && option.is_none(arriving_stop),
    return: Error(Nil),
  )

  let departing_details = case departing_stop {
    option.Some(Stop(id:, name:, arrivals:, time:)) ->
      html.details([attribute.open(True)], [
        html.summary([], [
          html.text("Departing: " <> name |> option.unwrap(or: "unknown stop")),
        ]),
        keyed.ol(
          [attribute.class("arrival-list")],
          list.filter_map(arrivals, arrival.li(
            _,
            highlighting: option.Some(train.id),
            at: current_time,
          )),
        ),
      ])

    option.None -> element.none()
  }

  let arriving_details = case arriving_stop {
    option.Some(Stop(id:, name:, arrivals:, time:)) ->
      html.details([attribute.open(True)], [
        html.summary([], [
          html.text("Arriving: " <> name |> option.unwrap(or: "unknown stop")),
        ]),
        keyed.ol(
          [attribute.class("arrival-list")],
          list.filter_map(arrivals, arrival.li(
            _,
            highlighting: option.Some(train.id),
            at: current_time,
          )),
        ),
      ])

    option.None -> element.none()
  }
  html.li([], [
    html.h2([], [
      route_bullet(train.route),
      case train.headsign {
        option.Some(headsign) -> html.text(headsign)
        option.None -> element.none()
      },
    ]),
    departing_details,
    arriving_details,
  ])
  |> Ok
}

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed

import subway_gleam/gtfs/st
import subway_gleam/shared/component/connecting_train.{type ConnectingTrain}
import subway_gleam/shared/component/last_updated
import subway_gleam/shared/component/navbar.{navbar}
import subway_gleam/shared/component/route_bullet.{
  type RouteBullet, route_bullet,
}
import subway_gleam/shared/component/stop.{type Stop}
import subway_gleam/shared/util/live_status.{type LiveStatus}
import subway_gleam/shared/util/time.{type Time}

pub type Model {
  Model(
    last_updated: Time,
    route: RouteBullet,
    headsign: String,
    stops: List(Stop),
    highlighted_stop: option.Option(st.StopId),
    connecting_trains: List(ConnectingTrain),
    event_source: LiveStatus,
    cur_time: Time,
  )
}

pub fn view(model: Model) -> Element(msg) {
  let Model(
    last_updated:,
    route:,
    headsign:,
    stops:,
    highlighted_stop:,
    connecting_trains:,
    event_source:,
    cur_time:,
  ) = model

  let stops = list.filter_map(stops, stop.li(_, highlighted_stop, cur_time))

  let live_status = case event_source {
    live_status.Connecting(_) -> element.text("Conecting...")
    live_status.Live(_) -> element.text("Live!")
    live_status.Unavailable -> element.text("Live not available.")
  }

  html.div([], [
    html.h1([], [route_bullet(route), html.text(headsign)]),
    html.p([], [
      last_updated.last_updated(at: last_updated, cur_time:),
      html.br([]),
      live_status,
    ]),
    connecting_train.list(connecting_trains, cur_time),
    keyed.ol([attribute.class("stops-list")], stops),
    navbar(),
  ])
}

pub fn model_decoder() -> decode.Decoder(Model) {
  use last_updated <- decode.field("last_updated", time.decoder())
  use route <- decode.field("route", route_bullet.decoder())
  use headsign <- decode.field("headsign", decode.string)
  use stops <- decode.field("stops", decode.list(stop.decoder()))
  use highlighted_stop <- decode.field(
    "highlighted_stop",
    decode.optional(decode.string |> decode.map(st.StopId)),
  )
  use connecting_trains <- decode.field(
    "connecting_trains",
    decode.list(of: connecting_train.decoder()),
  )
  use cur_time <- decode.field("cur_time", time.decoder())

  decode.success(Model(
    last_updated:,
    route:,
    headsign:,
    stops:,
    highlighted_stop:,
    connecting_trains:,
    event_source: live_status.Unavailable,
    cur_time:,
  ))
}

pub fn model_to_json(model: Model) -> json.Json {
  let Model(
    last_updated:,
    route:,
    headsign:,
    stops:,
    highlighted_stop:,
    connecting_trains:,
    event_source: _,
    cur_time:,
  ) = model

  json.object([
    #("last_updated", time.to_json(last_updated)),
    #("route", route_bullet.to_json(route)),
    #("headsign", json.string(headsign)),
    #("stops", json.array(stops, stop.to_json)),
    #(
      "highlighted_stop",
      json.nullable(from: highlighted_stop, of: fn(stop_id) {
        let st.StopId(str) = stop_id
        json.string(str)
      }),
    ),
    #(
      "connecting_trains",
      json.array(connecting_trains, of: connecting_train.to_json),
    ),
    #("cur_time", time.to_json(cur_time)),
  ])
}

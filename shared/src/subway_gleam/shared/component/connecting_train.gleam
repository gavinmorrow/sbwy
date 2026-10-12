import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/list
import gleam/option
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

import subway_gleam/gtfs/rt
import subway_gleam/gtfs/st
import subway_gleam/shared/component/arrival_time
import subway_gleam/shared/component/route_bullet.{
  type RouteBullet, route_bullet,
}
import subway_gleam/shared/util/time.{type Time}
import subway_gleam/shared/util/timestamp_json

pub type ConnectingTrain {
  ConnectingTrain(
    trip_id: rt.TripId,
    train_url: String,
    route: RouteBullet,
    transfer_stop_id: st.StopId,
    transfer_stop_name: Result(String, Nil),
    arrival_time: Timestamp,
  )
}

pub fn decoder() -> decode.Decoder(ConnectingTrain) {
  use trip_id <- decode.field("trip_id", decode.string |> decode.map(rt.TripId))
  use train_url <- decode.field("train_url", decode.string)
  use route <- decode.field("route", route_bullet.decoder())
  use transfer_stop_id <- decode.field(
    "transfer_stop_id",
    decode.string |> decode.map(st.StopId),
  )
  use transfer_stop_name <- decode.field(
    "transfer_stop_name",
    decode.optional(decode.string) |> decode.map(option.to_result(_, Nil)),
  )
  use arrival_time <- decode.field("arrival_time", timestamp_json.decoder())

  ConnectingTrain(
    trip_id:,
    train_url:,
    route:,
    transfer_stop_id:,
    transfer_stop_name:,
    arrival_time:,
  )
  |> decode.success
}

pub fn to_json(connecting_train: ConnectingTrain) -> Json {
  let ConnectingTrain(
    trip_id:,
    train_url:,
    route:,
    transfer_stop_id: st.StopId(transfer_stop_id),
    transfer_stop_name:,
    arrival_time:,
  ) = connecting_train

  json.object([
    #("trip_id", json.string(rt.trip_id_to_string(trip_id))),
    #("train_url", json.string(train_url)),
    #("route", route_bullet.to_json(route)),
    #("transfer_stop_id", json.string(transfer_stop_id)),
    #(
      "transfer_stop_name",
      json.nullable(option.from_result(transfer_stop_name), of: json.string),
    ),
    #("arrival_time", timestamp_json.to_json(arrival_time)),
  ])
}

pub fn list(
  connecting_trains: List(ConnectingTrain),
  current_time: Time,
) -> Element(a) {
  html.aside([attribute.id("connecting-trains")], [
    html.li([], list.map(connecting_trains, li(_, current_time))),
  ])
}

fn li(connecting_train: ConnectingTrain, current_time: Time) -> Element(a) {
  let ConnectingTrain(
    trip_id: _,
    train_url:,
    route:,
    transfer_stop_id: _,
    transfer_stop_name:,
    arrival_time:,
  ) = connecting_train

  html.li([], [
    html.a([attribute.href(train_url)], [
      route_bullet(route),
      html.span([], [
        html.text(
          "Arriving at "
          <> result.unwrap(transfer_stop_name, "unknown stop")
          <> " in  ",
        ),
        arrival_time.arrival_time(arrival_time, current_time),
      ]),
    ]),
  ])
}

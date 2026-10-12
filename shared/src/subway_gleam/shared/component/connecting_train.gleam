import gleam/bool
import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import subway_gleam/shared/util

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
    departing_stop: Option(ConnectingStop),
    arriving_stop: Option(ConnectingStop),
  )
}

pub fn decoder() -> decode.Decoder(ConnectingTrain) {
  use trip_id <- decode.field("trip_id", decode.string |> decode.map(rt.TripId))
  use train_url <- decode.field("train_url", decode.string)
  use route <- decode.field("route", route_bullet.decoder())
  use departing_stop <- decode.field(
    "departing_stop",
    decode.optional(connecting_stop_decoder()),
  )
  use arriving_stop <- decode.field(
    "arriving_stop",
    decode.optional(connecting_stop_decoder()),
  )

  ConnectingTrain(trip_id:, train_url:, route:, departing_stop:, arriving_stop:)
  |> decode.success
}

pub fn to_json(connecting_train: ConnectingTrain) -> Json {
  let ConnectingTrain(
    trip_id:,
    train_url:,
    route:,
    departing_stop:,
    arriving_stop:,
  ) = connecting_train

  json.object([
    #("trip_id", json.string(rt.trip_id_to_string(trip_id))),
    #("train_url", json.string(train_url)),
    #("route", route_bullet.to_json(route)),
    #("departing_stop", json.nullable(departing_stop, connecting_stop_to_json)),
    #("arriving_stop", json.nullable(arriving_stop, connecting_stop_to_json)),
  ])
}

pub type ConnectingStop {
  ConnectingStop(id: st.StopId, name: Result(String, Nil), time: Timestamp)
}

fn connecting_stop_decoder() -> decode.Decoder(ConnectingStop) {
  use id <- decode.field("id", decode.string |> decode.map(st.StopId))
  use name <- decode.field(
    "name",
    decode.optional(decode.string) |> decode.map(option.to_result(_, Nil)),
  )
  use time <- decode.field("time", timestamp_json.decoder())
  decode.success(ConnectingStop(id:, name:, time:))
}

fn connecting_stop_to_json(connecting_stop: ConnectingStop) -> Json {
  let ConnectingStop(id: st.StopId(id), name:, time:) = connecting_stop
  json.object([
    #("id", json.string(id)),
    #("name", json.nullable(option.from_result(name), of: json.string)),
    #("time", timestamp_json.to_json(time)),
  ])
}

pub fn list(
  connecting_trains: List(ConnectingTrain),
  current_time: Time,
) -> Element(a) {
  html.aside([attribute.id("connecting-trains")], [
    html.h2([], [html.text("Transfers")]),
    html.ol([], list.filter_map(connecting_trains, li(_, current_time))),
    case connecting_trains {
      [] -> element.none()
      _ ->
        html.form(
          [
            attribute.class("clear-transfers-form"),
            attribute.action("./"),
            attribute.method("get"),
          ],
          [
            html.button([], [html.text("Clear transfers")]),
          ],
        )
    },
  ])
}

fn li(
  connecting_train: ConnectingTrain,
  current_time: Time,
) -> Result(Element(a), Nil) {
  let ConnectingTrain(
    trip_id: _,
    train_url:,
    route:,
    departing_stop:,
    arriving_stop:,
  ) = connecting_train

  // Filter to not show transfers that have finished.
  let is_finished = case arriving_stop {
    option.Some(arriving_stop) -> {
      let dt = arriving_stop.time |> util.min_from(current_time.timestamp)
      dt < 0
    }
    // If the destination hasn't been chosen, the transfer isn't finished.
    option.None -> False
  }
  use <- bool.guard(when: is_finished, return: Error(Nil))
  // Ensure that there's no nothing transfers
  use <- bool.guard(
    when: option.is_none(departing_stop) && option.is_none(arriving_stop),
    return: Error(Nil),
  )

  html.li([], [
    html.a([attribute.href(train_url)], [
      route_bullet(route),
      html.span([attribute.class("lines")], [
        case departing_stop {
          option.Some(ConnectingStop(id: _, name:, time:)) ->
            html.span([], case time |> util.min_from(current_time.timestamp) {
              dt if dt < 0 -> [
                // Already departed
                html.span([attribute.class("description")], [
                  html.text("Departed: " <> result.unwrap(name, "unknown stop")),
                ]),
              ]
              _ -> [
                // Departing in future
                html.span([attribute.class("description")], [
                  html.text(
                    "Departing: " <> result.unwrap(name, "unknown stop"),
                  ),
                ]),
                arrival_time.arrival_time(time, current_time),
              ]
            })
          option.None -> element.none()
        },
        case arriving_stop {
          option.Some(ConnectingStop(id: _, name:, time:)) ->
            html.span([], [
              html.span([attribute.class("description")], [
                html.text("Arriving: " <> result.unwrap(name, "unknown stop")),
              ]),
              arrival_time.arrival_time(time, current_time),
            ])
          option.None -> element.none()
        },
      ]),
    ]),
  ])
  |> Ok
}

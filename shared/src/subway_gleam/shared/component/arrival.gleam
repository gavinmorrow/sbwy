import gleam/bool
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result
import gleam/time/timestamp
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

import subway_gleam/gtfs/rt
import subway_gleam/shared/component/arrival_time.{arrival_time}
import subway_gleam/shared/component/route_bullet.{
  type RouteBullet, route_bullet,
}
import subway_gleam/shared/util
import subway_gleam/shared/util/time.{type Time}
import subway_gleam/shared/util/timestamp_json

pub type Arrival {
  Arrival(
    train_id: rt.TripId,
    train_url: String,
    route: RouteBullet,
    headsign: Result(String, Nil),
    time: timestamp.Timestamp,
    dimmed: Bool,
  )
}

pub fn decoder() -> decode.Decoder(Arrival) {
  use train_id <- decode.field(
    "train_id",
    decode.string |> decode.map(rt.TripId),
  )
  use train_url <- decode.field("train_url", decode.string)
  use route <- decode.field("route", route_bullet.decoder())
  use headsign <- decode.field(
    "headsign",
    decode.optional(decode.string) |> decode.map(option.to_result(_, Nil)),
  )
  use time <- decode.field("time", timestamp_json.decoder())
  use dimmed <- decode.field("dimmed", decode.bool)

  decode.success(Arrival(
    train_id:,
    train_url:,
    route:,
    headsign:,
    time:,
    dimmed:,
  ))
}

pub fn to_json(arrival: Arrival) -> json.Json {
  let Arrival(train_id:, train_url:, route:, headsign:, time:, dimmed:) =
    arrival

  json.object([
    #("train_id", json.string(rt.trip_id_to_string(train_id))),
    #("train_url", json.string(train_url)),
    #("route", route_bullet.to_json(route)),
    #("headsign", json.nullable(option.from_result(headsign), of: json.string)),
    #("time", timestamp_json.to_json(time)),
    #("dimmed", json.bool(dimmed)),
  ])
}

pub fn li(
  for arrival: Arrival,
  highlighting highlighted_train: option.Option(rt.TripId),
  at cur_time: Time,
) -> Result(#(String, Element(msg)), Nil) {
  let Arrival(train_id:, train_url:, route:, headsign:, time:, dimmed:) =
    arrival

  // Filter to not show departed trains
  let dt = time |> util.min_from(cur_time.timestamp)
  use <- bool.guard(when: dt < 0, return: Error(Nil))

  let headsign =
    result.map(headsign, fn(headsign) {
      html.span([attribute.class("headsign")], [html.text(headsign)])
    })

  let is_highlighted = option.Some(train_id) == highlighted_train

  #(
    rt.trip_id_to_string(arrival.train_id),
    html.li([], [
      html.a(
        [
          attribute.href(train_url),
          attribute.classes([
            #("highlight", is_highlighted),
            #("dimmed", dimmed),
          ]),
        ],
        [
          route_bullet(route),
          html.div([], [
            headsign |> result.unwrap(or: element.none()),
            html.div(
              [
                attribute.classes([
                  #(
                    "arriving-now",
                    time |> util.min_from(cur_time.timestamp) < 1,
                  ),
                  #(
                    "arriving-very-soon",
                    time |> util.min_from(cur_time.timestamp) <= 5,
                  ),
                  #(
                    "arriving-soon",
                    time |> util.min_from(cur_time.timestamp) <= 10,
                  ),
                ]),
              ],
              [arrival_time(arriving_at: time, cur_time:)],
            ),
          ]),
        ],
      ),
    ]),
  )
  |> Ok
}

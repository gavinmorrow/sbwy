import gleam/bool
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import subway_gleam/shared/util

import subway_gleam/shared/component/arrival_time
import subway_gleam/shared/component/connecting_train.{ConnectingStop}
import subway_gleam/shared/component/last_updated
import subway_gleam/shared/component/route_bullet.{route_bullet}
import subway_gleam/shared/util/live_status.{type LiveStatus}
import subway_gleam/shared/util/time.{type Time}

pub type Model {
  Model(
    connections: List(connecting_train.ConnectingTrain),
    last_updated: Time,
    current_time: Time,
    event_source: LiveStatus,
  )
}

pub fn model_decoder() -> decode.Decoder(Model) {
  use connections <- decode.field(
    "connections",
    decode.list(of: connecting_train.decoder()),
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
    #("connections", json.array(connections, of: connecting_train.to_json)),
    #("last_updated", time.to_json(last_updated)),
    #("current_time", time.to_json(current_time)),
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
  connecting_train: connecting_train.ConnectingTrain,
  current_time: Time,
) -> Result(Element(msg), Nil) {
  let connecting_train.ConnectingTrain(
    trip_id:,
    train_url:,
    route:,
    departing_stop:,
    arriving_stop:,
  ) = connecting_train

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

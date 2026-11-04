import gleam/dynamic/decode
import gleam/json
import lustre/element.{type Element}
import lustre/element/html
import subway_gleam/shared/component/last_updated

import subway_gleam/shared/component/connecting_train
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

  html.main([], [
    html.h1([], [html.text("Your Trip")]),
    html.aside([], [
      last_updated.last_updated(at: last_updated, cur_time: current_time),
      html.br([]),
      live_status,
    ]),
    // TODO: make custom list
    connecting_train.list(connections, current_time),
  ])
}

import gleam/json
import gleam/result
import gleam/time/duration
import gleam/time/timestamp
import lustre
import lustre/effect.{type Effect}
import lustre_event_source
import plinth/browser/document
import plinth/browser/element
import plinth/browser/location
import plinth/browser/window

import subway_gleam/client/util/set_interval
import subway_gleam/shared/route/trip.{type Model, Model, view}
import subway_gleam/shared/util/live_status.{live_status}
import subway_gleam/shared/util/time.{Time}

pub fn main() -> Result(lustre.Runtime(Msg), lustre.Error) {
  // TODO: handle errors: model not found, and invalid JSON
  let assert Ok(Ok(model)) =
    document.get_element_by_id("model")
    |> result.map(element.inner_text)
    |> result.map(json.parse(_, trip.model_decoder()))

  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, onto: "#app", with: model)
}

pub type Msg {
  EventSource(lustre_event_source.Message)
  /// Update the current timestamp and time zone offset
  UpdateTime(timestamp.Timestamp, Result(duration.Duration, Nil))
}

fn init(flags: Model) -> #(Model, Effect(Msg)) {
  let update_cur_time = set_interval.update_time(UpdateTime)
  let query_params =
    window.self() |> window.location |> location.search |> result.unwrap(or: "")
  let event_source =
    lustre_event_source.init("./model_stream?" <> query_params, EventSource)

  #(flags, effect.batch([update_cur_time, event_source]))
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    // TODO: extract all this event source logic into a function
    EventSource(lustre_event_source.Data(data)) -> {
      case json.parse(from: data, using: trip.model_decoder()) {
        Ok(Model(connections:, last_updated:, current_time: _, event_source: _)) -> #(
          Model(..model, connections:, last_updated:),
          effect.none(),
        )
        Error(_) -> todo as "handle model decode error"
      }
    }
    EventSource(lustre_event_source.Init(event_source))
    | EventSource(lustre_event_source.OnOpen(event_source)) -> {
      #(Model(..model, event_source: live_status(event_source)), effect.none())
    }
    EventSource(lustre_event_source.Error) -> {
      let live_status = case model.event_source {
        live_status.Connecting(event_source) -> live_status(event_source)
        live_status.Live(event_source) -> live_status(event_source)
        live_status.Unavailable -> live_status.Unavailable
      }
      #(Model(..model, event_source: live_status), effect.none())
    }
    EventSource(lustre_event_source.NoEventSourceClient) -> #(
      Model(..model, event_source: live_status.Unavailable),
      effect.none(),
    )

    UpdateTime(timestamp, time_zone_offset) -> #(
      Model(
        ..model,
        current_time: Time(
          timestamp:,
          time_zone_offset: time_zone_offset
            |> result.or(model.current_time.time_zone_offset),
        ),
      ),
      effect.none(),
    )
  }
}

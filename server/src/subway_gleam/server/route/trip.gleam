import gleam/result
import gleam/time/timestamp
import lustre/attribute
import lustre/element/html
import wisp

import subway_gleam/server/connecting_trains
import subway_gleam/server/hydration_scripts
import subway_gleam/server/log
import subway_gleam/server/lustre_middleware.{Document, try_lustre_res}
import subway_gleam/server/state
import subway_gleam/server/state/gtfs_store
import subway_gleam/server/time_zone
import subway_gleam/shared/route/trip.{type Model, Model}
import subway_gleam/shared/util/live_status
import subway_gleam/shared/util/time

pub fn trip(
  req: wisp.Request,
  state: state.State,
  trip_str: String,
) -> wisp.Response {
  use <- log.time("trip route")
  use _req <- try_lustre_res(req)

  case model(state, trip_str) {
    Ok(model) -> {
      use <- log.time("stop route post-model")

      let head = [
        html.title([], "Your Trip"),
        hydration_scripts.hydration_scripts("trip", trip.model_to_json(model)),
      ]
      let body = [html.div([attribute.id("app")], [trip.view(model)])]

      Ok(#(Document(head:, body:), wisp.response(200)))
    }
    Error(Nil) -> panic as "unreachable"
  }
}

pub fn model(state: state.State, trip_str: String) -> Result(Model, Nil) {
  let connections = connecting_trains.from_str(trip_str, state)

  let data = gtfs_store.get(state.gtfs_store)
  let last_updated =
    gtfs_store.last_updated(data) |> result.unwrap(or: timestamp.unix_epoch)
  let last_updated =
    time.Time(
      last_updated,
      state.tz_db |> time_zone.new_york_offset(at: last_updated),
    )
  let current_time = time_zone.now(state.tz_db)

  Model(
    connections:,
    last_updated:,
    current_time:,
    event_source: live_status.Unavailable,
  )
  |> Ok
}

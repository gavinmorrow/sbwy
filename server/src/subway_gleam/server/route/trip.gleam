import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/result
import gleam/time/timestamp
import lustre/attribute
import lustre/element/html
import subway_gleam/gtfs/rt
import subway_gleam/gtfs/st
import subway_gleam/shared/component/connecting_train
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
  let connections =
    connecting_trains.from_str(trip_str, state)
    |> list.map(map_connecting_train(_, state.schedule.trips.headsigns))

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

fn map_connecting_train(
  connection: connecting_train.ConnectingTrain,
  headsigns: Dict(st.ShapeId, String),
) -> trip.Connection {
  let connecting_train.ConnectingTrain(
    trip_id:,
    train_url:,
    route:,
    departing_stop:,
    arriving_stop:,
  ) = connection

  let headsign =
    option.from_result({
      use shape_id <- result.try(rt.parse_shape_id(trip_id))
      dict.get(headsigns, shape_id)
    })

  trip.Connection(
    train: trip.Train(id: trip_id, url: train_url, route:, headsign:),
    departing_stop: option.map(departing_stop, map_connecting_stop),
    arriving_stop: option.map(arriving_stop, map_connecting_stop),
  )
}

fn map_connecting_stop(stop: connecting_train.ConnectingStop) -> trip.Stop {
  let connecting_train.ConnectingStop(id:, name:, time:) = stop
  trip.Stop(id:, name: option.from_result(name), time:)
}

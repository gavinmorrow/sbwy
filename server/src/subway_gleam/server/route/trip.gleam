import gleam/dict
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/time/timestamp
import lustre/attribute
import lustre/element/html
import wisp

import subway_gleam/gtfs/rt
import subway_gleam/gtfs/st
import subway_gleam/server/arrival
import subway_gleam/server/connecting_trains
import subway_gleam/server/hydration_scripts
import subway_gleam/server/log
import subway_gleam/server/lustre_middleware.{Document, try_lustre_res}
import subway_gleam/server/state
import subway_gleam/server/state/gtfs_store
import subway_gleam/server/time_zone
import subway_gleam/shared/component/connecting_train
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
  let data = gtfs_store.get(state.gtfs_store)
  let last_updated =
    gtfs_store.last_updated(data) |> result.unwrap(or: timestamp.unix_epoch)
  let last_updated =
    time.Time(
      last_updated,
      state.tz_db |> time_zone.new_york_offset(at: last_updated),
    )
  let current_time = time_zone.now(state.tz_db)

  let connections =
    connecting_trains.from_str(trip_str, state)
    |> list.map(map_connecting_train(_, state.schedule, data))

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
  schedule: st.Schedule,
  data: gtfs_store.Data,
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
      dict.get(schedule.trips.headsigns, shape_id)
    })

  trip.Connection(
    train: trip.Train(id: trip_id, url: train_url, route:, headsign:),
    departing_stop: departing_stop
      |> option.map(map_connecting_stop(_, trip_id, schedule, data)),
    arriving_stop: arriving_stop
      |> option.map(map_connecting_stop(_, trip_id, schedule, data)),
  )
}

fn map_connecting_stop(
  stop: connecting_train.ConnectingStop,
  trip_id: rt.TripId,
  schedule: st.Schedule,
  data: gtfs_store.Data,
) -> trip.Stop {
  let connecting_train.ConnectingStop(id:, name:, time:) = stop
  let arrivals =
    data
    |> gtfs_store.arrivals(id)
    |> result.unwrap(or: [])
    |> list.sort(by: fn(a, b) {
      timestamp.compare(a.1.time, b.1.time) |> order.negate
    })

  // Take just `num` trains before and after the current one
  let num = 3
  let #(before, after) =
    arrivals
    |> list.split_while(satisfying: fn(arrival) {
      let #(trip, _) = arrival
      trip.id != trip_id
    })
  let #(_, before) = list.split(before, at: list.length(before) - num)
  // +1 because it includes the current train
  let #(after, _) = list.split(after, at: num + 1)
  let arrivals = list.append(before, after)

  let arrivals =
    arrivals
    |> list.map(arrival.arrival(
      _,
      schedule,
      gtfs_store.final_stop(data, _),
      // TODO: connecting trains
      [],
    ))
  trip.Stop(id:, name: option.from_result(name), arrivals:, time:)
}

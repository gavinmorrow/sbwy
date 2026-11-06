import gleam/dict
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/time/timestamp
import gleam/uri

import subway_gleam/gtfs/rt
import subway_gleam/gtfs/st
import subway_gleam/gtfs/st/route
import subway_gleam/server/connecting_trains
import subway_gleam/shared/component/arrival.{type Arrival, Arrival}
import subway_gleam/shared/component/connecting_train.{
  type ConnectingTrain, ConnectingTrain,
}
import subway_gleam/shared/component/route_bullet

pub fn arrival(
  update: #(rt.Trip, rt.TrainStopping),
  schedule: st.Schedule,
  get_final_stop: fn(st.ShapeId) -> Result(st.StopId, Nil),
  connecting_trains: List(ConnectingTrain),
) -> Arrival {
  let #(trip, rt.TrainStopping(time:, stop_id:, direction:)) = update

  let headsign = {
    use shape_id <- result.try(rt.parse_shape_id(from: trip.id))
    schedule.trips.headsigns
    |> dict.get(shape_id)
    |> result.lazy_or(fn() {
      get_final_stop(shape_id)
      |> result.try(dict.get(schedule.stops, _))
      |> result.map(fn(stop) { stop.name })
      // TODO: maybe don't want to always have a value?
      |> result.unwrap(or: "<Unknown stop>")
      |> Ok
    })
  }

  let is_last_connection = case list.last(connecting_trains) {
    Ok(connecting_train.ConnectingTrain(trip_id:, ..)) -> trip_id == trip.id
    _ -> False
  }

  let query =
    uri.query_to_string(
      [
        #(
          "stop_id",
          st.stop_id_to_string(stop_id, option.Some(direction)) |> Ok,
        ),
        #("connecting_trains", case is_last_connection {
          True ->
            case list.reverse(connecting_trains) {
              [] -> Error(Nil)
              [
                ConnectingTrain(
                  trip_id:,
                  departing_stop:,
                  arriving_stop: option.Some(arriving_stop),
                  ..,
                ),
                ..rest
              ]
                if arriving_stop.id == stop_id
              ->
                connecting_trains.append_to_string(
                  to: rest,
                  trip_id: trip_id,
                  departing: departing_stop |> option.map(fn(stop) { stop.id }),
                  arriving: option.None,
                )
                |> Ok
              _ -> connecting_trains |> connecting_trains.to_string
            }

          False ->
            connecting_trains.append_to_string(
              to: connecting_trains,
              trip_id: trip.id,
              departing: option.Some(stop_id),
              arriving: option.None,
            )
            |> Ok
        }),
      ]
      |> list.filter_map(fn(query) {
        case query {
          #(key, Ok(value)) -> Ok(#(key, value))
          _ -> Error(Nil)
        }
      }),
    )
  let train_url = "/train/" <> rt.trip_id_to_string(trip.id) <> "/?" <> query

  // TODO: use default route bullet instead of panicking
  let assert Ok(route) = route.parse(trip.route)
  let route =
    schedule |> st.route_data(for: route) |> route_bullet.from_route_data

  let dimmed = case list.last(connecting_trains) {
    Ok(ConnectingTrain(
      arriving_stop: option.Some(connecting_train.ConnectingStop(
        time: arrival_time,
        ..,
      )),
      ..,
    )) -> timestamp.compare(arrival_time, time) == order.Gt
    _ -> False
  }

  Arrival(train_id: trip.id, train_url:, route:, headsign:, time:, dimmed:)
}

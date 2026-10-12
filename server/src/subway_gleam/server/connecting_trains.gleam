import gleam/dict
import gleam/function
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/uri
import subway_gleam/gtfs/rt
import subway_gleam/gtfs/st
import subway_gleam/gtfs/st/route
import subway_gleam/server/state
import subway_gleam/server/state/gtfs_store
import subway_gleam/shared/component/connecting_train.{
  type ConnectingTrain, ConnectingTrain,
}
import subway_gleam/shared/component/route_bullet

pub fn to_string(
  connecting_trains: List(ConnectingTrain),
) -> Result(String, Nil) {
  case connecting_trains {
    [] -> Error(Nil)
    _ ->
      list.map(connecting_trains, connecting_train_to_string)
      |> string.join(";")
      |> Ok
  }
}

fn connecting_train_to_string(connection: ConnectingTrain) -> String {
  let trip_id = rt.trip_id_to_string(connection.trip_id)
  let departing_id = case connection.departing_stop {
    option.Some(connecting_train.ConnectingStop(id: st.StopId(id), ..)) -> id
    option.None -> ""
  }
  let arriving_id = case connection.arriving_stop {
    option.Some(connecting_train.ConnectingStop(id: st.StopId(id), ..)) -> id
    option.None -> ""
  }
  trip_id <> ":" <> departing_id <> "-" <> arriving_id
}

pub fn append_to_string(
  to connecting_trains: List(ConnectingTrain),
  connection connection: String,
) -> String {
  case connecting_trains |> to_string {
    Error(Nil) -> connection
    Ok(connections) -> connections <> ";" <> connection
  }
}

pub fn from_query_params(
  query: List(#(String, String)),
  state: state.State,
) -> List(ConnectingTrain) {
  let connecting_trains_raw =
    query
    |> list.key_find("connecting_trains")
  let #(_, connecting_trains) =
    connecting_trains_raw
    |> result.try(parse_connecting_trains)
    |> result.unwrap(or: [])
    |> list.map_fold("", fn(prev_connections, connection) {
      let #(trip_id, departing_stop_id, arriving_stop_id) = connection

      // TODO: make this a function?
      // FIXME: discards arrival of current connection
      let train_url =
        "/train/"
        <> rt.trip_id_to_string(trip_id)
        <> "?"
        <> uri.query_to_string([#("connecting-trains", prev_connections)])

      let connection = {
        use #(trip, stops) <- result.try(
          state.fetch_gtfs(state) |> gtfs_store.trip(for: trip_id),
        )

        // TODO: copied from arrival_li(), should it be a function?
        // TODO: use default route bullet instead of panicking
        let assert Ok(route) = route.parse(trip.route)
        let route =
          state.schedule
          |> st.route_data(for: route)
          |> route_bullet.from_route_data

        ConnectingTrain(
          trip_id:,
          train_url:,
          route:,
          departing_stop: departing_stop_id
            |> option.then(connecting_stop(_, stops, state.schedule)),
          arriving_stop: arriving_stop_id
            |> option.then(connecting_stop(_, stops, state.schedule)),
        )
        |> Ok
      }

      case connection {
        Ok(connection) -> {
          let connections = case prev_connections {
            "" -> rt.trip_id_to_string(trip_id)
            _ -> prev_connections <> ";" <> rt.trip_id_to_string(trip_id)
          }
          #(connections, Ok(connection))
        }
        Error(Nil) -> #(prev_connections, Error(Nil))
      }
    })
  list.filter_map(connecting_trains, function.identity)
}

fn connecting_stop(
  id: st.StopId,
  stops: List(rt.TrainStopping),
  schedule: st.Schedule,
) -> Option(connecting_train.ConnectingStop) {
  use time <- option.map(
    list.find_map(in: stops, with: fn(stop) {
      case stop.stop_id == id {
        True -> Ok(stop.time)
        False -> Error(Nil)
      }
    })
    |> option.from_result,
  )

  connecting_train.ConnectingStop(
    id:,
    name: schedule.stops
      |> dict.get(id)
      |> result.map(fn(stop) { stop.name }),
    time:,
  )
}

fn parse_connecting_trains(
  trains: String,
) -> Result(List(#(rt.TripId, Option(st.StopId), Option(st.StopId))), Nil) {
  string.split(trains, on: ";")
  |> list.filter_map(parse_connecting_train)
  |> Ok
}

fn parse_connecting_train(
  train: String,
) -> Result(#(rt.TripId, Option(st.StopId), Option(st.StopId)), Nil) {
  case string.split(train, on: ":") {
    [trip_id, stop_ids] -> {
      let trip_id = rt.TripId(trip_id)
      case string.split(stop_ids, on: "-") {
        [""] | ["", ""] -> Error(Nil)
        [departing] ->
          Ok(#(trip_id, option.Some(st.StopId(departing)), option.None))
        ["", arriving] ->
          Ok(#(trip_id, option.None, option.Some(st.StopId(arriving))))
        [departing, arriving] ->
          Ok(#(
            trip_id,
            option.Some(st.StopId(departing)),
            option.Some(st.StopId(arriving)),
          ))
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

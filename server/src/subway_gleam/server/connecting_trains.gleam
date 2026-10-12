import gleam/dict
import gleam/function
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/time/timestamp
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
  let st.StopId(departing_id) = connection.departing_stop.id
  case connection.arriving_stop {
    option.Some(arriving_stop) -> {
      let st.StopId(arriving_id) = arriving_stop.id
      trip_id <> ":" <> departing_id <> "-" <> arriving_id
    }
    option.None -> trip_id <> ":" <> departing_id
  }
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

        let departing_time =
          result.unwrap(
            list.find_map(in: stops, with: fn(stop) {
              case stop.stop_id == departing_stop_id {
                True -> Ok(stop.time)
                False -> Error(Nil)
              }
            }),
            or: timestamp.unix_epoch,
          )

        ConnectingTrain(
          trip_id:,
          train_url:,
          route:,
          departing_stop: connecting_train.ConnectingStop(
            id: departing_stop_id,
            name: state.schedule.stops
              |> dict.get(departing_stop_id)
              |> result.map(fn(stop) { stop.name }),
            time: departing_time,
          ),
          arriving_stop: option.then(arriving_stop_id, fn(id) {
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
              name: state.schedule.stops
                |> dict.get(id)
                |> result.map(fn(stop) { stop.name }),
              time:,
            )
          }),
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

fn parse_connecting_trains(
  trains: String,
) -> Result(List(#(rt.TripId, st.StopId, Option(st.StopId))), Nil) {
  string.split(trains, on: ";")
  |> list.filter_map(parse_connecting_train)
  |> Ok
}

fn parse_connecting_train(
  train: String,
) -> Result(#(rt.TripId, st.StopId, Option(st.StopId)), Nil) {
  case string.split(train, on: ":") {
    [trip_id, stop_ids] -> {
      case string.split(stop_ids, on: "-") {
        [departing] ->
          Ok(#(rt.TripId(trip_id), st.StopId(departing), option.None))
        [departing, arriving] ->
          Ok(#(
            rt.TripId(trip_id),
            st.StopId(departing),
            option.Some(st.StopId(arriving)),
          ))

        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

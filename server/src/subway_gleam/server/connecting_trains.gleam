import gleam/dict
import gleam/function
import gleam/list
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
  let st.StopId(stop_id) = connection.transfer_stop_id
  trip_id <> ":" <> stop_id
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
      let #(trip_id, stop_id) = connection

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

        use arrival_time <- result.map(
          list.find_map(in: stops, with: fn(stop) {
            case stop.stop_id == stop_id {
              True -> Ok(stop.time)
              False -> Error(Nil)
            }
          }),
        )

        let transfer_stop_name =
          state.schedule.stops
          |> dict.get(stop_id)
          |> result.map(fn(stop) { stop.name })

        ConnectingTrain(
          trip_id:,
          train_url:,
          route:,
          transfer_stop_id: stop_id,
          transfer_stop_name:,
          arrival_time:,
        )
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
) -> Result(List(#(rt.TripId, st.StopId)), Nil) {
  string.split(trains, on: ";")
  |> list.filter_map(parse_connecting_train)
  |> Ok
}

fn parse_connecting_train(
  train: String,
) -> Result(#(rt.TripId, st.StopId), Nil) {
  case string.split(train, on: ":") {
    [trip_id, stop_id] -> Ok(#(rt.TripId(trip_id), st.StopId(stop_id)))
    _ -> Error(Nil)
  }
}

import gleam/dict
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import gleam/time/timestamp
import gleam/uri

import subway_gleam/gtfs/rt
import subway_gleam/gtfs/st
import subway_gleam/server/connecting_trains
import subway_gleam/shared/component/connecting_train
import subway_gleam/shared/component/route_bullet
import subway_gleam/shared/component/stop.{type Stop, Stop}

pub fn li(
  stop: st.Station,
  time: timestamp.Timestamp,
  trip_id: rt.TripId,
  schedule: st.Schedule,
  connecting_trains: List(connecting_train.ConnectingTrain),
  before_connection: Bool,
) -> Stop {
  let is_last_connection = case list.last(connecting_trains) {
    Ok(connecting_train.ConnectingTrain(
      departing_stop: option.Some(connecting_train.ConnectingStop(id:, ..)),
      ..,
    )) -> id == stop.id
    _ -> False
  }

  let stop_url = {
    let stop_id = stop.id |> st.stop_id_to_string(direction: option.None)
    let train_id = rt.trip_id_to_string(trip_id)

    let query = {
      let train = #("train_id", train_id)
      let connections = #("connecting_trains", case is_last_connection {
        True -> {
          // TODO: are these empty strings correct
          case list.reverse(connecting_trains) {
            [] -> ""
            [_this_stop, ..rest] ->
              rest |> connecting_trains.to_string |> result.unwrap(or: "")
          }
        }
        False ->
          connecting_trains.append_arriving_stop_to_string(
            to: case before_connection {
              True -> []
              False -> connecting_trains
            },
            trip_id:,
            arriving_stop_id: stop.id,
          )
      })

      uri.query_to_string([train, connections])
    }
    "/stop/" <> stop_id <> "?" <> query
  }

  let transfers =
    dict.get(schedule.transfers, stop.id)
    |> result.map(set.to_list)
    |> result.unwrap(or: [])
    |> list.flat_map(fn(transfer) {
      st.daytime_routes(in: schedule, for: transfer.destination) |> set.to_list
    })
    |> list.map(st.route_data(for: _, in: schedule))
    |> list.sort(by: st.route_compare)
    |> list.map(route_bullet.from_route_data)

  Stop(
    id: stop.id,
    name: stop.name,
    stop_url:,
    transfers:,
    time:,
    dimmed: before_connection,
  )
}

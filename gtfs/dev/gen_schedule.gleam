import gleam/dict
import gleam/dynamic/decode
import gleam/io
import gleam/json
import gleam/set
import gleam/time/duration
import simplifile
import subway_gleam/gtfs/st/route

import subway_gleam/gtfs/st
import subway_gleam/gtfs/st_extra

const path = st.schedule_sample_data_path

pub fn main() -> Nil {
  io.println_error("Fetching...")
  // let assert Ok(bits) = st.fetch_bin(st.Regular)
  let assert Ok(bits) = simplifile.read_bits(from: "../gtfs_subway.zip")
  io.println_error("Parsing...")
  let st_extra_data = load_st_extra_data()
  let assert Ok(schedule) = st.parse(bits, st_extra_data)

  io.println_error("Generating...")
  let schedule = schedule_to_json(schedule) |> json.to_string

  io.println_error("Writing to " <> path <> "...")
  let assert Ok(Nil) = simplifile.write(to: path, contents: schedule)

  io.println_error("Done.")
  Nil
}

fn schedule_to_json(schedule: st.Schedule) -> json.Json {
  json.object([
    #("stops", stops_to_json(schedule.stops)),
    #("trips", trips_to_json(schedule.trips)),
    #("services", services_to_json(schedule.services)),
    #("transfers", transfers_to_json(schedule.transfers)),
    #("routes", routes_to_json(schedule.routes)),
  ])
}

fn stops_to_json(stops: dict.Dict(st.StopId, st.Stop)) -> json.Json {
  json.dict(stops, stop_id_to_string, fn(stop: st.Stop) -> json.Json {
    let st.Stop(
      id:,
      name:,
      lat:,
      lon:,
      location_type:,
      parent_station:,
      borough:,
      daytime_routes:,
    ) = stop
    json.object([
      #("id", stop_id_to_json(id)),
      #("name", json.string(name)),
      #("lat", json.float(lat)),
      #("lon", json.float(lon)),
      #("location_type", json.nullable(location_type, of: json.int)),
      #("parent_station", json.nullable(parent_station, of: stop_id_to_json)),
      #("borough", borough_to_json(borough)),
      #(
        "daytime_routes",
        daytime_routes |> set.to_list |> json.array(of: route_to_json),
      ),
    ])
  })
}

fn trips_to_json(trips: st.Trips) -> json.Json {
  let st.Trips(headsigns:, routes:) = trips
  json.object([
    #("headsigns", json.dict(headsigns, st.shape_id_to_string, json.string)),
    #(
      "routes",
      json.dict(
        routes,
        fn(trip_id) {
          let st.TripId(trip_id) = trip_id
          trip_id
        },
        route_to_json,
      ),
    ),
  ])
}

fn services_to_json(services: dict.Dict(route.Route, st.Service)) -> json.Json {
  json.dict(services, route.to_long_id, fn(service) {
    let st.Service(route:, stops:) = service
    json.object([
      #("route", route_to_json(route)),
      #("stops", json.array(set.to_list(stops), of: stop_id_to_json)),
    ])
  })
}

fn transfers_to_json(
  transfers: dict.Dict(st.StopId, set.Set(st.Transfer)),
) -> json.Json {
  json.dict(transfers, stop_id_to_string, fn(transfers) {
    json.array(set.to_list(transfers), of: fn(transfer) {
      let st.Transfer(origin:, destination:, transfer_time:) = transfer
      json.object([
        #("origin", stop_id_to_json(origin)),
        #("destination", stop_id_to_json(destination)),
        #(
          "transfer_time_ms",
          json.int(transfer_time |> duration.to_milliseconds),
        ),
      ])
    })
  })
}

fn routes_to_json(routes: dict.Dict(route.Route, st.RouteData)) -> json.Json {
  json.dict(routes, route.to_long_id, fn(route_data) {
    let st.RouteData(
      id:,
      short_name:,
      long_name:,
      desc:,
      url:,
      color:,
      text_color:,
      sort_order:,
    ) = route_data
    json.object([
      #("id", route_to_json(id)),
      #("short_name", json.string(short_name)),
      #("long_name", json.string(long_name)),
      #("desc", json.string(desc)),
      #("url", json.string(url)),
      #("color", json.string(color)),
      #("text_color", json.string(text_color)),
      #("sort_order", json.int(sort_order)),
    ])
  })
}

fn borough_to_json(borough: st_extra.Borough) -> json.Json {
  json.string(case borough {
    st_extra.Manhattan -> "manhattan"
    st_extra.Brooklyn -> "brooklyn"
    st_extra.Queens -> "queens"
    st_extra.Bronx -> "bronx"
    st_extra.StatenIsland -> "staten_island"
  })
}

fn route_to_json(route: route.Route) -> json.Json {
  json.string(route.to_long_id(route))
}

fn stop_id_to_json(stop_id: st.StopId) -> json.Json {
  json.string(stop_id |> stop_id_to_string)
}

fn stop_id_to_string(stop_id: st.StopId) -> String {
  let st.StopId(stop_id) = stop_id
  stop_id
}

fn load_st_extra_data() -> st_extra.Data {
  let assert Ok(file) = simplifile.read(from: st_extra.data_file_path)
    as "data file should be prebuilt"
  let assert Ok(stops) =
    json.parse(file, using: decode.dict(decode.string, st_extra.stop_decoder()))
    as "prebuilt data should be have correct shape"
  stops
}

//// A sample schedule to use that doesn't take forever to parse.

import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/set
import gleam/time/duration
import simplifile
import subway_gleam/gtfs/st_extra

import subway_gleam/gtfs/st
import subway_gleam/gtfs/st/route

/// A sample schedule to use that doesn't take forever to parse.
pub fn schedule() -> Result(st.Schedule, st.FetchError) {
  let assert Ok(file) =
    simplifile.read(from: "../gtfs/" <> st.schedule_sample_data_path)
    as "data file should be prebuilt"
  let assert Ok(schedule) = json.parse(file, using: decode_schedule())
    as "prebuilt data should have correct shape"
  Ok(schedule)
}

fn decode_schedule() -> decode.Decoder(st.Schedule) {
  use stops <- decode.field("stops", stops_decoder())
  use trips <- decode.field("trips", trips_decoder())
  use services <- decode.field("services", services_decoder())
  use transfers <- decode.field("transfers", transfers_decoder())
  use routes <- decode.field("routes", routes_decoder())

  st.Schedule(stops:, trips:, services:, transfers:, routes:) |> decode.success
}

fn stops_decoder() -> decode.Decoder(dict.Dict(st.StopId, st.Stop)) {
  decode.dict(stop_id_decoder(), {
    use id <- decode.field("id", stop_id_decoder())
    use name <- decode.field("name", decode.string)
    use lat <- decode.field("lat", decode.float)
    use lon <- decode.field("lon", decode.float)
    use location_type <- decode.field(
      "location_type",
      decode.optional(decode.int),
    )
    use parent_station <- decode.field(
      "parent_station",
      decode.optional(stop_id_decoder()),
    )
    use borough <- decode.field("borough", borough_decoder())
    use daytime_routes <- decode.field(
      "daytime_routes",
      decode.list(of: route_decoder()) |> decode.map(set.from_list),
    )
    use north_direction_label <- decode.field(
      "north_direction_label",
      decode.string,
    )
    use south_direction_label <- decode.field(
      "south_direction_label",
      decode.string,
    )

    st.Stop(
      id:,
      name:,
      lat:,
      lon:,
      location_type:,
      parent_station:,
      borough:,
      daytime_routes:,
      north_direction_label:,
      south_direction_label:,
    )
    |> decode.success
  })
}

fn trips_decoder() -> decode.Decoder(st.Trips) {
  use headsigns <- decode.field(
    "headsigns",
    decode.dict(decode.string |> decode.map(st.ShapeId), decode.string),
  )
  use routes <- decode.field(
    "routes",
    decode.dict(decode.string |> decode.map(st.TripId), route_decoder()),
  )

  st.Trips(headsigns:, routes:) |> decode.success
}

fn services_decoder() -> decode.Decoder(dict.Dict(route.Route, st.Service)) {
  decode.dict(route_decoder(), {
    use route <- decode.field("route", route_decoder())
    use stops <- decode.field(
      "stops",
      decode.list(of: stop_id_decoder()) |> decode.map(set.from_list),
    )
    st.Service(route:, stops:) |> decode.success
  })
}

fn transfers_decoder() -> decode.Decoder(
  dict.Dict(st.StopId, set.Set(st.Transfer)),
) {
  decode.dict(stop_id_decoder(), {
    decode.list(of: {
      use origin <- decode.field("origin", stop_id_decoder())
      use destination <- decode.field("destination", stop_id_decoder())
      use transfer_time <- decode.field(
        "transfer_time_ms",
        decode.int |> decode.map(duration.milliseconds),
      )
      st.Transfer(origin:, destination:, transfer_time:) |> decode.success
    })
    |> decode.map(set.from_list)
  })
}

fn routes_decoder() -> decode.Decoder(dict.Dict(route.Route, st.RouteData)) {
  decode.dict(route_decoder(), {
    use id <- decode.field("id", route_decoder())
    use short_name <- decode.field("short_name", decode.string)
    use long_name <- decode.field("long_name", decode.string)
    use desc <- decode.field("desc", decode.string)
    use url <- decode.field("url", decode.string)
    use color <- decode.field("color", decode.string)
    use text_color <- decode.field("text_color", decode.string)
    use sort_order <- decode.field("sort_order", decode.int)

    st.RouteData(
      id:,
      short_name:,
      long_name:,
      desc:,
      url:,
      color:,
      text_color:,
      sort_order:,
    )
    |> decode.success
  })
}

fn borough_decoder() -> decode.Decoder(st_extra.Borough) {
  use borough <- decode.then(decode.string)
  case borough {
    "manhattan" -> st_extra.Manhattan |> decode.success
    "brooklyn" -> st_extra.Brooklyn |> decode.success
    "queens" -> st_extra.Queens |> decode.success
    "bronx" -> st_extra.Bronx |> decode.success
    "staten_island" -> st_extra.StatenIsland |> decode.success
    _ -> decode.failure(st_extra.Manhattan, "Borough")
  }
}

fn route_decoder() -> decode.Decoder(route.Route) {
  use route <- decode.then(decode.string)
  case route.from_long_id(route) {
    Ok(route) -> decode.success(route)
    Error(Nil) -> decode.failure(route.A, "Route")
  }
}

fn stop_id_decoder() -> decode.Decoder(st.StopId) {
  use stop_id <- decode.then(decode.string)
  st.StopId(stop_id) |> decode.success
}

//// Extra fields that are technically not in the GTFS feed.
//// Semi-manually parsed from
//// <https://catalog.data.gov/dataset/mta-subway-stations-and-complexes>

import gleam/dict
import gleam/dynamic/decode
import gleam/set

import subway_gleam/gtfs/st/route.{type Route}

pub const data_file_path: String = "./priv/st_extra.json"

pub type Data =
  dict.Dict(String, Stop)

pub type Stop {
  Stop(
    borough: Borough,
    /// The routes that "normally" (ie, daytime weekdays) stop at the stop.
    /// Does not account for rush hour express.
    daytime_routes: set.Set(Route),
    north_direction_label: String,
    south_direction_label: String,
  )
}

pub fn stop_decoder() -> decode.Decoder(Stop) {
  use borough <- decode.field("borough", borough_decoder())
  use daytime_routes <- decode.field("daytime_routes", daytime_routes_decoder())
  use north_direction_label <- decode.field(
    "north_direction_label",
    decode.string,
  )
  use south_direction_label <- decode.field(
    "south_direction_label",
    decode.string,
  )
  decode.success(Stop(
    borough:,
    daytime_routes:,
    north_direction_label:,
    south_direction_label:,
  ))
}

pub type Borough {
  Manhattan
  Brooklyn
  Queens
  Bronx
  StatenIsland
}

fn borough_decoder() -> decode.Decoder(Borough) {
  use variant <- decode.then(decode.string)
  case variant {
    "manhattan" -> decode.success(Manhattan)
    "brooklyn" -> decode.success(Brooklyn)
    "queens" -> decode.success(Queens)
    "bronx" -> decode.success(Bronx)
    "staten_island" -> decode.success(StatenIsland)
    _ -> decode.failure(Manhattan, "Borough")
  }
}

fn daytime_routes_decoder() -> decode.Decoder(set.Set(Route)) {
  decode.list(of: route_decoder()) |> decode.map(set.from_list)
}

fn route_decoder() -> decode.Decoder(Route) {
  use route <- decode.then(decode.string)
  case route.from_long_id(route) {
    Ok(route) -> decode.success(route)
    Error(Nil) -> decode.failure(route.A, "Route")
  }
}

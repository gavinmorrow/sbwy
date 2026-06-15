//// Extra fields that are technically not in the GTFS feed.
//// Semi-manually parsed from
//// <https://catalog.data.gov/dataset/mta-subway-stations-and-complexes>

import gleam/set

import subway_gleam/gtfs/st/route.{type Route}

pub type Stop {
  Stop(
    id: String,
    borough: Borough,
    /// The routes that "normally" (ie, daytime weekdays) stop at the stop.
    /// Does not account for rush hour express.
    daytime_routes: set.Set(Route),
  )
}

pub type Borough {
  Manhattan
  Brooklyn
  Queens
  Bronx
  StatenIsland
}

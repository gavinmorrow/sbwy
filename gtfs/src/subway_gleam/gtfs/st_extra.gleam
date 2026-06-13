//// Extra fields that are technically not in the GTFS feed.
//// Semi-manually parsed from
//// <https://catalog.data.gov/dataset/mta-subway-stations-and-complexes>

import gleam/set

import subway_gleam/gtfs/st

pub type Stop {
  Stop(
    borough: Borough,
    /// The routes that "normally" (ie, daytime weekdays) stop at the stop.
    /// Does not account for rush hour express.
    daytime_routes: set.Set(st.Route),
  )
}

pub type Borough {
  Manhattan
  Brooklyn
  Queens
  Bronx
  StatenIsland
}

import gleam/dict
import gleam/list
import gleam/option
import gleam/set
import gleam/time/timestamp
import lustre/dev/query.{type Query}
import lustre/dev/simulate
import lustre/effect
import subway_gleam/gtfs/st.{Stop, StopId}
import subway_gleam/gtfs/st/route.{
  A, C, E, J, N, N1, N2, N3, N4, N5, N6, Q, R, W, Z,
}
import subway_gleam/gtfs/st_extra.{Manhattan}
import subway_gleam/shared/ffi/geolocation

import subway_gleam/client/stops.{type Msg, UpdatePosition, update} as _
import subway_gleam/shared/route/stops.{type Model, Model, StopLi, view} as _

fn simulate(model: Model) -> simulate.Simulation(Model, Msg) {
  simulate.application(init: fn(_) { #(model, effect.none()) }, update:, view:)
  |> simulate.start(Nil)
}

pub fn shows_nearby_stops_test() -> Nil {
  let app =
    simulate(
      Model(
        all_stops: all_stops(),
        stop_routes: dict.new(),
        cur_position: option.None,
        fav_stops: [],
      ),
    )

  // Should have no nearby stops
  let assert [] = query.find_all(stops_nearby_lis(), in: simulate.view(app))

  let app = simulate.message(app, UpdatePosition(city_hall_position))

  // Should have no nearby stops
  let stops = query.find_all(stops_nearby_lis(), in: simulate.view(app))
  assert list.length(stops) == 18
}

pub fn always_shows_favorites_test() -> Nil {
  let fav_stops = [
    // Should be within distance
    StopLi(id: StopId("R24"), name: "City Hall"),
    // Should be outside of distance
    StopLi(id: StopId("Q05"), name: "96 St"),
  ]

  let app =
    simulate(Model(
      all_stops: all_stops(),
      stop_routes: dict.new(),
      cur_position: option.None,
      fav_stops:,
    ))

  // All favorites should be shown
  let shown_favs = query.find_all(fav_stops_lis(), in: simulate.view(app))
  assert list.length(shown_favs) == list.length(fav_stops)

  let app = simulate.message(app, UpdatePosition(city_hall_position))

  // All favorites should still be shown
  let shown_favs = query.find_all(fav_stops_lis(), in: simulate.view(app))
  assert list.length(shown_favs) == list.length(fav_stops)
}

fn fav_stops_list() -> Query {
  query.element(query.class("favorite-stops-list"))
}

fn fav_stops_lis() -> Query {
  query.child(of: fav_stops_list(), matching: query.tag("li"))
}

fn stops_nearby_list() -> Query {
  query.element(query.class("stops-nearby-list"))
}

fn stops_nearby_lis() -> Query {
  query.child(of: stops_nearby_list(), matching: query.tag("li"))
}

const city_hall_position: geolocation.Position = geolocation.Position(
  latitude: 40.7127667,
  longitude: -74.0060544,
  accuracy: 10.0,
  // Okay to use epoch because it's just a test
  timestamp: timestamp.unix_epoch,
)

/// Not actually all stops, but a bunch of stops cenetered around City Hall, and
/// then a couple extra ones that shouldn't be within range.
fn all_stops() -> List(st.Stop) {
  [
    // Should be within distance
    Stop(
      StopId("R24"),
      "City Hall",
      40.713282,
      -74.006978,
      option.None,
      option.Some(StopId("R24")),
      Manhattan,
      set.from_list([R, W]),
      "Uptown",
      "Downtown",
    ),
    Stop(
      StopId("640"),
      "Brooklyn Bridge-City Hall",
      40.713065,
      -74.004131,
      option.None,
      option.Some(StopId("640")),
      Manhattan,
      set.from_list([N4, N5, N6]),
      "Uptown",
      "Downtown",
    ),
    Stop(
      StopId("M21"),
      "Chambers St",
      40.713243,
      -74.003401,
      option.None,
      option.Some(StopId("M21")),
      Manhattan,
      set.from_list([J, Z]),
      "Brooklyn",
      "Downtown",
    ),
    Stop(
      StopId("228"),
      "Park Place",
      40.713051,
      -74.008811,
      option.None,
      option.Some(StopId("228")),
      Manhattan,
      set.from_list([N2, N3]),
      "Uptown",
      "Brooklyn",
    ),
    Stop(
      StopId("A36"),
      "Chambers St",
      40.714111,
      -74.008585,
      option.None,
      option.Some(StopId("A36")),
      Manhattan,
      set.from_list([C, A]),
      "Uptown",
      "Brooklyn",
    ),
    Stop(
      StopId("M22"),
      "Fulton St",
      40.710374,
      -74.007582,
      option.None,
      option.Some(StopId("M22")),
      Manhattan,
      set.from_list([J, Z]),
      "Brooklyn",
      "Downtown",
    ),
    Stop(
      StopId("E01"),
      "World Trade Center",
      40.712582,
      -74.009781,
      option.None,
      option.Some(StopId("E01")),
      Manhattan,
      set.from_list([E]),
      "Uptown",
      "Last Stop",
    ),
    Stop(
      StopId("A38"),
      "Fulton St",
      40.710197,
      -74.007691,
      option.None,
      option.Some(StopId("A38")),
      Manhattan,
      set.from_list([C, A]),
      "Uptown",
      "Brooklyn",
    ),
    Stop(
      StopId("229"),
      "Fulton St",
      40.709416,
      -74.006571,
      option.None,
      option.Some(StopId("229")),
      Manhattan,
      set.from_list([N2, N3]),
      "Uptown",
      "Brooklyn",
    ),
    Stop(
      StopId("418"),
      "Fulton St",
      40.710368,
      -74.009509,
      option.None,
      option.Some(StopId("418")),
      Manhattan,
      set.from_list([N4, N5]),
      "Uptown",
      "Downtown",
    ),
    Stop(
      StopId("137"),
      "Chambers St",
      40.715478,
      -74.009266,
      option.None,
      option.Some(StopId("137")),
      Manhattan,
      set.from_list([N1, N2, N3]),
      "Uptown",
      "Downtown",
    ),
    Stop(
      StopId("R25"),
      "Cortlandt St",
      40.710668,
      -74.011029,
      option.None,
      option.Some(StopId("R25")),
      Manhattan,
      set.from_list([R, W]),
      "Uptown",
      "Downtown",
    ),
    Stop(
      StopId("138"),
      "WTC Cortlandt",
      40.711835,
      -74.012188,
      option.None,
      option.Some(StopId("138")),
      Manhattan,
      set.from_list([N1]),
      "Uptown",
      "Downtown",
    ),
    Stop(
      StopId("230"),
      "Wall St",
      40.706821,
      -74.0091,
      option.None,
      option.Some(StopId("230")),
      Manhattan,
      set.from_list([N2, N3]),
      "Uptown",
      "Brooklyn",
    ),
    Stop(
      StopId("136"),
      "Franklin St",
      40.719318,
      -74.006886,
      option.None,
      option.Some(StopId("136")),
      Manhattan,
      set.from_list([N1]),
      "Uptown",
      "Downtown",
    ),
    Stop(
      StopId("419"),
      "Wall St",
      40.707557,
      -74.011862,
      option.None,
      option.Some(StopId("419")),
      Manhattan,
      set.from_list([N4, N5]),
      "Uptown",
      "Downtown",
    ),
    Stop(
      StopId("Q01"),
      "Canal St",
      40.718383,
      -74.00046,
      option.None,
      option.Some(StopId("Q01")),
      Manhattan,
      set.from_list([Q, N]),
      "Uptown",
      "Downtown",
    ),
    Stop(
      StopId("M20"),
      "Canal St",
      40.718092,
      -73.999892,
      option.None,
      option.Some(StopId("M20")),
      Manhattan,
      set.from_list([J, Z]),
      "Brooklyn",
      "Downtown",
    ),
    // Should not be within distance
    Stop(
      id: StopId("625"),
      name: "96 St",
      lat: 40.785672,
      lon: -73.95107,
      location_type: option.None,
      parent_station: option.None,
      borough: Manhattan,
      daytime_routes: set.from_list([N6]),
      north_direction_label: "The Bronx",
      south_direction_label: "Downtown",
    ),
    Stop(
      id: StopId("Q05"),
      name: "96 St",
      lat: 40.784318,
      lon: -73.947152,
      location_type: option.None,
      parent_station: option.None,
      borough: Manhattan,
      daytime_routes: set.from_list([Q]),
      north_direction_label: "Last Stop",
      south_direction_label: "Downtown",
    ),
    Stop(
      id: StopId("626"),
      name: "86 St",
      lat: 40.779492,
      lon: -73.955589,
      location_type: option.None,
      parent_station: option.None,
      borough: Manhattan,
      daytime_routes: set.from_list([N5, N4, N6]),
      north_direction_label: "Uptown",
      south_direction_label: "Downtown",
    ),
    Stop(
      id: StopId("624"),
      name: "103 St",
      lat: 40.7906,
      lon: -73.947478,
      location_type: option.None,
      parent_station: option.None,
      borough: Manhattan,
      daytime_routes: set.from_list([N6]),
      north_direction_label: "The Bronx",
      south_direction_label: "Downtown",
    ),
  ]
}

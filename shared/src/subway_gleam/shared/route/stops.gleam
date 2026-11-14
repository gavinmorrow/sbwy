import gleam/dict
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/element/keyed

import subway_gleam/gtfs/st
import subway_gleam/gtfs/st/route.{type Route}
import subway_gleam/gtfs/st_extra
import subway_gleam/shared/component/navbar.{navbar}
import subway_gleam/shared/component/route_bullet
import subway_gleam/shared/ffi/geolocation
import subway_gleam/shared/util/haversine
import subway_gleam/shared/util/stop_id_json

pub type Model {
  Model(
    all_stations: List(st.Station),
    stop_routes: dict.Dict(st.StopId, List(route_bullet.RouteBullet)),
    cur_position: option.Option(geolocation.Position),
    fav_stations: List(StationLi),
  )
}

pub fn view(model: Model) -> element.Element(msg) {
  let Model(all_stations:, stop_routes:, cur_position:, fav_stations:) = model

  // DEBUG
  // let cur_position =
  //   geolocation.Position(
  //     latitude: 40.7127667,
  //     longitude: -74.0060544,
  //     accuracy: 10.0,
  //     // Okay to use epoch bc this is for debugging
  //     timestamp: timestamp.unix_epoch,
  //   )
  //   |> option.Some

  // Automatically add in routes
  let station_li = fn(station: StationLi) {
    let routes = stop_routes |> dict.get(station.id) |> result.unwrap(or: [])
    station_li(station, routes)
  }

  let stations_nearby =
    option.map(cur_position, fn(pos) {
      all_stations
      |> list.filter(keeping: fn(station) {
        station_distance(station, pos:) <. 800.0
      })
      |> list.sort(by: fn(a, b) {
        float.compare(
          station_distance(a, pos:),
          with: station_distance(b, pos:),
        )
      })
      |> list.map(fn(station) {
        station_li(StationLi(id: station.id, name: station.name))
      })
    })
  let stations_nearby = case stations_nearby {
    option.Some(lis) -> keyed.ol([attribute.class("stations-nearby-list")], lis)
    option.None -> html.p([], [html.em([], [html.text("No stations nearby.")])])
  }

  let fav_stations = list.map(fav_stations, with: station_li)
  let fav_stations = case fav_stations {
    [] -> html.p([], [html.em([], [html.text("No favorite stations.")])])
    lis -> keyed.ol([attribute.class("favorite-stations-list")], lis)
  }

  element.fragment([
    html.div([], [
      html.h1([], [html.text("Stations")]),
      html.h2([], [html.text("Favorites")]),
      fav_stations,
      html.h2([], [html.text("Nearby")]),
      stations_nearby,
      navbar(),
    ]),
    html.hr([]),
    html.p([], [
      html.text("To learn more about sbwy, visit the "),
      html.a([attribute.href("/")], [html.text("home page")]),
      html.text("."),
    ]),
  ])
}

pub type StationLi {
  StationLi(id: st.StopId, name: String)
}

pub fn station_li_decoder() -> decode.Decoder(StationLi) {
  use id <- decode.field("id", decode.string |> decode.map(st.StopId))
  use name <- decode.field("name", decode.string)
  decode.success(StationLi(id:, name:))
}

pub fn station_li_to_json(station_li: StationLi) -> json.Json {
  let StationLi(id:, name:) = station_li
  let st.StopId(id) = id
  json.object([
    #("id", json.string(id)),
    #("name", json.string(name)),
  ])
}

fn station_li(
  station: StationLi,
  routes: List(route_bullet.RouteBullet),
) -> #(String, element.Element(msg)) {
  let id = station.id |> st.stop_id_to_string(option.None)
  // TODO: url function
  let url = "/stop/" <> id <> "/"
  let routes =
    list.map(routes, route_bullet.route_bullet)
    |> html.div([], _)

  #(
    id,
    html.li([], [
      html.a([attribute.href(url)], [
        html.text(station.name),
        routes,
      ]),
    ]),
  )
}

/// The distance between a station and a position, in meters.
fn station_distance(
  station: st.Station,
  pos pos: geolocation.Position,
) -> Float {
  // TODO: account for pos accuracy
  let distance_km =
    haversine.distance(from: #(station.lat, station.lon), to: #(
      pos.latitude,
      pos.longitude,
    ))
  distance_km *. 1000.0
}

pub fn model_decoder() -> decode.Decoder(Model) {
  use all_stations <- decode.field(
    "all_stations",
    decode.list(of: station_decoder()),
  )
  use stop_routes <- decode.field(
    "stop_routes",
    decode.dict(stop_id_json.decoder(), decode.list(of: route_bullet.decoder())),
  )

  Model(
    all_stations:,
    stop_routes:,
    cur_position: option.None,
    fav_stations: [],
  )
  |> decode.success
}

pub fn model_to_json(model: Model) -> json.Json {
  let Model(
    all_stations: all_stations,
    stop_routes:,
    cur_position: _,
    fav_stations: _,
  ) = model
  json.object([
    #("all_stations", json.array(from: all_stations, of: station_to_json)),
    #(
      "stop_routes",
      json.dict(stop_routes, stop_id_json.to_dict_key, json.array(
        _,
        of: route_bullet.to_json,
      )),
    ),
  ])
}

fn station_decoder() -> decode.Decoder(st.Station) {
  let float_or_int_decoder =
    decode.one_of(decode.float, or: [decode.int |> decode.map(int.to_float)])

  use id <- decode.field("id", decode.string |> decode.map(st.StopId))
  use name <- decode.field("name", decode.string)
  use lat <- decode.field("lat", float_or_int_decoder)
  use lon <- decode.field("lon", float_or_int_decoder)
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

  st.Station(
    id:,
    name:,
    lat:,
    lon:,
    location_type: option.None,
    parent_station: option.None,
    borough:,
    daytime_routes:,
    north_direction_label:,
    south_direction_label:,
  )
  |> decode.success
}

fn station_to_json(station: st.Station) -> json.Json {
  let st.Station(
    id:,
    name:,
    lat:,
    lon:,
    location_type: _,
    parent_station: _,
    borough:,
    daytime_routes:,
    north_direction_label:,
    south_direction_label:,
  ) = station
  let st.StopId(id) = id

  json.object([
    #("id", json.string(id)),
    #("name", json.string(name)),
    #("lat", json.float(lat)),
    #("lon", json.float(lon)),
    #("borough", borough_to_json(borough)),
    #(
      "daytime_routes",
      json.preprocessed_array(
        daytime_routes |> set.to_list |> list.map(route_to_json),
      ),
    ),
    #("north_direction_label", json.string(north_direction_label)),
    #("south_direction_label", json.string(south_direction_label)),
  ])
}

fn borough_decoder() -> decode.Decoder(st_extra.Borough) {
  use borough <- decode.then(decode.string)
  case borough {
    "Manhattan" -> st_extra.Manhattan |> decode.success
    "Brooklyn" -> st_extra.Brooklyn |> decode.success
    "Queens" -> st_extra.Queens |> decode.success
    "Bronx" -> st_extra.Bronx |> decode.success
    "StatenIsland" -> st_extra.StatenIsland |> decode.success
    _ -> decode.failure(st_extra.Manhattan, "Borough")
  }
}

fn borough_to_json(borough: st_extra.Borough) -> json.Json {
  json.string(case borough {
    st_extra.Manhattan -> "Manhattan"
    st_extra.Brooklyn -> "Brooklyn"
    st_extra.Queens -> "Queens"
    st_extra.Bronx -> "Bronx"
    st_extra.StatenIsland -> "StatenIsland"
  })
}

fn route_decoder() -> decode.Decoder(Route) {
  use long_id <- decode.then(decode.string)
  case route.from_long_id(long_id) {
    Ok(route) -> decode.success(route)
    Error(Nil) -> decode.failure(route.A, "Route")
  }
}

fn route_to_json(route: Route) -> json.Json {
  let long_id = route.to_long_id(route)
  json.string(long_id)
}

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
    all_stops: List(st.Stop),
    stop_routes: dict.Dict(st.StopId, List(route_bullet.RouteBullet)),
    cur_position: option.Option(geolocation.Position),
    fav_stops: List(StopLi),
  )
}

pub fn view(model: Model) -> element.Element(msg) {
  let Model(all_stops:, stop_routes:, cur_position:, fav_stops:) = model

  // DEBUG
  // let cur_position =
  //   geolocation.Position(
  //     latitude: 40.7127667,
  //     longitude: -74.0060544,
  //     accuracy: 10.0,
  //     // Okay to use current time bc this is for debugging
  //     timestamp: util.current_time(),
  //   )
  //   |> option.Some

  // Automatically add in routes
  let stop_li = fn(stop: StopLi) {
    let routes = stop_routes |> dict.get(stop.id) |> result.unwrap(or: [])
    stop_li(stop, routes)
  }

  let stops_nearby =
    option.map(cur_position, fn(pos) {
      all_stops
      |> list.filter(keeping: fn(stop) { stop_distance(stop, pos:) <. 800.0 })
      |> list.sort(by: fn(a, b) {
        float.compare(stop_distance(a, pos:), with: stop_distance(b, pos:))
      })
      |> list.map(fn(stop) { stop_li(StopLi(id: stop.id, name: stop.name)) })
    })
  let stops_nearby = case stops_nearby {
    option.Some(lis) -> keyed.ol([attribute.class("stops-nearby-list")], lis)
    option.None -> html.p([], [html.text("No stops nearby.")])
  }

  let fav_stops = list.map(fav_stops, with: stop_li)
  let fav_stops = case fav_stops {
    [] -> html.p([], [html.text("No favorite stops.")])
    lis -> keyed.ol([attribute.class("favorite-stops-list")], lis)
  }

  html.div([], [
    html.h1([], [html.text("Stops")]),
    html.h2([], [html.text("Favorites")]),
    fav_stops,
    html.h2([], [html.text("Nearby")]),
    stops_nearby,
    navbar(),
  ])
}

pub type StopLi {
  StopLi(id: st.StopId, name: String)
}

pub fn stop_li_decoder() -> decode.Decoder(StopLi) {
  use id <- decode.field("id", decode.string |> decode.map(st.StopId))
  use name <- decode.field("name", decode.string)
  decode.success(StopLi(id:, name:))
}

pub fn stop_li_to_json(stop_li: StopLi) -> json.Json {
  let StopLi(id:, name:) = stop_li
  let st.StopId(id) = id
  json.object([
    #("id", json.string(id)),
    #("name", json.string(name)),
  ])
}

fn stop_li(
  stop: StopLi,
  routes: List(route_bullet.RouteBullet),
) -> #(String, element.Element(msg)) {
  let id = stop.id |> st.stop_id_to_string(option.None)
  let url = "/stop/" <> id <> "/"
  let routes =
    list.map(routes, route_bullet.route_bullet)
    |> html.div([], _)

  #(
    id,
    html.li([], [
      html.a([attribute.href(url)], [
        html.text(stop.name),
        routes,
      ]),
    ]),
  )
}

/// The distance between a stop and a position, in meters.
fn stop_distance(stop: st.Stop, pos pos: geolocation.Position) -> Float {
  // TODO: account for pos accuracy
  let distance_km =
    haversine.distance(from: #(stop.lat, stop.lon), to: #(
      pos.latitude,
      pos.longitude,
    ))
  distance_km *. 1000.0
}

pub fn model_decoder() -> decode.Decoder(Model) {
  use all_stops <- decode.field("all_stops", decode.list(of: stop_decoder()))
  use stop_routes <- decode.field(
    "stop_routes",
    decode.dict(stop_id_json.decoder(), decode.list(of: route_bullet.decoder())),
  )

  Model(all_stops:, stop_routes:, cur_position: option.None, fav_stops: [])
  |> decode.success
}

pub fn model_to_json(model: Model) -> json.Json {
  let Model(all_stops:, stop_routes:, cur_position: _, fav_stops: _) = model
  json.object([
    #("all_stops", json.array(from: all_stops, of: stop_to_json)),
    #(
      "stop_routes",
      json.dict(stop_routes, stop_id_json.to_dict_key, json.array(
        _,
        of: route_bullet.to_json,
      )),
    ),
  ])
}

fn stop_decoder() -> decode.Decoder(st.Stop) {
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

  st.Stop(
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

fn stop_to_json(stop: st.Stop) -> json.Json {
  let st.Stop(
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
  ) = stop
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

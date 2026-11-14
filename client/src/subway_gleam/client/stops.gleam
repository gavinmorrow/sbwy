import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import lustre
import lustre/effect.{type Effect}
import plinth/browser/document
import plinth/browser/element
import plinth/javascript/storage

import subway_gleam/shared/ffi/geolocation
import subway_gleam/shared/route/stops.{type Model, Model, view}

pub fn main() -> Result(lustre.Runtime(Msg), lustre.Error) {
  // TODO: handle errors: model not found, and invalid JSON
  let assert Ok(Ok(model)) =
    document.get_element_by_id("model")
    |> result.map(element.inner_text)
    |> result.map(json.parse(from: _, using: stops.model_decoder()))

  // TODO: handle (or log?) various errors here
  let fav_stations = result.unwrap(get_fav_stations(), or: [])
  let model = Model(..model, fav_stations:)

  let app = lustre.application(init, update, view)
  lustre.start(app, onto: "#app", with: model)
}

fn get_fav_stations() -> Result(List(stops.StationLi), Nil) {
  use storage <- result.try(storage.local())
  // TODO: migrate from fav_stops to fav_stations?
  use fav_stations <- result.try(storage.get_item(storage, "fav_stops"))
  json.parse(
    from: fav_stations,
    using: decode.list(of: stops.station_li_decoder()),
  )
  |> result.replace_error(Nil)
}

fn update_fav_stations(
  with fun: fn(List(stops.StationLi)) -> List(stops.StationLi),
) -> Result(Nil, Nil) {
  use storage <- result.try(storage.local())
  let fav_stations = result.unwrap(get_fav_stations(), or: [])
  let fav_stations = fun(fav_stations)
  storage.set_item(
    storage,
    // TODO: migrate from fav_stops to fav_stations?
    "fav_stops",
    fav_stations |> json.array(of: stops.station_li_to_json) |> json.to_string,
  )
}

pub fn add_fav_station(station: stops.StationLi) -> Result(Nil, Nil) {
  use fav_stations <- update_fav_stations
  [station, ..fav_stations]
}

pub fn remove_fav_station(station: stops.StationLi) -> Result(Nil, Nil) {
  use fav_stations <- update_fav_stations
  list.filter(fav_stations, keeping: fn(s) { s != station })
}

pub fn is_fav_station(station: stops.StationLi) -> Bool {
  get_fav_stations() |> result.unwrap(or: []) |> list.contains(station)
}

pub type Msg {
  UpdatePosition(geolocation.Position)
}

fn init(flags: Model) -> #(Model, effect.Effect(Msg)) {
  #(flags, watch_position())
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    UpdatePosition(cur_position) -> #(
      Model(..model, cur_position: option.Some(cur_position)),
      effect.none(),
    )
  }
}

fn watch_position() -> Effect(Msg) {
  use dispatch <- effect.from
  let _id =
    geolocation.watch_position(
      on_success: fn(pos) { dispatch(UpdatePosition(pos)) },
      on_error: fn(_err) { todo },
    )
  Nil
}

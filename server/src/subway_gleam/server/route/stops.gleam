import gleam/dict
import gleam/list
import gleam/option
import gleam/set
import lustre/attribute
import lustre/element/html
import wisp

import subway_gleam/gtfs/st
import subway_gleam/server/hydration_scripts.{hydration_scripts}
import subway_gleam/server/lustre_middleware.{Document}
import subway_gleam/server/state
import subway_gleam/shared/component/route_bullet
import subway_gleam/shared/route/stops

pub fn stops(req: wisp.Request, state: state.State) -> wisp.Response {
  use _req <- lustre_middleware.lustre_res(req)

  let all_stops =
    state.schedule.stops
    |> dict.values
  let stop_routes =
    state.schedule.stops
    // Transform into expected shape
    |> dict.fold(from: dict.new(), with: fn(acc, stop_id, stop) {
      let routes =
        set.map(stop.daytime_routes, st.route_data(for: _, in: state.schedule))
        |> set.to_list
        |> list.sort(by: st.route_compare)
        |> list.map(route_bullet.from_route_data)

      dict.insert(routes, into: acc, for: stop_id)
    })

  let model =
    stops.Model(
      all_stops:,
      stop_routes:,
      cur_position: option.None,
      fav_stops: [],
    )

  let head = [
    html.title([], "Stops"),
    hydration_scripts("stops", stops.model_to_json(model)),
  ]
  let body = [html.div([attribute.id("app")], [stops.view(model)])]

  #(Document(head:, body:), wisp.response(200))
}

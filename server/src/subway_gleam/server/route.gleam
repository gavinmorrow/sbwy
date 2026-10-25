import gleam/http/response
import gleam/option
import lustre/attribute
import lustre/element/html
import wisp

import subway_gleam/server/lustre_middleware.{Body, lustre_res}
import subway_gleam/server/route/line
import subway_gleam/server/route/stop
import subway_gleam/server/route/stop/alerts
import subway_gleam/server/route/stops
import subway_gleam/server/route/train
import subway_gleam/shared/component/navbar.{navbar}

pub fn index(_req: wisp.Request) -> wisp.Response {
  let assert Ok(priv_dir) = wisp.priv_directory("subway_gleam")
    as "priv_dir should exist"
  let path = priv_dir <> "/index.html"
  response.new(200)
  |> response.set_header("content-type", "text/html; charset=utf-8")
  |> response.set_body(wisp.File(path:, offset: 0, limit: option.None))
}

pub fn health(_req: wisp.Request) -> wisp.Response {
  wisp.ok()
  |> wisp.set_header("cache-control", "no-cache")
  |> wisp.set_body(wisp.Text("200 OK"))
}

pub fn not_found(req: wisp.Request) -> wisp.Response {
  use _req <- lustre_res(req)

  let body = [
    html.p([], [
      html.text("404 not found :["),
    ]),
    navbar(),
  ]
  let res = wisp.response(404)

  #(Body(body:), res)
}

pub fn map(req: wisp.Request) -> wisp.Response {
  use _req <- lustre_res(req)

  let body = [
    html.img([
      attribute.id("subway-diagram"),
      attribute.src("/static/subway-diagram.webp"),
    ]),
    navbar(),
  ]
  let res = wisp.response(200)

  #(Body(body:), res)
}

pub const stops = stops.stops

pub const stop = stop.stop

pub const stop_alerts = alerts.alerts

pub const train = train.train

pub const line = line.line

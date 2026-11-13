import gleam/bool
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import subway_gleam/gtfs/st
import subway_gleam/shared/component/arrival_time
import subway_gleam/shared/component/route_bullet.{
  type RouteBullet, route_bullet,
}
import subway_gleam/shared/util
import subway_gleam/shared/util/time.{type Time}
import subway_gleam/shared/util/timestamp_json

// TODO: finish extracting from train.gleam

pub type Stop {
  Stop(
    id: st.StopId,
    name: String,
    stop_url: String,
    transfers: List(RouteBullet),
    time: Timestamp,
    dimmed: Bool,
  )
}

pub fn decoder() -> decode.Decoder(Stop) {
  use id <- decode.field("id", decode.string |> decode.map(st.StopId))
  use name <- decode.field("name", decode.string)
  use stop_url <- decode.field("stop_url", decode.string)
  use transfers <- decode.field(
    "transfers",
    decode.list(route_bullet.decoder()),
  )
  use time <- decode.field("time", timestamp_json.decoder())
  use dimmed <- decode.field("dimmed", decode.bool)

  decode.success(Stop(id:, name:, stop_url:, transfers:, time:, dimmed:))
}

pub fn to_json(stop: Stop) -> json.Json {
  let Stop(id:, name:, stop_url:, transfers:, time:, dimmed:) = stop
  let st.StopId(id) = id

  json.object([
    #("id", json.string(id)),
    #("name", json.string(name)),
    #("stop_url", json.string(stop_url)),
    #("transfers", json.array(transfers, route_bullet.to_json)),
    #("time", timestamp_json.to_json(time)),
    #("dimmed", json.bool(dimmed)),
  ])
}

pub fn li(
  stop: Stop,
  highlighted_stop: Option(st.StopId),
  cur_time: Time,
) -> Result(#(String, Element(msg)), Nil) {
  let Stop(id:, name:, stop_url:, transfers:, time:, dimmed:) = stop

  let dt = util.min_from(time, epoch: cur_time.timestamp)
  use <- bool.guard(when: dt < 0, return: Error(Nil))

  let transfers = list.map(transfers, route_bullet)
  let is_highlighted = option.Some(id) == highlighted_stop

  let st.StopId(id) = id
  #(
    id,
    html.li([], [
      html.a(
        [
          attribute.href(stop_url),
          attribute.classes([
            #("highlight", is_highlighted),
            #("dimmed", dimmed),
          ]),
        ],
        [
          html.span([attribute.class("name")], [
            html.text(name),
            html.span([attribute.class("transfers")], transfers),
          ]),
          arrival_time.arrival_time(arriving_at: time, cur_time:),
        ],
      ),
    ]),
  )
  |> Ok
}

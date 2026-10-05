import birdie
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import lustre/dev/query.{type Query}
import lustre/dev/simulate
import lustre/effect
import lustre/element
import subway_gleam/gtfs/rt
import subway_gleam/gtfs/st
import subway_gleam/shared/component/route_bullet
import subway_gleam/shared/util/live_status
import subway_gleam/shared/util/time.{type Time, Time}

import subway_gleam/client/stop.{type Msg, ToggleFavBtnPressed, update} as _
import subway_gleam/shared/route/stop.{
  type Arrival, type Model, Arrival, Model, Transfer, view,
} as _

pub fn arrivals_are_in_correct_format_test() -> Nil {
  let html =
    view(
      Model(..default_model(), uptown: arrival_times() |> list.map(arrival)),
      Nil,
    )
  let lis =
    query.find_all(
      query.descendant(of: arrival_lis(), matching: query.class("arrival-time")),
      in: html,
    )
  birdie.snap(
    title: "Times (absolute and countdown) are in hh:mm+? and <int>m format.",
    content: list.map(lis, element.to_string) |> string.join("\n"),
  )
}

pub fn transfer_for_current_stop_is_highlighted_test() -> Nil {
  let transfer = Transfer(destination: stop_id_a27, routes: [route_bullet_a])

  let app =
    simulate(
      Model(..default_model(), transfers: [
        Transfer(destination: st.StopId("0"), routes: []),
        transfer,
        Transfer(destination: st.StopId("1"), routes: []),
        Transfer(destination: st.StopId("2"), routes: []),
      ]),
    )

  let transfers = query.find_all(transfers(), in: simulate.view(app))
  let highlighted =
    list.map(transfers, fn(transfer) {
      transfer |> query.matches(query.class("highlight"))
    })

  assert highlighted == [False, True, False, False]
}

pub fn highlighted_train_is_highlighted_test() -> Nil {
  let highlighted =
    Arrival(
      train_id: rt.TripId(int.random(1000) |> int.to_string),
      train_url: "",
      route: route_bullet_a,
      headsign: Error(Nil),
      time: timestamp.add(unix_epoch().timestamp, duration.minutes(2)),
    )

  let app =
    simulate(
      Model(
        ..default_model(),
        uptown: [
          arrival(in: duration.seconds(5)),
          highlighted,
          arrival(in: duration.minutes(10)),
        ],
        downtown: [
          arrival(in: duration.minutes(2)),
          arrival(in: duration.hours(1)),
        ],
        highlighted_train: option.Some(highlighted.train_id),
      ),
    )

  let lists = query.find_all(arrival_lists(), in: simulate.view(app))
  let highlights =
    list.map(lists, fn(list) {
      query.find_all(arrival_lis(), in: list)
      |> list.map(query.has(_, query.class("highlight")))
    })

  assert highlights == [[False, True, False], [False, False]]
}

fn arrival_lis_class_test(class: String) -> List(Bool) {
  let app = simulate(model_with_arrival_times(arrival_times(), []))
  simulate.view(app)
  |> query.find_all(arrival_lis(), in: _)
  |> list.map(query.has(_, query.class(class)))
}

pub fn arriving_now_signified_test() -> Nil {
  assert arrival_lis_class_test("arriving-now")
    // Arrivals in past shouldn't be present at all, so it starts with True
    == [True, True, False, False, False, False]
}

pub fn arriving_very_soon_signified_test() -> Nil {
  assert arrival_lis_class_test("arriving-very-soon")
    // Arrivals in past shouldn't be present at all, so it starts with True
    == [True, True, True, True, False, False]
}

pub fn arriving_soon_signified_test() -> Nil {
  assert arrival_lis_class_test("arriving-soon")
    // Arrivals in past shouldn't be present at all, so it starts with True
    == [True, True, True, True, True, False]
}

fn arrival_times() -> List(duration.Duration) {
  [
    // Departed
    duration.minutes(-1),
    duration.seconds(-31),
    // Arriving now
    duration.seconds(-5),
    duration.seconds(22),
    // Arriving very soon
    duration.seconds(31),
    duration.minutes(5),
    // Arriving soon
    duration.minutes(10),
    // Later arrivals
    duration.hours(1),
  ]
}

fn simulate(model: Model) -> simulate.Simulation(Model, Msg) {
  simulate.application(
    init: fn(_) { #(model, effect.none()) },
    update:,
    view: view(_, ToggleFavBtnPressed),
  )
  |> simulate.start(Nil)
}

fn model_with_arrival_times(
  uptown: List(duration.Duration),
  downtown: List(duration.Duration),
) -> Model {
  Model(
    ..default_model(),
    uptown: list.map(uptown, arrival(in: _)),
    downtown: list.map(downtown, arrival(in: _)),
  )
}

const stop_id_a27 = st.StopId("A27")

fn default_model() -> Model {
  Model(
    id: stop_id_a27,
    name: "42 St-Port Authority Bus Terminal",
    last_updated: unix_epoch(),
    transfers: [],
    alerted_routes: [],
    alert_summary: "",
    uptown: [],
    downtown: [],
    north_direction_label: "Uptown",
    south_direction_label: "Downtown",
    highlighted_train: option.None,
    event_source: live_status.Unavailable,
    cur_time: unix_epoch(),
    is_fav: False,
  )
}

fn unix_epoch() -> Time {
  Time(timestamp.unix_epoch, Ok(duration.hours(-4)))
}

const route_bullet_a = route_bullet.RouteBullet(
  text: "A",
  shape: st.Circle,
  color: "#0062CF",
  text_color: "white",
)

fn arrival(in time: duration.Duration) -> Arrival {
  Arrival(
    train_id: rt.TripId(int.random(1000) |> int.to_string),
    train_url: "",
    route: route_bullet_a,
    headsign: Error(Nil),
    time: timestamp.add(unix_epoch().timestamp, time),
  )
}

fn arrival_lists() -> Query {
  query.element(query.class("arrival-list"))
}

fn arrival_lis() -> Query {
  query.child(of: arrival_lists(), matching: query.tag("li"))
}

fn transfers() -> Query {
  query.element(query.id("transfers"))
  |> query.descendant(matching: query.class("bullet-group"))
}

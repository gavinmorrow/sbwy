import gleam/int
import gleam/list
import gleam/option
import gleam/time/duration
import gleam/time/timestamp
import lustre/dev/query.{type Query}
import lustre/dev/simulate
import lustre/effect
import subway_gleam/gtfs/rt
import subway_gleam/gtfs/st
import subway_gleam/shared/component/route_bullet
import subway_gleam/shared/util/live_status
import subway_gleam/shared/util/time.{type Time, Time}

import subway_gleam/client/stop.{type Msg, ToggleFavBtnPressed, update} as _
import subway_gleam/shared/route/stop.{
  type Arrival, type Model, Arrival, Model, view,
} as _

fn simulate(model: Model) -> simulate.Simulation(Model, Msg) {
  simulate.application(
    init: fn(_) { #(model, effect.none()) },
    update:,
    view: view(_, ToggleFavBtnPressed),
  )
  |> simulate.start(Nil)
}

pub fn arriving_now_signified_test() -> Nil {
  // Arrivals in past shouldn't be present at all, so it starts with True
  assert test_arrival_li_classes("arriving-now")
    == [True, True, False, False, False, False]
}

pub fn arriving_very_soon_signified_test() -> Nil {
  // Arrivals in past shouldn't be present at all, so it starts with True
  assert test_arrival_li_classes("arriving-very-soon")
    == [True, True, True, True, False, False]
}

pub fn arriving_soon_signified_test() -> Nil {
  // Arrivals in past shouldn't be present at all, so it starts with True
  assert test_arrival_li_classes("arriving-soon")
    == [True, True, True, True, True, False]
}

fn test_arrival_li_classes(class: String) -> List(Bool) {
  let arrival_times = [
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
  let app =
    simulate(Model(
      id: st.StopId("A27"),
      name: "42 St-Port Authority Bus Terminal",
      last_updated: unix_epoch,
      transfers: [],
      alerted_routes: [],
      alert_summary: "",
      uptown: list.map(arrival_times, arrival(in: _)),
      downtown: [],
      north_direction_label: "Uptown",
      south_direction_label: "Downtown",
      highlighted_train: option.None,
      event_source: live_status.Unavailable,
      cur_time: unix_epoch,
      is_fav: False,
    ))

  query.find_all(arrival_lis(), in: simulate.view(app))
  |> list.map(query.has(_, query.class(class)))
}

const unix_epoch: Time = Time(timestamp.unix_epoch, Error(Nil))

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
    time: timestamp.add(unix_epoch.timestamp, time),
  )
}

fn arrival_lists() -> Query {
  query.element(query.class("arrival-list"))
}

fn arrival_lis() -> Query {
  query.child(of: arrival_lists(), matching: query.tag("li"))
}

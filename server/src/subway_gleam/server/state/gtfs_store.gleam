import gleam/dict
import gleam/erlang/atom
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/result
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}

import subway_gleam/gtfs/rt
import subway_gleam/gtfs/st
import subway_gleam/server/gtfs/fetch_rt
import subway_gleam/server/log
import subway_gleam/server/state/table.{type Table}
import subway_gleam/shared/util

pub opaque type GtfsStore {
  // TODO: feels a little weird to have this live in a table
  GtfsStore(data: Data, watchers: Table(process.Subject(Nil), Nil))
}

pub opaque type Data {
  Data(
    arrivals: Table(st.StopId, List(#(rt.Trip, rt.TrainStopping))),
    final_stops: Table(st.ShapeId, st.StopId),
    trips: Table(rt.TripId, #(rt.Trip, List(rt.TrainStopping))),
    // TODO: find an actual key to use
    alerts: Table(Nil, List(rt.Alert)),
    // TODO: feels hacky to have a table with only one item
    last_updated: Table(Nil, Timestamp),
  )
}

/// **Must be called at most once**, or an error will be thrown because the
/// tables already exist.
pub fn init() -> GtfsStore {
  GtfsStore(
    data: Data(
      table.new("arrivals" |> atom.create),
      table.new("final_stops" |> atom.create),
      table.new("trips" |> atom.create),
      table.new("alerts" |> atom.create),
      table.new("last_updated" |> atom.create)
        |> table.insert(timestamp.unix_epoch, for: Nil),
    ),
    watchers: table.new("watchers" |> atom.create),
  )
}

/// This cannot be used until *after* `init()` is called.
pub fn new() -> GtfsStore {
  let data =
    Data(
      table.from_name("arrivals" |> atom.create),
      table.from_name("final_stops" |> atom.create),
      table.from_name("trips" |> atom.create),
      table.from_name("alerts" |> atom.create),
      table.from_name("last_updated" |> atom.create),
    )
  let watchers = table.from_name("watchers" |> atom.create)
  GtfsStore(data:, watchers:)
}

pub fn get(from store: GtfsStore) -> Data {
  store.data
}

pub fn update(store: GtfsStore) -> Nil {
  let start_time = timestamp.system_time()
  log.debug("Starting gtfs rt update...", with: log.new_context())
  // TODO: is this OTP compliant?
  // If this process crashes it shouldn't take down the main process
  process.spawn_unlinked(fn() {
    use #(rt.Data(arrivals:, final_stops:, trips:, alerts:), last_updated) <- result.map(
      fetch_all_rt_feeds(),
    )
    let arrivals = dict.to_list(arrivals)
    let final_stops = dict.to_list(final_stops)
    let trips = dict.to_list(trips)
    let alerts = [#(Nil, alerts)]

    // Update data
    // TODO: this is non-atomic. data will update before last-updated is set.
    //       Maybe make one table and make a larger Key type?
    table.replace_all_items(in: store.data.arrivals, with: arrivals)
    table.replace_all_items(in: store.data.final_stops, with: final_stops)
    table.replace_all_items(in: store.data.trips, with: trips)
    table.replace_all_items(in: store.data.alerts, with: alerts)
    table.insert(last_updated, into: store.data.last_updated, for: Nil)

    // Notify watchers
    store.watchers
    |> table.each(fn(subject, _: Nil) { process.send(subject, Nil) })

    let end_time = timestamp.system_time()
    let duration = timestamp.difference(start_time, end_time)
    log.debug(
      "Finished gtfs rt update.",
      with: log.context([
        #(
          "duration",
          duration.to_milliseconds(duration) |> int.to_string <> "ms",
        ),
      ]),
    )
  })
  Nil
}

pub fn subscribe_watcher(
  to store: GtfsStore,
  watcher watcher: process.Subject(Nil),
) -> Nil {
  table.insert(watcher, into: store.watchers, insert: Nil)
  // Send an update immediately after connecting
  // Sometimes it will be useless, but if it's a reconnection then it will help
  process.send(watcher, Nil)
}

pub fn unsubscribe_watcher(
  from store: GtfsStore,
  watcher watcher: process.Subject(Nil),
) -> Nil {
  table.delete_item(watcher, in: store.watchers)
  Nil
}

fn fetch_all_rt_feeds() -> Result(#(rt.Data, Timestamp), rt.FetchGtfsError) {
  let current_time = util.current_time()

  use data <- result.try(
    list.try_fold(
      over: rt.all_feeds,
      from: rt.empty_data(),
      with: fn(acc, feed) {
        use rt <- result.map(
          fetch_rt.fetch_gtfs(feed:)
          |> result.map(rt.analyze),
        )
        acc |> rt.data_merge(from: rt)
      },
    ),
  )

  #(data, current_time) |> Ok
}

pub fn arrivals(
  data: Data,
  for stop: st.StopId,
) -> Result(List(#(rt.Trip, rt.TrainStopping)), Nil) {
  data.arrivals |> table.get(stop)
}

pub fn final_stop(
  data: Data,
  for shape_id: st.ShapeId,
) -> Result(st.StopId, Nil) {
  data.final_stops |> table.get(shape_id)
}

pub fn trip(
  data: Data,
  for trip_id: rt.TripId,
) -> Result(#(rt.Trip, List(rt.TrainStopping)), Nil) {
  data.trips |> table.get(trip_id)
}

pub fn alerts(data: Data) -> Result(List(rt.Alert), Nil) {
  data.alerts |> table.get(Nil)
}

pub fn last_updated(data: Data) -> Result(Timestamp, Nil) {
  data.last_updated |> table.get(Nil)
}

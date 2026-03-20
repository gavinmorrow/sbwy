import gleam/result
import gleam/time/duration.{type Duration}
import gleam/time/timestamp.{type Timestamp}
import tzif/database.{type TzDatabase}
import tzif/tzcalendar

import subway_gleam/shared/util
import subway_gleam/shared/util/time.{type Time, Time}

pub fn new_york_offset(
  tz_db tz_db: TzDatabase,
  at time: Timestamp,
) -> Result(Duration, Nil) {
  use tz <- result.map(
    tzcalendar.to_time_and_zone(time, "America/New_York", tz_db)
    |> result.replace_error(Nil),
  )
  tz.offset
}

pub fn now(tz_db: database.TzDatabase) -> Time {
  let timestamp = util.current_time()
  Time(timestamp:, time_zone_offset: tz_db |> new_york_offset(at: timestamp))
}

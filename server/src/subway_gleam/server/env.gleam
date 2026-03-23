import envoy
import gleam/int
import gleam/result
import gleam/time/duration
import logging

pub fn host() -> String {
  envoy.get("host")
  |> result.unwrap(or: "127.0.0.1")
}

pub fn http_port() -> Int {
  envoy.get("http_port")
  |> result.try(int.parse)
  |> result.unwrap(or: 8080)
}

pub fn https_port() -> Int {
  envoy.get("https_port")
  |> result.try(int.parse)
  |> result.unwrap(or: 4433)
}

pub fn certfile() -> Result(String, Nil) {
  envoy.get("certfile")
}

pub fn keyfile() -> Result(String, Nil) {
  envoy.get("keyfile")
}

pub fn log_level() {
  case envoy.get("log_level") {
    Ok("emergency") -> Ok(logging.Emergency)
    Ok("alert") -> Ok(logging.Alert)
    Ok("critical") -> Ok(logging.Critical)
    Ok("error") -> Ok(logging.Error)
    Ok("warning") -> Ok(logging.Warning)
    Ok("notice") -> Ok(logging.Notice)
    Ok("info") -> Ok(logging.Info)
    Ok("debug") -> Ok(logging.Debug)
    _ -> Error(Nil)
  }
}

pub fn log_tz_offset() -> Result(duration.Duration, Nil) {
  envoy.get("log_tz_offset")
  |> result.try(int.parse)
  |> result.map(duration.hours)
}

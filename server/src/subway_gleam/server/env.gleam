import envoy
import gleam/int
import gleam/result
import logging

pub fn host() -> String {
  case envoy.get("host") {
    Ok(host) -> host
    Error(Nil) -> "127.0.0.1"
  }
}

pub fn http_port() -> Int {
  case envoy.get("http_port") |> result.try(int.parse) {
    Ok(port) -> port
    Error(Nil) -> 8080
  }
}

pub fn https_port() -> Int {
  case envoy.get("https_port") |> result.try(int.parse) {
    Ok(port) -> port
    Error(Nil) -> 4433
  }
}

pub fn certfile() -> Result(String, Nil) {
  envoy.get("certfile")
}

pub fn keyfile() -> Result(String, Nil) {
  envoy.get("keyfile")
}

pub fn log_level() {
  envoy.get("log_level")
  |> result.try(fn(level) {
    case level {
      "emergency" -> Ok(logging.Emergency)
      "alert" -> Ok(logging.Alert)
      "critical" -> Ok(logging.Critical)
      "error" -> Ok(logging.Error)
      "warning" -> Ok(logging.Warning)
      "notice" -> Ok(logging.Notice)
      "info" -> Ok(logging.Info)
      "debug" -> Ok(logging.Debug)
      _ -> Error(Nil)
    }
  })
}

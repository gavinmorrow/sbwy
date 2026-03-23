import gleam/io
import gleam/string
import subway_gleam/server

pub fn main() {
  start(fn() { server.start(sleeping_after: Ok(30 * 1000)) })
  |> string.inspect
  |> io.println
}

@external(erlang, "server_prof_ffi", "start")
fn start(f: fn() -> Nil) -> ffi_type

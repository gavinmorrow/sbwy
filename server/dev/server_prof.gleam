import gleam/io
import gleam/string
import subway_gleam/server

pub fn main() {
  start(server.main) |> string.inspect |> io.println
}

@external(erlang, "server_prof_ffi", "start")
fn start(f: fn() -> Nil) -> ffi_type

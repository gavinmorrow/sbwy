import ewe
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/string

import subway_gleam/server
import subway_gleam/server/log

pub fn main() {
  start(fn() {
    let server = server.server()
    let assert Ok(_) = ewe.start(server)

    let sec = 30
    log.debug(
      "Main process sleeping for " <> int.to_string(sec) <> "sec...",
      with: log.new_context(),
    )
    process.sleep(sec * 1000)
  })
  |> string.inspect
  |> io.println
}

@external(erlang, "server_prof_ffi", "start")
fn start(f: fn() -> Nil) -> ffi_type

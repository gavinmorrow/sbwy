import ewe
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/result
import subway_gleam/server/log

import subway_gleam/server/state
import subway_gleam/server/state/gtfs_store

pub fn sse_gtfs(
  req: request.Request(ewe.Connection),
  state: state.Ref,
  model: fn() -> Result(json.Json, anyerror),
) -> response.Response(ewe.Body) {
  use _req, context <- log.request(req)
  response.new(200)
  // Prevent nginx from buffering SSE responses
  |> response.set_header("X-Accel-Buffering", "no")
  |> ewe.sse(
    on_init: fn(_conn, selector) {
      let self = process.new_subject()
      let state = state.get(state)
      gtfs_store.subscribe_watcher(self, to: state.gtfs_store)
      #(self, process.select(selector, for: self))
    },
    handler: fn(conn, self, _message: Nil) {
      log.debug("Notified of gtfs update; updating model...", with: context)

      let model =
        model()
        |> result.replace_error(Nil)
        |> result.map(json.to_string)

      log.debug("Finished updating model.", with: context)

      let event = model |> result.map(ewe.event)
      case result.map(event, ewe.send_event(conn, _)) {
        Ok(Ok(Nil)) -> {
          log.debug("Sent model.", with: context)
          ewe.continue(self)
        }
        _ -> {
          log.debug(
            "Failed to send model: connection closed; unsubscribing from gtfs store.",
            with: context,
          )
          let state = state.get(state)
          gtfs_store.unsubscribe_watcher(self, from: state.gtfs_store)
          ewe.stop()
        }
      }
    },
    on_close: fn(_conn, self) {
      log.debug(
        "Connection closed; unsubscribing from gtfs store.",
        with: context,
      )
      let state = state.get(state)
      gtfs_store.unsubscribe_watcher(self, from: state.gtfs_store)
    },
  )
}

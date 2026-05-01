# sbwy

This is a little web app to view subway arrival times for the NYC Subway :]

It sends over server-side rendered HTML pages using lustre, which are then
hydrated (if possible) on the client. It aims to be progressively enhanced, and
work without javascript enabled.

## Subprojects

- `server`: The code for the HTTP server. Targets Erlang. Run via
            `gleam run -m subway_gleam/server`. The client must be built first.
- `shared`: Shared code between the server and client. It contains all of the
            lustre view code—ie `fn view()` and `type Model`. This allows for
            server-side rendering.
- `client`: Contains code that runs exclusively in the browser. It contains all
            the interactive bits of lustre code—ie `fn init()`, `fn update()`,
            and `type Msg`. Build with
            `gleam run -m lustre/dev build subway_gleam/client/[route]`.
-   `gtfs`: GTFS parsing code for both static and realtime.

## Development

There are a few [`just`](https://just.systems/) recipes available for use.

To run the project: build the client, start the server, then go to
`localhost:8080` in your web browser of choice. You can also use `just run`.

If this is your first time running it, make sure that the env var are set to
fetch from the internet and save the values to disk. After doing `gleam run`
once followed by `gleam run -m gen_schedule` (inside of `server`), they will
be saved, so development can continue locally without re-fetching and parsing
each time. The folder `./gtfs/src/subway_gleam/gtfs/st/schedule_sample/` may
need to be created. Disable fetch and save to disk afterwards, and only enable
when needed.

### Env vars

| name              | description                                       |
| ----------------- | ------------------------------------------------- | 
| `host`            | The interface to bind to when starting the server |
| `http_port`       | The port to bind to for the HTTP server           |
| `https_port`      | The port to bind to for the HTTPS server          |
| `certfile`        | Path to the `.crt` file. leave unset for no TLS. relative to `server`. |
| `keyfile`         | Path to the `.key` file. leave unset for no TLS. relative to `server`. |
| `gtfs_st`         | If "local": use the cached st data.               |
| `gtfs_rt`         | If "local": use the cached rt data.               |
| `save_fetched_st` | If "true": write fetched st data to disk.         |
| `save_fetched_rt` | If "true": write fetched rt data to disk.         |
| `gtfs_rt_fetch_time` | The unix time in sec the cached rt was fetched at. |
| `log_level`       | The minimum log level to show. Defaults to all.   |
| `log_tz_offset`   | The offset (in hours) from GMT the log timestamps are in. |
| `profile_pages`   | Which pages to enable eflame profiling for.       |
| `profile_funcs`   | If `true`, log the duration of certain functions. |

#### Log Levels

This project uses the Erlang logger. The levels are
emergency/alert/critical/error/warning/notice/info/debug.

#### Profiling

For `profile_pages`, it is a comma-separated list with potential values of:
`stops`, `stop`, `stop_alerts`, and `train`.

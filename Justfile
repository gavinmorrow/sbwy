set dotenv-load
set dotenv-required

check: (server "check") (client "check")

build: (server "build") build-pages

run: build-pages (server "run")

[working-directory: 'server']
server cmd="check":
    gleam {{cmd}} {{ if cmd == "run" { "-m subway_gleam/server" } else { "" } }}

[working-directory: 'client']
client cmd="check":
    gleam {{cmd}}

build-pages: (build-page "stops") (build-page "stop") (build-page "train")

[working-directory: 'client']
build-page name:
    gleam run -m lustre/dev build subway_gleam/client/{{name}}

[working-directory: 'server']
start-prof:
    # Set these env vars here to override .env file
    # the [env()] attribute doesn't seem to override
    https_port=3000 http_port=3003 gtfs_st="local" gleam run -m server_prof

[working-directory: 'server']
start-stop-prof:
    # Set these env vars here to override .env file
    # the [env()] attribute doesn't seem to override
    profile_pages="stops,stop,stop_alerts,train" http_port=3000 gtfs_st="local" gleam run -m subway_gleam/server


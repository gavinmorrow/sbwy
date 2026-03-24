set dotenv-load
set dotenv-required

start: build-client start-server

[working-directory: 'server']
start-server:
    gleam run -m subway_gleam/server

[working-directory: 'server']
start-prof:
    # Set these env vars here to override .env file
    # the [env()] attribute doesn't seem to override
    https_port=3000 http_port=3003 gtfs_st="local" gleam run -m server_prof

[working-directory: 'server']
start-stop-prof:
    # Set these env vars here to override .env file
    # the [env()] attribute doesn't seem to override
    profile_stop_page=true https_port=3000 http_port=3003 gtfs_st="local" gleam run -m subway_gleam/server

# TODO: automate this somehow?
# also maybe move into submodules
# maybe use make?

build-client: build-stops build-stop build-train

[working-directory: 'client']
build-stops:
    gleam run -m lustre/dev build subway_gleam/client/stops

[working-directory: 'client']
build-stop:
    gleam run -m lustre/dev build subway_gleam/client/stop

[working-directory: 'client']
build-train:
    gleam run -m lustre/dev build subway_gleam/client/train

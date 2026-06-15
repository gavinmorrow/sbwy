//// Rebuilds the st_extra_data.gleam file.
//// 
//// Run with `gleam run -m build_st_extra`.

import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/io
import gleam/list
import gleam/result
import gleam/set
import gleam/string
import gsv
import shellout
import simplifile

import subway_gleam/gtfs/st/route.{type Route}
import subway_gleam/gtfs/st_extra

const data_file_path = "./MTA_Subway_Stations.csv"

const output_file_path = "./src/subway_gleam/gtfs/st_extra_data.gleam"

pub fn main() -> Nil {
  io.println_error("Reading file...")
  // Read and parse
  let assert Ok(file) = simplifile.read(from: data_file_path)
    as "data file must exist"
  io.println_error("Parsing data...")
  let assert Ok(stops) = parse(file) as "data must be parsable"

  // Write
  io.println_error("Generating code...")
  let gleam_code = output(stops)
  io.println_error("Writing output...")
  let assert Ok(Nil) = simplifile.write(gleam_code, to: output_file_path)

  io.println_error("Checking code...")
  let assert Ok(_) =
    shellout.command("gleam", with: ["check"], in: ".", opt: [])

  io.println_error("Done.")
}

fn parse(file: String) -> Result(List(#(String, st_extra.Stop)), ParseError) {
  // Parse the csv
  use rows <- result.try(
    file
    |> gsv.to_dicts(separator: ",")
    |> result.map_error(CsvError),
  )

  // Turn the whole thing into a dynamic list
  let dynamic_rows =
    dynamic.list(
      list.map(rows, fn(row) {
        // Turn each row into a dynamic dict
        dynamic.properties(
          dict.to_list(row)
          |> list.map(fn(kv) {
            let #(k, v) = kv
            #(dynamic.string(k), dynamic.string(v))
          }),
        )
      }),
    )

  // Run the decoder
  decode.run(dynamic_rows, decode.list(of: stop_decoder()))
  |> result.map_error(DecodeError)
}

type ParseError {
  CsvError(gsv.Error)
  DecodeError(List(decode.DecodeError))
}

/// Converts the data to a gleam module
fn output(data: List(#(String, st_extra.Stop))) -> String {
  "import gleam/dict
import gleam/set.{from_list as set}

import subway_gleam/gtfs/st/route.{
  A, B, C, D, E, F, G, J, L, M, N, N1, N2, N3, N4, N5, N6, N7, Q, R, S, Sf, Si,
  Sr, W, Z,
}
import subway_gleam/gtfs/st_extra.{
  type Stop, Bronx, Brooklyn, Manhattan, Queens, StatenIsland, Stop,
}

pub fn data() -> dict.Dict(String, Stop) {
  dict.from_list([
" <> {
    data
    |> list.map(fn(stop) { "    " <> output_stop(stop.0, stop.1) <> "," })
    |> string.join(with: "\n")
  } <> "
  ])
}
"
}

fn output_stop(id: String, stop: st_extra.Stop) -> String {
  let st_extra.Stop(borough:, daytime_routes:) = stop

  let borough = case borough {
    st_extra.Manhattan -> "Manhattan"
    st_extra.Brooklyn -> "Brooklyn"
    st_extra.Queens -> "Queens"
    st_extra.Bronx -> "Bronx"
    st_extra.StatenIsland -> "StatenIsland"
  }
  let daytime_routes =
    "set(["
    <> {
      set.to_list(daytime_routes)
      |> list.map(fn(route) {
        case route {
          route.N1 -> "N1"
          route.N2 -> "N2"
          route.N3 -> "N3"
          route.N4 -> "N4"
          route.N5 -> "N5"
          route.N6 -> "N6"
          route.N7 -> "N7"
          route.A -> "A"
          route.C -> "C"
          route.E -> "E"
          route.B -> "B"
          route.D -> "D"
          route.F -> "F"
          route.M -> "M"
          route.N -> "N"
          route.Q -> "Q"
          route.R -> "R"
          route.W -> "W"
          route.J -> "J"
          route.Z -> "Z"
          route.G -> "G"
          route.L -> "L"
          route.S -> "S"
          route.Sr -> "Sr"
          route.Sf -> "Sf"
          route.Si -> "Si"
          route.N6X | route.N7X | route.FX ->
            panic as "express routes not allowed in daytime routes"
        }
      })
      |> string.join(with: ", ")
    }
    <> "])"

  let id = "\"" <> id <> "\""
  let stop = "Stop(" <> borough <> ", " <> daytime_routes <> ")"
  "#(" <> id <> ", " <> stop <> ")"
}

fn stop_decoder() -> decode.Decoder(#(String, st_extra.Stop)) {
  use id <- decode.field("GTFS Stop ID", decode.string)
  use borough <- decode.field("Borough", borough_decoder())
  use daytime_routes <- decode.field(
    "Daytime Routes",
    daytime_routes_decoder(borough),
  )

  #(id, st_extra.Stop(borough:, daytime_routes:)) |> decode.success
}

fn daytime_routes_decoder(
  borough: st_extra.Borough,
) -> decode.Decoder(set.Set(Route)) {
  use routes <- decode.then(decode.string)

  routes
  |> string.split(on: " ")
  |> list.filter_map(fn(route) {
    case route {
      "1" -> route.N1 |> Ok
      "2" -> route.N2 |> Ok
      "3" -> route.N3 |> Ok
      "4" -> route.N4 |> Ok
      "5" -> route.N5 |> Ok
      "6" -> route.N6 |> Ok
      "7" -> route.N7 |> Ok
      "A" -> route.A |> Ok
      "B" -> route.B |> Ok
      "C" -> route.C |> Ok
      "D" -> route.D |> Ok
      "E" -> route.E |> Ok
      "F" -> route.F |> Ok
      "G" -> route.G |> Ok
      "J" -> route.J |> Ok
      "L" -> route.L |> Ok
      "M" -> route.M |> Ok
      "N" -> route.N |> Ok
      "Q" -> route.Q |> Ok
      "R" -> route.R |> Ok
      "S" if borough == st_extra.Manhattan -> route.S |> Ok
      "S" if borough == st_extra.Brooklyn -> route.Sf |> Ok
      "S" if borough == st_extra.Queens -> route.Sr |> Ok
      "W" -> route.W |> Ok
      "Z" -> route.Z |> Ok
      "SIR" -> route.Si |> Ok
      _ -> Error(Nil)
    }
  })
  |> set.from_list
  |> decode.success
}

fn borough_decoder() -> decode.Decoder(st_extra.Borough) {
  use variant <- decode.then(decode.string)
  case variant {
    "M" -> decode.success(st_extra.Manhattan)
    "Bk" -> decode.success(st_extra.Brooklyn)
    "Q" -> decode.success(st_extra.Queens)
    "Bx" -> decode.success(st_extra.Bronx)
    "SI" -> decode.success(st_extra.StatenIsland)
    _ -> decode.failure(st_extra.Manhattan, "Borough")
  }
}

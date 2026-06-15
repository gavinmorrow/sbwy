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

import subway_gleam/gtfs/st
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

fn parse(file: String) -> Result(List(st_extra.Stop), ParseError) {
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
fn output(data: List(st_extra.Stop)) -> String {
  "import gleam/dict
import gleam/set.{from_list as set}

import subway_gleam/gtfs/st.{
  type StopId, A, B, C, D, E, F, G, J, L, M, N, N1, N2, N3, N4, N5, N6, N7, Q, R,
  S, Sf, Si, Sr, StopId, W, Z,
}
import subway_gleam/gtfs/st_extra.{
  type Stop, Bronx, Brooklyn, Manhattan, Queens, StatenIsland, Stop,
}

pub fn data() -> dict.Dict(StopId, Stop) {
  dict.from_list([
" <> {
    data
    |> list.map(fn(stop) { "    " <> output_stop(stop) <> "," })
    |> string.join(with: "\n")
  } <> "
  ])
}
"
}

fn output_stop(stop: st_extra.Stop) -> String {
  let st_extra.Stop(id: st.StopId(id), borough:, daytime_routes:) = stop

  let id = "StopId(\"" <> id <> "\")"
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
          st.N1 -> "N1"
          st.N2 -> "N2"
          st.N3 -> "N3"
          st.N4 -> "N4"
          st.N5 -> "N5"
          st.N6 -> "N6"
          st.N7 -> "N7"
          st.A -> "A"
          st.C -> "C"
          st.E -> "E"
          st.B -> "B"
          st.D -> "D"
          st.F -> "F"
          st.M -> "M"
          st.N -> "N"
          st.Q -> "Q"
          st.R -> "R"
          st.W -> "W"
          st.J -> "J"
          st.Z -> "Z"
          st.G -> "G"
          st.L -> "L"
          st.S -> "S"
          st.Sr -> "Sr"
          st.Sf -> "Sf"
          st.Si -> "Si"
          st.N6X | st.N7X | st.FX ->
            panic as "express routes not allowed in daytime routes"
        }
      })
      |> string.join(with: ", ")
    }
    <> "])"

  let stop = "Stop(" <> id <> ", " <> borough <> ", " <> daytime_routes <> ")"
  "#(" <> id <> ", " <> stop <> ")"
}

fn stop_decoder() -> decode.Decoder(st_extra.Stop) {
  use id <- decode.field("GTFS Stop ID", decode.string |> decode.map(st.StopId))
  use borough <- decode.field("Borough", borough_decoder())
  use daytime_routes <- decode.field(
    "Daytime Routes",
    daytime_routes_decoder(borough),
  )

  st_extra.Stop(id:, borough:, daytime_routes:) |> decode.success
}

fn daytime_routes_decoder(
  borough: st_extra.Borough,
) -> decode.Decoder(set.Set(st.Route)) {
  use routes <- decode.then(decode.string)

  routes
  |> string.split(on: " ")
  |> list.filter_map(fn(route) {
    case route {
      "1" -> st.N1 |> Ok
      "2" -> st.N2 |> Ok
      "3" -> st.N3 |> Ok
      "4" -> st.N4 |> Ok
      "5" -> st.N5 |> Ok
      "6" -> st.N6 |> Ok
      "7" -> st.N7 |> Ok
      "A" -> st.A |> Ok
      "B" -> st.B |> Ok
      "C" -> st.C |> Ok
      "D" -> st.D |> Ok
      "E" -> st.E |> Ok
      "F" -> st.F |> Ok
      "G" -> st.G |> Ok
      "J" -> st.J |> Ok
      "L" -> st.L |> Ok
      "M" -> st.M |> Ok
      "N" -> st.N |> Ok
      "Q" -> st.Q |> Ok
      "R" -> st.R |> Ok
      "S" if borough == st_extra.Manhattan -> st.S |> Ok
      "S" if borough == st_extra.Brooklyn -> st.Sf |> Ok
      "S" if borough == st_extra.Queens -> st.Sr |> Ok
      "W" -> st.W |> Ok
      "Z" -> st.Z |> Ok
      "SIR" -> st.Si |> Ok
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

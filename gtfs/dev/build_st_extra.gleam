//// Rebuilds the st_extra_data.gleam file.
//// 
//// Run with `gleam run -m build_st_extra`.

import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/function
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/set
import gleam/string
import gsv
import simplifile

import subway_gleam/gtfs/st/route.{type Route}
import subway_gleam/gtfs/st_extra

const data_file_path = "./MTA_Subway_Stations.csv"

const output_file_path = st_extra.data_file_path

pub fn main() -> Nil {
  io.println_error("Reading file...")
  // Read and parse
  let assert Ok(file) = simplifile.read(from: data_file_path)
    as "data file must exist"
  io.println_error("Parsing data...")
  let assert Ok(stops) = parse(file) as "data must be parsable"

  // Write
  io.println_error("Generating code...")
  let output = to_json(stops) |> json.to_string
  io.println_error("Writing output...")
  let assert Ok(Nil) = simplifile.write(output, to: output_file_path)

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

fn to_json(data: List(#(String, st_extra.Stop))) -> json.Json {
  json.dict(dict.from_list(data), function.identity, stop_to_json)
}

fn stop_to_json(stop: st_extra.Stop) -> json.Json {
  let st_extra.Stop(borough:, daytime_routes:) = stop
  json.object([
    #("borough", borough_to_json(borough)),
    #("daytime_routes", daytime_routes_to_json(daytime_routes)),
  ])
}

fn borough_to_json(borough: st_extra.Borough) -> json.Json {
  json.string(case borough {
    st_extra.Manhattan -> "manhattan"
    st_extra.Brooklyn -> "brooklyn"
    st_extra.Queens -> "queens"
    st_extra.Bronx -> "bronx"
    st_extra.StatenIsland -> "staten_island"
  })
}

fn daytime_routes_to_json(daytime_routes: set.Set(Route)) -> json.Json {
  json.preprocessed_array(
    set.to_list(daytime_routes)
    |> list.map(fn(route) {
      json.string(case route {
        route.N6X | route.N7X | route.FX ->
          panic as "express routes not allowed in daytime routes"
        route -> route.to_long_id(route)
      })
    }),
  )
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

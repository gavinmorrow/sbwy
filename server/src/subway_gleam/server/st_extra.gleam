import gleam/dynamic/decode
import gleam/json
import simplifile

import subway_gleam/gtfs/st_extra

pub fn load_data() -> st_extra.Data {
  let assert Ok(file) =
    simplifile.read(from: "../gtfs/" <> st_extra.data_file_path)
    as "data file should be prebuilt"
  let assert Ok(stops) =
    json.parse(file, using: decode.dict(decode.string, st_extra.stop_decoder()))
    as "prebuilt data should be have correct shape"
  stops
}

import gleam/dynamic/decode

pub type Route {
  N1
  N2
  N3

  N4
  N5
  N6
  N6X

  N7
  N7X

  A
  C
  E

  B
  D
  F
  FX
  M

  N
  Q
  R
  W

  J
  Z

  G

  L

  S
  Sr
  Sf

  Si
}

pub fn decoder() -> decode.Decoder(Route) {
  use route <- decode.then(decode.string)
  case parse(route) {
    Ok(route) -> decode.success(route)
    Error(route) -> decode.failure(A, "Route (in trip) (" <> route <> ")")
  }
}

/// For parsing from GTFS
pub fn parse(route) {
  case route {
    "A" -> A |> Ok
    "B" -> B |> Ok
    "C" -> C |> Ok
    "D" -> D |> Ok
    "E" -> E |> Ok
    "F" -> F |> Ok
    "FX" -> FX |> Ok
    "G" -> G |> Ok
    "J" -> J |> Ok
    "L" -> L |> Ok
    "M" -> M |> Ok
    "N" -> N |> Ok
    "1" -> N1 |> Ok
    "2" -> N2 |> Ok
    "3" -> N3 |> Ok
    "4" -> N4 |> Ok
    "5" -> N5 |> Ok
    "6" -> N6 |> Ok
    "6X" -> N6X |> Ok
    "7" -> N7 |> Ok
    "7X" -> N7X |> Ok
    "Q" -> Q |> Ok
    "R" -> R |> Ok
    "GS" -> S |> Ok
    "FS" -> Sf |> Ok
    "SI" -> Si |> Ok
    "H" -> Sr |> Ok
    "W" -> W |> Ok
    "Z" -> Z |> Ok
    route -> Error(route)
  }
}

/// This exists so that the app can convert Route <=> String losslessly.
/// It is essentially string.inspect.
/// It is the opposite of route_id_long_to_route().
pub fn to_long_id(route: Route) -> String {
  case route {
    A -> "A"
    B -> "B"
    C -> "C"
    D -> "D"
    E -> "E"
    F -> "F"
    FX -> "FX"
    G -> "G"
    J -> "J"
    L -> "L"
    M -> "M"
    N -> "N"
    N1 -> "1"
    N2 -> "2"
    N3 -> "3"
    N4 -> "4"
    N5 -> "5"
    N6 -> "6"
    N6X -> "6X"
    N7 -> "7"
    N7X -> "7X"
    Q -> "Q"
    R -> "R"
    S -> "S"
    Sf -> "Sf"
    Si -> "Si"
    Sr -> "Sr"
    W -> "W"
    Z -> "Z"
  }
}

/// This exists so that the app can convert Route <=> String losslessly.
/// It is the opposite of route_to_long_id().
pub fn from_long_id(route: String) -> Result(Route, Nil) {
  case route {
    "A" -> A |> Ok
    "B" -> B |> Ok
    "C" -> C |> Ok
    "D" -> D |> Ok
    "E" -> E |> Ok
    "F" -> F |> Ok
    "FX" -> FX |> Ok
    "G" -> G |> Ok
    "J" -> J |> Ok
    "L" -> L |> Ok
    "M" -> M |> Ok
    "N" -> N |> Ok
    "1" -> N1 |> Ok
    "2" -> N2 |> Ok
    "3" -> N3 |> Ok
    "4" -> N4 |> Ok
    "5" -> N5 |> Ok
    "6" -> N6 |> Ok
    "6X" -> N6X |> Ok
    "7" -> N7 |> Ok
    "7X" -> N7X |> Ok
    "Q" -> Q |> Ok
    "R" -> R |> Ok
    "S" -> S |> Ok
    "Sf" -> Sf |> Ok
    "Si" -> Si |> Ok
    "Sr" -> Sr |> Ok
    "W" -> W |> Ok
    "Z" -> Z |> Ok
    _ -> Error(Nil)
  }
}

import gleam/erlang/atom.{type Atom}

pub type Table(key, value)

@external(erlang, "table_ffi", "new")
pub fn new(name: Atom) -> Table(key, value)

@external(erlang, "table_ffi", "identity")
pub fn from_name(name: Atom) -> Table(key, value)

pub fn get(from table: Table(key, value), for key: key) -> Result(value, Nil) {
  case do_get(from: table, for: key) {
    [] -> Error(Nil)
    [#(_key, item), ..] -> Ok(item)
  }
}

@external(erlang, "table_ffi", "get")
fn do_get(from table: Table(key, value), for key: key) -> List(#(key, value))

pub fn insert(
  into table: Table(key, value),
  for key: key,
  insert value: value,
) -> Table(key, value) {
  do_insert(into: table, item: #(key, value))
  table
}

pub fn insert_many(
  into table: Table(key, value),
  items items: List(#(key, value)),
) -> Table(key, value) {
  do_insert_many(into: table, items:)
  table
}

@external(erlang, "table_ffi", "insert")
fn do_insert(into table: Table(key, value), item item: #(key, value)) -> Nil

@external(erlang, "table_ffi", "insert")
fn do_insert_many(
  into table: Table(key, value),
  items items: List(#(key, value)),
) -> Nil

pub fn delete_all_items(in table: Table(key, value)) -> Table(key, value) {
  do_delete_all_items(in: table)
  table
}

@external(erlang, "table_ffi", "delete_all_items")
fn do_delete_all_items(in table: Table(key, value)) -> Nil

pub fn replace_all_items(
  in table: Table(key, value),
  with items: List(#(key, value)),
) -> Table(key, value) {
  table |> delete_all_items |> insert_many(items:)
}

pub fn delete_item(
  in table: Table(key, value),
  delete key: key,
) -> Table(key, value) {
  do_delete_item(in: table, delete: key)
  table
}

@external(erlang, "table_ffi", "delete_item")
fn do_delete_item(in table: Table(key, value), delete key: key) -> Nil

@external(erlang, "table_ffi", "fold")
pub fn fold(
  over table: Table(key, value),
  from initial: a,
  with fun: fn(a, key, value) -> a,
) -> a

pub fn each(
  table: Table(key, value),
  fun: fn(key, value) -> anything,
) -> Table(key, value) {
  let Nil =
    fold(over: table, from: Nil, with: fn(_acc, key, value) {
      let _ = fun(key, value)
      Nil
    })
  table
}

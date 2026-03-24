import booklet.{type Booklet}
import gleam/option
import subway_gleam/gtfs/st
import subway_gleam/server/state/gtfs_store.{type GtfsStore}
import tzif/database.{type TzDatabase}

pub type State {
  State(
    priv_dir: String,
    schedule: st.Schedule,
    gtfs_store: GtfsStore,
    tz_db: TzDatabase,
  )
}

pub opaque type Ref {
  Ref(Booklet(option.Option(State)))
}

pub fn ref(from state: State) -> Ref {
  // Do this so that the default value is small.
  // Internally a booklet is {Ref, DefaultValue}; the DefaultValue is copied on
  // the heap. We don't want it to be big—that's the problem we're solving.
  let ref = booklet.new(option.None)
  booklet.set(ref, to: option.Some(state))
  Ref(ref)
}

pub fn get(from ref: Ref) -> State {
  let Ref(ref) = ref
  let assert option.Some(state) = booklet.get(ref)
    as "state ref should always have value set"
  state
}

pub fn fetch_gtfs(state: State) -> gtfs_store.Data {
  gtfs_store.get(from: state.gtfs_store)
}

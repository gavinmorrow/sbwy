-module(table_ffi).
-export([new/1, get/2, insert/2, delete_all_items/1, delete_item/2, fold/3, identity/1]).

new(Name) -> ets:new(Name, [public, named_table]).

get(Table, Key) -> ets:lookup(Table, Key).

insert(Table, ItemOrItems) -> ets:insert(Table, ItemOrItems).

delete_all_items(Table) -> ets:delete_all_objects(Table).

delete_item(Table, Key) -> ets:delete(Table, Key).

fold(Table, Initial, Fun) ->
    ets:foldl(fun({K, V}, Acc) -> Fun(Acc, K, V) end, Initial, Table).

identity(X) -> X.

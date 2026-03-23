-module(eprof_ffi).
-export([eprof/1]).

eprof(F) ->
    {ok, Result} = eprof:profile(F),
    ok = eprof:log("sbwy.log"),
    eprof:analyze(),
    Result.

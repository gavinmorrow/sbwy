-module(server_prof_ffi).
-export([start/1]).

start(F) ->
    {ok, Result} = eprof:profile(F),
    ok = eprof:log("sbwy.log"),
    eprof:analyze().

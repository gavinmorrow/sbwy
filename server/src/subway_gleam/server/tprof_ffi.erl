-module(tprof_ffi).
-export([tprof/1]).

tprof(F) ->
    {Result, Data} = tprof:profile(F, #{type => call_time, report => return}),
    tprof:format(tprof:inspect(Data)),
    Result.

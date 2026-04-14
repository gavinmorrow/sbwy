-module(logger_config_ffi).
-import(logger, [update_primary_config/1]).
-export([configure_level_info/0, configure_level_all/0]).

% TODO: figure out how to pass in level or smth
configure_level_info() ->
    logger:update_primary_config(#{level => info}).
configure_level_all() ->
    logger:update_primary_config(#{level => all}).

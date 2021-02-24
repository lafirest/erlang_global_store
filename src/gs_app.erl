%%%-------------------------------------------------------------------
%% @doc gs public API
%% @end
%%%-------------------------------------------------------------------

-module(gs_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    gs_sup:start_link().

stop(_State) ->
    ok.

%% internal functions

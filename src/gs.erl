%%%-------------------------------------------------------------------
%%% @author firest
%%% @copyright (C) 2021, firest
%%% @doc
%%%
%%% @end
%%% Created : 2021-02-24 20:59:39.953426
%%%-------------------------------------------------------------------
-module(gs).

-export([insert/2,
         insert/3,
         delete/1,
         delete/2,
         delete_if_eql/2,
         delete_if_eql/3,
         find/1]).

-export([join_group/2,
         join_group/3,
         exit_group/2,
         exit_group/3,
         group_foreach/2,
         group_fold/3,
         print_group/1]).

-export([map_insert/3,
         map_insert/4,
         map_delete/2,
         map_delete/3,
         map_find/2,
         map_foreach/2,
         map_fold/3,
         print_map/1]).

-export_type([sync_type/0, 
              gs_group/0,
              gs_map/0]).

-include("include/gs.hrl").

-type sync_type() :: local
                   | urgent
                   | delayed.


-type gs_group() :: #{term() => node()}.
-type gs_map() :: #{term() => #map_value{}}.

%%%===================================================================
%%% KV
%%%===================================================================
-spec insert(term(), term()) -> ok.
insert(Key, Value) ->
    gs_store:insert(Key, Value).

-spec insert(term(), term(), sync_type()) -> ok.
insert(Key, Value, SyncType) ->
    gs_store:insert(Key, Value, SyncType).

-spec delete(term()) -> ok.
delete(Key) ->
    gs_store:delete(Key).

-spec delete(term(), sync_type()) -> ok.
delete(Key, SyncType) ->
    gs_store:delete(Key, SyncType).

-spec delete_if_eql(term(), term()) -> ok.
delete_if_eql(Key, Value) ->
    gs_store:delete_if_eql(Key, Value).

-spec delete_if_eql(term(), term(), sync_type()) -> ok.
delete_if_eql(Key, Value, SyncType) ->
    gs_store:delete_if_eql(Key, Value, SyncType).

-spec find(term()) -> undefined | term().
find(Key) ->
    case ets:lookup(?gs_name_table, Key) of
        [] ->
            undefined;
        [Any] ->
            Any#key_value.value
    end.

%%%===================================================================
%%% group
%%%===================================================================
-spec join_group(term(), term()) -> ok.
join_group(Group, Value) ->
    gs_store:join_group(Group, Value).

-spec join_group(term(), term(), sync_type()) -> ok.
join_group(Group, Value, SyncType) ->
    gs_store:join_group(Group, Value, SyncType).

-spec exit_group(term(), term()) -> ok.
exit_group(Group, Value) ->
    gs_store:exit_group(Group, Value).

-spec exit_group(term(), term(), sync_type()) -> ok.
exit_group(Group, Value, SyncType) ->
    gs_store:exit_group(Group, Value, SyncType).

-spec group_foreach(term(), fun((term()) -> any())) -> ok.
group_foreach(GroupName, Fun) ->
    case gs_store:find_group(GroupName) of
        undefined ->
            ok;
        Group ->
            Iter = maps:iterator(Group),
            group_foreach_next(Iter, Fun),
            ok
    end.

-spec group_fold(term(), fun((term(), term()) -> any()), term()) -> term().
group_fold(GroupName, Fun, Init) ->
    case gs_store:find_group(GroupName) of
        undefined ->
            Init;
        Group ->
            maps:fold(fun(Value, _, Acc) ->
                        Fun(Value, Acc)
                      end,
                      Init,
                      Group)
    end.

-spec print_group(term()) -> ok.
print_group(GroupName) ->
    group_foreach(GroupName, fun(E) -> io:format("~p~n", [E]) end).
%%%===================================================================
%%% Map
%%%===================================================================
-spec map_insert(term(), term(), term()) -> ok.
map_insert(Map, Key, Value) ->
    gs_store:map_insert(Map, Key, Value).

-spec map_insert(term(), term(), term(), sync_type()) -> ok.
map_insert(Map, Key, Value, SyncType) ->
    gs_store:map_insert(Map, Key, Value, SyncType).

-spec map_delete(term(), term()) -> ok.
map_delete(Map, Key) ->
    gs_store:map_delete(Map, Key).

-spec map_delete(term(), term(), sync_type()) -> ok.
map_delete(Map, Key, SyncType) ->
    gs_store:map_delete(Map, Key, SyncType).

-spec map_find(term(), term()) -> ok.
map_find(MapName, Key) ->
    case gs_store:find_map(MapName) of
        undefined ->
            undefined;
        Map ->
            case maps:get(Key, Map, undefined) of
                #map_value{value = Value} ->
                    Value;
                _ ->
                    undefined
            end
    end.

-spec map_foreach(term(), fun((term(), term()) -> any())) -> ok.
map_foreach(MapName, Fun) ->
    case gs_store:find_map(MapName) of
        undefined ->
            ok;
        Map ->
            Iter = maps:iterator(Map),
            map_foreach_next(Iter, Fun),
            ok
    end.

-spec map_fold(term(), fun((term(), term(), term()) -> any()), term()) -> term().
map_fold(MapName, Fun, Init) ->
    case gs_store:find_map(MapName) of
        undefined ->
            Init;
        Map ->
            maps:fold(fun(Key, Value, Acc) ->
                        Fun(Key, Value#map_value.value, Acc)
                      end,
                      Init,
                      Map)
    end.

-spec print_map(term()) -> ok.
print_map(MapName) ->
    map_foreach(MapName, fun(K, V) -> io:format("Key : ~p, Value : ~p ~n", [K, V]) end).

%%%===================================================================
%%% Internal functions
%%%===================================================================
-spec group_foreach_next(maps:iterator(term(), term()), fun((term()) -> any())) -> ok.
group_foreach_next(Iter, Fun) ->
    case maps:next(Iter) of
        {Value, _, Next} ->
            Fun(Value),
            group_foreach_next(Next, Fun);
        _ ->
            ok
    end.

-spec map_foreach_next(maps:iterator(term(), term()), fun((term(), term()) -> any())) -> ok.
map_foreach_next(Iter, Fun) ->
    case maps:next(Iter) of
        {Key, Value, Next} ->
            Fun(Key, Value#map_value.value),
            group_foreach_next(Next, Fun);
        _ ->
            ok
    end.

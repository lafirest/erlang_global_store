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
         find_group/1,
         group_foreach/2,
         group_fold/3]).

-export_type([sync_type/0, 
              gs_group/0]).

-type sync_type() :: local
                   | urgent
                   | delayed.


-type gs_group() :: #{term() => node()}.

-include("include/gs.hrl").
%%%===================================================================
%%% dict
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
            Any#gs_name.value
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

-spec find_group(term()) -> gs_group().
find_group(GroupName) ->
    case ets:lookup(?gs_group_table, GroupName) of
        [] ->
            undefined;
        [{_, Group}] ->
            Group
    end.

-spec group_foreach(fun((term()) -> any()), term()) -> ok.
group_foreach(Fun, GroupName) ->
    case find_group(GroupName) of
        undefined ->
            ok;
        Group ->
            Iter = maps:iterator(Group),
            group_foreach_next(Iter, Fun),
            ok
    end.

-spec group_fold(fun((term(), term()) -> any()), term(), term()) -> term().
group_fold(Fun, Init, GroupName) ->
    case find_group(GroupName) of
        undefined ->
            Init;
        Group ->
            maps:fold(fun(Value, _, Acc) ->
                        Fun(Value, Acc)
                      end,
                      Init,
                      Group)
    end.

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

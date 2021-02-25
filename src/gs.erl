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
         find/1]).

-export([join_group/2,
         join_group/3,
         exit_group/2,
         exit_group/3,
         traverse_group/2]).

-export_type([sync_type/0]).
-type sync_type() :: local
                   | urgent
                   | delayed.

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

-spec find(term()) -> undefined | term().
find(Key) ->
    gs_store:find(Key).

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

-spec traverse_group(term(), fun((term()) -> any())) -> ok.
traverse_group(GroupName, Fun) ->
    gs_store:traverse_group(GroupName, Fun).

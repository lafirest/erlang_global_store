%%%-------------------------------------------------------------------
%%% @author firest
%%% @copyright (C) 2021, firest
%%% @doc
%%%
%%% @end
%%% Created : 2021-02-24 15:17:47.241637
%%%-------------------------------------------------------------------
-module(gs_store).

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-export([insert/2,
         insert/3,
         delete/1,
         delete/2,
         delete_if_eql/2,
         delete_if_eql/3,
         join_group/2,
         join_group/3,
         exit_group/2,
         exit_group/3,
         map_insert/3,
         map_insert/4,
         map_delete/2,
         map_delete/3]).

-export([find_group/1,
         find_map/1]).

-export([remote_sync/2]).

-include("include/gs.hrl").

-define(SERVER, ?MODULE).
-define(try_sync_arbiter_interval, timer:seconds(1)).
-define(make_message(S, V1), {message, S, {?FUNCTION_NAME, V1}}).
-define(make_message(S, V1, V2), {message, S, {?FUNCTION_NAME, V1, V2}}).
-define(make_message(S, V1, V2, V3), {message, S, {?FUNCTION_NAME, V1, V2, V3}}).

%-record(gs_group_table, {name :: term(), members :: gs_group()}).

-type store_state() :: wait_sync
                    | sync_done.

-record(state, {store_state :: store_state()}).
%%%===================================================================
%%% API
%%%===================================================================
-spec insert(term(), term()) -> ok.
insert(Key, Value) ->
    insert(Key, Value, delayed).

-spec insert(term(), term(), gs:sync_type()) -> ok.
insert(Key, Value, SyncType) ->
    gen_server:call(?SERVER, ?make_message(SyncType, Key, Value)).

-spec delete(term()) -> ok.
delete(Key) ->
    delete(Key, delayed).

-spec delete(term(), gs:sync_type()) -> ok.
delete(Key, SyncType) ->
    gen_server:call(?SERVER, ?make_message(SyncType, Key)).

-spec delete_if_eql(term(), term()) -> ok.
delete_if_eql(Key, Value) ->
    delete_if_eql(Key, Value, delayed).

-spec delete_if_eql(term(), term(), gs:sync_type()) -> ok.
delete_if_eql(Key, Value, SyncType) ->
    gen_server:call(?SERVER, ?make_message(SyncType, Key, Value)).

-spec join_group(term(), term()) -> ok.
join_group(Group, Value) ->
    join_group(Group, Value, delayed).

-spec join_group(term(), term(), gs:sync_type()) -> ok.
join_group(Group, Value, SyncType) ->
    gen_server:call(?SERVER, ?make_message(SyncType, Group, Value)).

-spec exit_group(term(), term()) -> ok.
exit_group(Group, Value) ->
    exit_group(Group, Value, delayed).

-spec exit_group(term(), term(), gs:sync_type()) -> ok.
exit_group(Group, Value, SyncType) ->
    gen_server:call(?SERVER, ?make_message(SyncType, Group, Value)).

-spec map_insert(term(), term(), term()) -> ok.
map_insert(Map, Key, Value) ->
    map_insert(Map, Key, Value, delayed).

-spec map_insert(term(), term(), term(), gs:sync_type()) -> ok.
map_insert(Map, Key, Value, SyncType) ->
    gen_server:call(?SERVER, ?make_message(SyncType, Map, Key, Value)).

-spec map_delete(term(), term()) -> ok.
map_delete(Map, Key) ->
    map_delete(Map, Key, delayed).

-spec map_delete(term(), term(), gs:sync_type()) -> ok.
map_delete(Map, Key, SyncType) ->
    gen_server:call(?SERVER, ?make_message(SyncType, Map, Key)).

-spec remote_sync(node(), list(term())) -> ok.
remote_sync(Node, Messages) ->
    gen_server:cast({?SERVER, Node}, {?FUNCTION_NAME, node(), Messages}).

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    ok = net_kernel:monitor_nodes(true),
    ?gs_name_table = ets:new(?gs_name_table, [set, protected, named_table, {keypos, #key_value.key}, {write_concurrency, false}, {read_concurrency, true}]),
    ?gs_group_table = ets:new(?gs_group_table, [set, protected, named_table, {keypos, 1}, {write_concurrency, false}, {read_concurrency, true}]),
    ?gs_map_table = ets:new(?gs_map_table, [set, protected, named_table, {keypos, 1}, {write_concurrency, false}, {read_concurrency, true}]),
    erlang:send(self(), sync_from_arbiter),
    {ok, #state{store_state = wait_sync}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(sync_from_arbiter, _, State) ->
    {reply, {ok, ets:tab2list(?gs_name_table), ets:tab2list(?gs_group_table), ets:tab2list(?gs_map_table)}, State};

handle_call({message, SyncType, Message}, _, State) ->
    handle_message(Message, node()),
    gs_sync:sync(SyncType, Message),
    {reply, ok, State};

handle_call(Request, _From, State) ->
    Reply = ok,
    error_logger:error_msg("un handle call: ~p ~n", [Request]),
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({remote_sync, Node, Messages}, State) ->
    lists:foreach(fun(Message) -> handle_message(Message, Node) end, lists:reverse(Messages)),
    {noreply, State};

handle_cast(Msg, State) ->
    error_logger:error_msg("un handle cast: ~p~n", [Msg]),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(sync_from_arbiter, #state{ } = State) ->
    sync_from_arbiter(),
    {noreply, State#state{store_state = sync_done}};

handle_info({nodedown, RemoteNode}, State) ->
    ets:match_delete(?gs_name_table, {'_', '_', '_', RemoteNode}),
    ets:foldl(fun({GroupName, Group}, _) ->
                      Group2 = maps:filter(fun(_, Node) -> Node =/= RemoteNode end, Group),
                      ets:insert(?gs_group_table, {GroupName, Group2})
              end,
              ok,
              ?gs_group_table),
    ets:foldl(fun({MapName, Map}, _) ->
                      Map2 = maps:filter(fun(_, Value) -> Value#map_value.node =/= RemoteNode end, Map),
                      ets:insert(?gs_map_table, {MapName, Map2})
              end,
              ok,
              ?gs_map_table),
    {noreply, State};

handle_info({nodeup, Node}, #state{store_state = StoreState} = State) ->
    case StoreState of
        sync_done ->
            {?SERVER, Node} ! {vote, node()};
        _ ->
            ok
    end,
    {noreply, State};

handle_info({vote, _}, State) ->
    {noreply, State};

handle_info(Info, State) ->
    error_logger:error_msg("un handle info: ~p~n", [Info]),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
        {ok, State}.

%%%===================================================================
%%% handle_message
%%%===================================================================
-spec handle_message(term(), node()) -> ok.
handle_message({insert, Key, Value}, Node) ->
    ets:insert(?gs_name_table, #key_value{key = Key,
                                          value = Value,
                                          node = Node});

handle_message({delete, Key}, _) ->
    ets:delete(?gs_name_table, Key);

handle_message({delete_if_eql, Key, Value}, _) ->
    case gs:find(Key) of
        Value ->
            ets:delete(?gs_name_table, Key);
        _ -> 
            ok
    end;

handle_message({join_group, GroupName, Value}, Node) ->
    Group = find_or_create_group(GroupName),
    Group2 = Group#{Value => Node},
    ets:insert(?gs_group_table, {GroupName, Group2});

handle_message({exit_group, GroupName, Value}, _) ->
    case find_group(GroupName) of
        undefined ->
            ok;
        Group ->
            Group2 = maps:remove(Value, Group),
            ets:insert(?gs_group_table, {GroupName, Group2})
    end;

handle_message({map_insert, MapName, Key, Value}, Node) ->
    Map = find_or_create_map(MapName),
    Map2 = Map#{Key => #map_value{value = Value, node = Node}},
    ets:insert(?gs_map_table, {MapName, Map2});

handle_message({map_delete, MapName, Key}, _) ->
    case find_map(MapName) of
        undefined ->
            ok;
        Map ->
            Map2 = maps:remote(Key, Map),
            ets:insert(?gs_map_table, {MapName, Map2})
    end.

%%%===================================================================
%%% Internal functions
%%%===================================================================
-spec sync_from_arbiter() -> ok.
sync_from_arbiter() ->
    error_logger:info_msg("begin sync ~n", []),
    Nodes = net_adm:world(),
    case lists:delete(node(), Nodes) of
        [] ->
            error_logger:info_msg("sync done", []);
        _ ->
            error_logger:info_msg("wait vote~n", []),
            Arbiter = wait_vote(),
            {ok, NameTable, GroupTable, MapTable} = gen_server:call({?SERVER, Arbiter}, ?FUNCTION_NAME),
            lists:foreach(fun(E) -> ets:insert(?gs_name_table, E) end, NameTable),
            lists:foreach(fun(E) -> ets:insert(?gs_group_table, E) end, GroupTable),
            lists:foreach(fun(E) -> ets:insert(?gs_map_table, E) end, MapTable),
            error_logger:info_msg("sync done from node :~p~n", [Arbiter])
    end.

-spec wait_vote() -> node().
wait_vote() ->
    receive 
        {vote, Node} ->
            Node
    end.

-spec find_or_create_group(term()) -> gs:gs_group().
find_or_create_group(GroupName) ->
    find_or_create_map(?gs_group_table, GroupName).

-spec find_or_create_map(term()) -> gs:gs_map().
find_or_create_map(MapName) ->
    find_or_create_map(?gs_map_table, MapName).

-spec find_or_create_map(atom(), term()) -> maps:map(). 
find_or_create_map(TableName, MapName) ->
     case ets:lookup(TableName, MapName) of
        [] ->
             New = #{},
             ets:insert(TableName, {MapName, New}),
             New;
        [{_, Group}] ->
            Group
     end.

-spec find_group(term()) -> gs:gs_group().
find_group(GroupName) ->
    find_map(?gs_group_table, GroupName).

-spec find_map(term()) -> gs:gs_map().
find_map(MapName) ->
    find_map(?gs_map_table, MapName).

-spec find_map(atom(), term()) -> maps:map().
find_map(TableName, GroupName) ->
    case ets:lookup(TableName, GroupName) of
        [] ->
            undefined;
        [{_, Group}] ->
            Group
    end.

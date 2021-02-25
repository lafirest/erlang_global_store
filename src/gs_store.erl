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
         exit_group/3]).

-export([find/1,
         traverse_group/2]).

-export([remote_sync/2]).

-define(SERVER, ?MODULE).
-define(try_sync_arbiter_interval, timer:seconds(1)).
-define(gs_name_table, gs_name_table).
-define(gs_group_table, gs_group_table).
-define(make_message(S, V1), {message, S, {?FUNCTION_NAME, V1}}).
-define(make_message(S, V1, V2), {message, S, {?FUNCTION_NAME, V1, V2}}).

-record(state, {arbiter :: node()}).
-record(gs_name, {name :: term(), 
                  value :: term(),
                  node :: node()}).
-type gs_group() :: #{term() => node()}.
%-record(gs_group_table, {name :: term(), members :: gs_group()}).

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

-spec find(term()) -> undefined | term().
find(Key) ->
    case ets:lookup(?gs_name_table, Key) of
        [] ->
            undefined;
        [Any] ->
            Any#gs_name.value
    end.

-spec traverse_group(term(), fun((term()) -> any())) -> ok.
traverse_group(GroupName, Fun) ->
    case find_group(GroupName) of
        undefined ->
            ok;
        Group ->
            Iter = maps:iterator(Group),
            traverse_group_next(Iter, Fun),
            ok
    end.

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
    {ok, Arbiter} = application:get_env(gs, arbiter),
    ?gs_name_table = ets:new(?gs_name_table, [set, protected, named_table, {keypos, #gs_name.name}, {write_concurrency, false}, {read_concurrency, true}]),
    ?gs_group_table = ets:new(?gs_group_table, [set, protected, named_table, {keypos, 1}, {write_concurrency, false}, {read_concurrency, true}]),
    case node() =:= Arbiter of
        true -> 
            ok;
        _ ->
            erlang:send(self(), sync_from_arbiter)
    end,
    {ok, #state{arbiter = Arbiter}}.

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
    {reply, {ok, ets:tab2list(?gs_name_table), ets:tab2list(?gs_group_table)}, State};

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
handle_info(sync_from_arbiter, #state{arbiter = Arbiter} = State) ->
    sync_from_arbiter(Arbiter),
    {noreply, State};

handle_info({nodedown, RemoteNode}, State) ->
    ets:match_delete(?gs_name_table, {'_', '_', '_', RemoteNode}),
    ets:foldl(fun({GroupName, Group}, _) ->
                      Group2 = maps:filter(fun(_, Node) -> Node =/= RemoteNode end, Group),
                      ets:insert(?gs_group_table, {GroupName, Group2})
              end,
              ok,
              ?gs_group_table),
    {noreply, State};

handle_info({nodeup, _}, State) ->
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
    ets:insert(?gs_name_table, #gs_name{name = Key,
                                        value = Value,
                                        node = Node});

handle_message({delete, Key}, _) ->
    ets:delete(?gs_name_table, Key);

handle_message({delete_if_eql, Key, Value}, _) ->
    case find(Key) of
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
    end.

%%%===================================================================
%%% Internal functions
%%%===================================================================
-spec sync_from_arbiter(node()) -> ok.
sync_from_arbiter(Arbiter) ->
    error_logger:info_msg("sync from arbiter: ~p ~n", [Arbiter]),
    case net_adm:ping(Arbiter) of
        pong ->
            {ok, NameTable, GroupTable} = gen_server:call({?SERVER, Arbiter}, ?FUNCTION_NAME),
            lists:foreach(fun(E) -> ets:insert(?gs_name_table, E) end, NameTable),
            lists:foreach(fun(E) -> ets:insert(?gs_group_table, E) end, GroupTable),
            error_logger:info_msg("sync done");
        _ ->
            timer:sleep(?try_sync_arbiter_interval),
            sync_from_arbiter(Arbiter)
    end.

-spec find_group(term()) -> gs_group().
find_group(GroupName) ->
    case ets:lookup(?gs_group_table, GroupName) of
        [] ->
            undefined;
        [{_, Group}] ->
            Group
    end.

-spec find_or_create_group(term()) -> gs_group().
find_or_create_group(GroupName) ->
     case ets:lookup(?gs_group_table, GroupName) of
        [] ->
             New = #{},
             ets:insert(?gs_group_table, {GroupName, New}),
             New;
        [{_, Group}] ->
            Group
     end.

-spec traverse_group_next(maps:iterator(term(), term()), fun((term()) -> any())) -> ok.
traverse_group_next(Iter, Fun) ->
    case maps:next(Iter) of
        {Value, _, Next} ->
            Fun(Value),
            traverse_group_next(Next, Fun);
        _ ->
            ok
    end.

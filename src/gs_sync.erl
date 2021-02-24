%%%-------------------------------------------------------------------
%%% @author firest
%%% @copyright (C) 2021, firest
%%% @doc
%%%
%%% @end
%%% Created : 2021-02-24 16:41:01.579941
%%%-------------------------------------------------------------------
-module(gs_sync).

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

-export([sync/2,
         modify_sync_delay/1]).

-define(SERVER, ?MODULE).

-record(state, {sync_delay :: non_neg_integer(),
                timer_ref :: reference(),
                messages :: list()}).

%%%===================================================================
%%% API
%%%===================================================================
-spec sync(gs_store:sync_type(), term()) -> ok.
sync(local, _) ->
    ok;
sync(SyncType, Message) ->
    gen_server:cast(?SERVER, {sync, SyncType, Message}).

-spec modify_sync_delay(non_neg_integer()) -> ok.
modify_sync_delay(Delay) ->
    gen_server:cast(?SERVER, {modify_sync_delay, Delay}).

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
    {ok, SyncDelay} = application:get_env(gs, sync_delay),
    {ok, #state{sync_delay = SyncDelay,
                messages = [],
                timer_ref = undefined}}.

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
handle_call(_Request, _From, State) ->
    Reply = ok,
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
handle_cast({sync, urgent, Message}, #state{messages = Messages, timer_ref = TimerRef} = State) ->
    cancel_sync_timer(TimerRef),
    boardcast([Message | Messages]),
    {noreply, State#state{timer_ref = undefined, messages = []}};

handle_cast({sync, delayed, Message}, #state{messages = Messages,
                                             timer_ref = TimerRef,
                                             sync_delay = SyncDelay} = State) ->
    NewTimerRef = case TimerRef of
                      undefined ->
                          erlang:send_after(SyncDelay, self(), sync_dirty);
                      Any ->
                          Any
                  end,
    {noreply, State#state{messages = [Message | Messages],
                          timer_ref = NewTimerRef}};

handle_cast({modify_sync_delay, Delay}, State) ->
    {noreply, State#state{sync_delay = Delay}};

handle_cast(_Msg, State) ->
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
handle_info(sync_dirty, #state{messages = Messages} = State) ->
    case Messages of
        [] -> ok;
        _ ->
            boardcast(Messages)
    end,
    {noreply, State#state{messages = [], timer_ref = undefined}};

handle_info(_Info, State) ->
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
%%% Internal functions
%%%===================================================================
-spec cancel_sync_timer(reference() | undefiend) -> ok.
cancel_sync_timer(undefined) ->
    ok;
cancel_sync_timer(Ref) ->
    erlang:cancel_timer(Ref),
    ok.

-spec boardcast(list()) -> ok.
boardcast(Messages) ->
    lists:foreach(fun(Node) -> gs_store:remote_sync(Node, Messages) end, nodes()).    


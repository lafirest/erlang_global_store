%%%-------------------------------------------------------------------
%% @doc gs top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(gs_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).
-define(workerSpec(Mod), #{id => Mod,
                           start => {Mod, start_link, []},
                           restart => transient,
                           shutdown => timer:seconds(10),
                           type => worker,
                           modules => [Mod]}).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%% sup_flags() = #{strategy => strategy(),         % optional
%%                 intensity => non_neg_integer(), % optional
%%                 period => pos_integer()}        % optional
%% child_spec() = #{id => child_id(),       % mandatory
%%                  start => mfargs(),      % mandatory
%%                  restart => restart(),   % optional
%%                  shutdown => shutdown(), % optional
%%                  type => worker(),       % optional
%%                  modules => modules()}   % optional
init([]) ->
    SupFlags = #{strategy => one_for_one,
                 intensity => 6,
                 period => 3600},
    ChildSpecs = [?workerSpec(gs_store), ?workerSpec(gs_sync)],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions

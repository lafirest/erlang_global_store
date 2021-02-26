# Erlang global store
[![cn](https://img.shields.io/badge/lang-中文-blue.svg)](https://github.com/lafirest/erlang_global_store/blob/main/README.md)
[![en](https://img.shields.io/badge/lang-English-red.svg)](https://github.com/lafirest/erlang_global_store/blob/main/README_en.md)

------
***Note: Because my English is very bad, so this md is based on google translation***

   This is a very simple Erlang global variable sharing app
## Why I do this
   sometimes I need to share some data between all Erlang nodes. I used mnesia at first, but mnesia was too heavy and there were a lot of problems with it. Later, I changed it to [syn plugin](https://github.com/ostinelli/ syn ""), but this plug-in is specifically used for distributed routing, and I need to share more than just routing information. What's more serious is that when a large amount of data floods, syn's broadcast synchronization will bring a very high system load  
    Then I also considered using consistent hashing, but the problems I face are more reads and less writes, and the read performance of consistent hashing is obviously not as good as write synchronization.  
    So in the end I wrote this synchronous memory dictionary based on a small delay by default.  

## features:
   * Automatic networking and data synchronization based on net_adm:world()
   * Key/Value Insert Delete Find
   * Group, which can store a value in a global group
   * Global Map 
   * Controllable synchronization method:
         * No synchronization, only local modification
         * Delayed synchronization (default), local modifications will be delayed for a period of time before synchronization (to avoid broadcast storms when a large amount of data is flooded, such as when a game server cluster is opened and logged in)
         * Emergency synchronization, sync with other nodes immediately
   * When the node is down, other nodes will remove all the data written from this node
## unsupported features:
   * Data conflict resolution, because this is a very simple application, so there is no so-called data conflict resolution, all writes directly overwrite the previous data
   * Data protection, as above, any node can write directly to any key
## how to use
### optional environment variables
        
        1. sync_delay synchronization delay
   If you are using rebar, add the following settings directly in sys.config
```Erlang
    {gs, [{sync_delay, 100}]}
```
### API
#### KV
```Erlang
    -type sync_type() :: local
                   | urgent
                   | delayed.
    gs:insert(Key :: term(), Value :: term()).
    gs:insert(Key :: term(), Value :: term(), sync_type()).
    gs:delete(Key :: term()).
    gs:delete(Key :: term(), sync_type()).
    gs:delete_if_eql(Key :: term(), Value :: term()).
    gs:delete_if_eql(Key :: term(), Value :: term(), sync_type()).
    gs:find(Key :: term()).
```
#### Group/Hashset
```Erlang
    gs:join_group(GroupName :: term(), Value ::term()).
    gs:join_group(GroupName :: term(), Value ::term(), sync_type()).
    gs:exit_gropp(GroupName :: term(), Value ::term()).
    gs:exit_group(GroupName :: term(), Value ::term(), sync_type()).
    gs:group_foreach(GroupName :: term(), fun((Value :: term()) -> any())).
    gs:group_fodl(GroupName :: term(), fun((Value :: term(), AccIn :: term()) -> AccOut :: term())).
    gs:print_group(GroupName).
```
#### Map
```Erlang
    gs:map_insert(MapName :: term(), Key :: term(), Value ::term()).
    gs:map_insert(MapName :: term(), Value ::term(), sync_type()).
    gs:map_delete(MapName :: term(), Key ::term()).
    gs:map_delete(MapName :: term(), Key ::term(), sync_type()).
    gs:map_find(MapName :: term(), Key :: term()).
    gs:map_foreach(MapName :: term(), fun((Key :: term(), Value :: term()) -> any())).
    gs:map_fodl(MapName :: term(), fun((Key :: term(), Value :: term(), AccIn :: term()) -> AccOut :: term())).
    gs:print_map(MapName :: term()).
```
#### sync
```Erlang
    gs_sync:modify_sync_delay(non_neg_integer()).
```
### TODO
   * Global synchronization lock, used to solve the problem the nodes which join midway may not be able to achieve eventual consistency
   * Counter

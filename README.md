# Erlang 全局存储器
[![cn](https://img.shields.io/badge/lang-中文-blue.svg)](https://github.com/lafirest/erlang_global_store/blob/main/README.md)
[![en](https://img.shields.io/badge/lang-English-red.svg)](https://github.com/lafirest/erlang_global_store/blob/main/README_en.md)

------
   一个简单的Erlang全局数据共享APP
## 缘由
   有时我需要在所有Erlang节点间间共享一些数据，最开始使用的是mnesia, 但mnesia太过于重度,使用起来问题很多,后来换成了[syn插件](https://github.com/ostinelli/syn ""), 但这个插件是专门用来做分布式路由的，而我需要共享的不仅仅是路由信息.更严重的是，在大量数据涌入时，广播同步会带来很高的系统负载  
   然后我也考虑过使用一致性哈希，但我面对的问题都是读多写少，而一致性哈希的读性能显然不如写同步方式更佳   
   所以最后我就写了这个默认基于一小段延迟的写同步内存字典

## 实现的功能:
   * 基于K/V的注册 删除 查找
   * 群组功能，可以将一个值存入某个全局的群组中
   * 可控制的同步方式:
        * 不同步，仅本地修改
        * 延迟同步(默认),本地修改会延迟一段时间再进行同步(避免大量数据涌入时的广播风暴,比如游戏服务器开服登录时)
        * 紧急同步，立刻和其他节点进行同步
   * 节点挂掉时，其他节点将会注销掉从这个节点写入的数据
## 未实现的功能:
   * 数据冲突解决,因为这是很简单的应用，所以不存在所谓的数据冲突解决,所有写入都是直接覆盖之前的数据
   * 数据保护,同上,任何节点都能对任何键直接写入
## 使用
### 环境变量配置:
   需要在application env中提供以下两个变量:
       1. arbiter 裁决服务器，用于在新节点登录时，获取旧的数据
       2. sync_delay 同步延迟
   如果是使用rebar,则直接在sys.config中加入以下设置即可
```Erlang
    {gs, [{arbiter, 's1@127.0.0.1'}, {sync_delay, 100}]}
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
    gs:find(Key :: term()).
```
#### Group
```Erlang
    gs:join_group(GroupName :: term(), Value ::term()).
    gs:join_group(GroupName :: term(), Value ::term(), sync_type()).
    gs:exit_gropp(GroupName :: term(), Value ::term()).
    gs:exit_group(GroupName :: term(), Value ::term(), sync_type()).
    gs:traverse_group(GroupName :: term(), fun((Value :: term()) -> any())).
```

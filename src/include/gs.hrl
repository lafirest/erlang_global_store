-define(gs_name_table, gs_name_table).
-define(gs_group_table, gs_group_table).
-define(gs_map_table, gs_map_table).

-record(key_value, {key :: term(), 
                    value :: term(),
                    node :: node()}).

-record(map_value, {value :: term(),
                    node :: node()}).



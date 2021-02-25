-define(gs_name_table, gs_name_table).
-define(gs_group_table, gs_group_table).

-record(gs_name, {name :: term(), 
                  value :: term(),
                  node :: node()}).



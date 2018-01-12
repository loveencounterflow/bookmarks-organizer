
-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _U_ cascade;
create schema _U_;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function _U_.tabulate( data_ jsonb ) returns text strict immutable language plpython3u as $$
  plpy.execute( 'select INIT.py_init()' )
  ctx   = GD[ 'ctx' ]
  import json
  data  = json.loads( data_ )
  return ctx.tabulate.tabulate( data )
  $$;
reset role;


do $$ begin perform log( _U_.tabulate( '[ ["body","radius / km", "mass / 10^29 kg"], ["Sun",696000,1989100000],["Earth",6371,5973.6], ["Moon",1737,73.5],["Mars",3390,641.85]]'::jsonb
  ) ); end; $$;


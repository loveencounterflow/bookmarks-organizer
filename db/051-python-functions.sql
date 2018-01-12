

-- -- ---------------------------------------------------------------------------------------------------------
-- create function U.tabulate( data_ json ) returns text strict immutable language plpgsql as $$
--   $$;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function U.tabulate( data_ jsonb ) returns text strict immutable language plpython3u as $$
  plpy.execute( 'select INIT.py_init()' )
  ctx   = GD[ 'ctx' ]
  import json
  data  = json.loads( data_ )
  return ctx.tabulate.tabulate( data )
  $$;
reset role;

-- ---------------------------------------------------------------------------------------------------------
create function U.tabulate( ¶data json ) returns text strict immutable language sql as $$
  select U.tabulate( ¶data::jsonb ); $$;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function U.query_as_jsonb( q_ text ) returns jsonb strict immutable language plpython3u as $$
  import json as JSON
  plpy.execute( 'select INIT.py_init()' )
  ctx   = GD[ 'ctx' ]
  rows  = plpy.execute( q_ )
  names = rows.colnames()
  R     = [ names, ]
  for row in rows:
    R.append( [ row[ name ] for name in names ] )
  return JSON.dumps( R )
  $$;
reset role;

-- ---------------------------------------------------------------------------------------------------------
create function U.tabulate_query( ¶q text ) returns text strict immutable language sql as $$
  select U.tabulate( U.query_as_jsonb( ¶q ) ); $$;


/*

select U.tabulate( U.query_as_jsonb( $$ select * from my_table where my_column = 3; $$ ) );
select U.tabulate(
  U.query_as_jsonb(
    format(
      $$ select * from my_table where my_column = %L; $$, 3 ) ) );

*/

-- do $$ begin perform log( _U_.tabulate( '[ ["body","radius / km", "mass / 10^29 kg"], ["Sun",696000,1989100000],["Earth",6371,5973.6], ["Moon",1737,73.5],["Mars",3390,641.85]]'::jsonb
--   ) ); end; $$;


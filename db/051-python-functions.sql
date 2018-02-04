

-- -- ---------------------------------------------------------------------------------------------------------
-- create function U.tabulate( data_ json ) returns text strict immutable language plpgsql as $$
--   $$;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function U.tabulate( data_ jsonb ) returns text strict immutable language plpython3u as $$
  plpy.execute( 'select INIT.py_init()' ); ctx = GD[ 'ctx' ]
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
  plpy.execute( 'select INIT.py_init()' ); ctx = GD[ 'ctx' ]
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

-- ---------------------------------------------------------------------------------------------------------
create type U.url as (
  scheme    text,
  netloc    text,
  username  text,
  password  text,
  hostname  text,
  port      text,
  path      text,
  params    text,
  query     text,
  fragment  text );

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function U.parse_url( url_ text ) returns U.url strict immutable language plpython3u as $$
  plpy.execute( 'select INIT.py_init()' ); ctx = GD[ 'ctx' ]
  ctx.url_parser.parse( url_ );
  $$;
reset role;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function U.parse_url_words( url_ text ) returns text[] strict immutable language plpython3u as $$
  plpy.execute( 'select INIT.py_init()' ); ctx = GD[ 'ctx' ]
  return ctx.url_parser.parse_words( url_ );
  $$;
reset role;


/*

select U.tabulate( U.query_as_jsonb( $$ select * from my_table where my_column = 3; $$ ) );
select U.tabulate(
  U.query_as_jsonb(
    format(
      $$ select * from my_table where my_column = %L; $$, 3 ) ) );

*/


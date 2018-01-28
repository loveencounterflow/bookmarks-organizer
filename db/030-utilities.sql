
/*

888     888
888     888
888     888
888     888
888     888
888     888
Y88b. .d88P
 "Y88888P"

*/

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists U cascade;
create schema U;

-- .........................................................................................................
create domain U.null_text             as text     check ( value is null                 );
create domain U.null_integer          as integer  check ( value is null                 );
create domain U.nonnegative_integer   as integer  check ( value >= 0                    );
create domain U.positive_integer      as integer  check ( value >= 1                    );
create domain U.nonempty_text         as text     check ( value != ''                   );
create domain U.chr                   as text     check ( character_length( value ) = 1 );
-- .........................................................................................................
create type U.text_facet              as ( key    text,     value text      );
create type U.jsonb_facet             as ( key    text,     value jsonb     );
create type U.line_facet              as ( linenr integer,  line  text      );
create type U.jsonbl_facet            as ( linenr integer,  value jsonb     );
create type U.integer_facet           as ( key    text,     value integer   );
create type U.float_facet             as ( key    text,     value float     );

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists NAMEOF cascade;
create schema NAMEOF;

-- ---------------------------------------------------------------------------------------------------------
/* aliases for names of DB objects; see table at https://www.postgresql.org/docs/current/static/datatype-oid.html */
create domain NAMEOF.function   as regproc;         /* pg_proc       */
create domain NAMEOF.operator   as regoper;         /* pg_operator   */
create domain NAMEOF.relation   as regclass;        /* pg_class      */
create domain NAMEOF.data_type  as regtype;         /* pg_type       */
create domain NAMEOF.role       as regrole;         /* pg_authid     */
create domain NAMEOF.schema     as regnamespace;    /* pg_namespace  */
-- create domain NAMEOF.numeric_object_identifier     as oid;             /* any           */
-- create domain NAMEOF.function_with_atypes          as regprocedure;    /* pg_proc       */
-- create domain NAMEOF.operator_with_atypes          as regoperator;     /* pg_operator   */
-- create domain NAMEOF.text_search_configuration     as regconfig;       /* pg_ts_config  */
-- create domain NAMEOF.text_search_dictionary        as regdictionary;   /* pg_ts_dict    */

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *  */
/* thx to https://stackoverflow.com/a/24006432/7568091 */
/*

functions to turn a select into json, text, display it:

-- select array_to_json(  array_agg( t ) ) from ( select 1 as a union all select 2 ) as t;
-- select json_agg( t ) from ( select 1 as a union all select 2 ) as t;
-- \quit

    X := json_agg( t )::text from ( select aid, act from _FSM2_.journal where bid = new.bid union select 111111, new.act ) as t;
    perform log( '00902', 'existing', X );
    X := json_agg( t )::text from ( select new ) as t;
*/
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *  */

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *  */
/*

turn a table with keys and values into a single JSON object:


drop table if exists d cascade;
create table d ( key text, value text );
insert into d values
  ( 'key_A', 'value_a' ),
  ( 'key_B', 'value_b' );

with  keys    as ( select array_agg( key    order by key ) as k from d ),
      values  as ( select array_agg( value  order by key ) as v from d )
  select jsonb_object( keys.k, values.v ) from keys, values;

               jsonb_object
------------------------------------------
 {"key_A": "value_a", "key_B": "value_b"}

*/
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *  */

-- -- ---------------------------------------------------------------------------------------------------------
-- create function T._is_distinct_from( anyelement, anyelement ) returns boolean immutable language sql as $$
--   select $1 is distinct from $2; $$;

-- -- ---------------------------------------------------------------------------------------------------------
-- create function T._is_distinct_from( anyarray, anyarray ) returns boolean immutable language sql as $$
--   select $1 is distinct from $2; $$;

-- ---------------------------------------------------------------------------------------------------------
create function U.text_array_from_json( jsonb )
  /* Accepts a textual JSON-compliant representation of an array and returns an SQL `array` with text
  elements. This is needed primarily to pass `variadic text[]` arguments to public / RPC UDFs.
  Thx to https://dba.stackexchange.com/a/54289/126933 */
  returns text[] immutable language sql as $$
  select array( select jsonb_array_elements_text( $1 ) )
  $$;

-- ---------------------------------------------------------------------------------------------------------
create function U.bigint_array_from_json( jsonb )
  /* Accepts a textual JSON-compliant representation of an array and returns an SQL `array` with bigint
  elements. This is needed primarily to pass `variadic bigint[]` arguments to public / RPC UDFs.
  Thx to https://dba.stackexchange.com/a/54289/126933 */
  returns bigint[] immutable language sql as $$
  select array( select jsonb_array_elements_text( $1 ) )::bigint[]
  $$;

/* thx to https://stackoverflow.com/a/37278190/7568091 (J. Raczkiewicz) */
create function U.jsonb_diff( a jsonb, b jsonb )
returns jsonb immutable language plpgsql as $$
  declare
    R             jsonb;
    object_result jsonb;
    n             int;
    value         record;
  begin
    if jsonb_typeof(a) = 'null' then return b; end if;
    -- .....................................................................................................
    R = a;
    for value in select * from jsonb_each( a ) loop
      R = R || jsonb_build_object( value.key, null );
      end loop;
    -- .....................................................................................................
    for value in select * from jsonb_each( b ) loop
      -- ...................................................................................................
      if jsonb_typeof( a->value.key ) = 'object' and jsonb_typeof( b->value.key ) = 'object' then
        object_result = U.jsonb_diff( a->value.key, b->value.key );
        -- .................................................................................................
        /* check if R is not empty */
        n := ( select count(*) from jsonb_each( object_result ) );
        -- .................................................................................................
        if n = 0 then
          --if empty, remove:
          R := R - value.key;
        -- .................................................................................................
        else
          R := R || jsonb_build_object( value.key, object_result );
          end if;
      -- ...................................................................................................
      elsif a->value.key = b->value.key then
        R = R - value.key;
      else
        R = R || jsonb_build_object( value.key,value.value );
        end if;
      end loop;
    -- .....................................................................................................
    return R;
    end;
    $$;

-- ---------------------------------------------------------------------------------------------------------
/* thx to https://stackoverflow.com/a/39812817/7568091 */
create function U.count_jsonb_keys( diff jsonb )
returns integer immutable language plpgsql as $$
  begin
    select array_upper( array( select jsonb_object_keys( diff ) ), 1 );
    end;
    $$;

-- ---------------------------------------------------------------------------------------------------------
/* thx to https://stackoverflow.com/a/39812817/7568091 */
create function U.truth( boolean )
returns text immutable language plpgsql as $$
  begin
    case $1
      when true   then  return 'true';
      when false  then  return 'false';
      else              return '∎';
      end case;
    end; $$;

  -- declare
  --   green   text;
  --   red     text;
  --   reset   text;
  -- begin
  --   select into reset value from TRM.colors where key = 'reset';
  --   if $1 then
  --     select into green value from TRM.colors where key = 'green';
  --     return green  || 'true'  || reset;
  --   else
  --     select into red   value from TRM.colors where key = 'red';
  --     return red    || 'false' || reset;
  --     end if;
  --   end;
  --   $$;

-- =========================================================================================================
-- VARIABLES
-- ---------------------------------------------------------------------------------------------------------
create table U.variables of U.text_facet ( key unique not null primary key );

/*
-- ---------------------------------------------------------------------------------------------------------
drop function if exists ¶( text ) cascade;
create function ¶( ¶key text ) returns text stable language plpgsql as $$
  begin return current_setting( 'xxx.' || ¶key ); end; $$;

-- ---------------------------------------------------------------------------------------------------------
drop function if exists ¶( text, text ) cascade;
create function ¶( ¶key text, ¶value anyelement ) returns void stable language plpgsql as $$
  begin perform set_config( 'xxx.' || ¶key, ¶value, false ); end; $$;
*/

-- ---------------------------------------------------------------------------------------------------------
drop function if exists ¶( text ) cascade;
create function ¶( ¶key text ) returns text volatile language sql as $$
  select value from U.variables where key = ¶key; $$;

-- ---------------------------------------------------------------------------------------------------------
drop function if exists ¶( text, anyelement ) cascade;
create function ¶( ¶key text, ¶value anyelement ) returns void volatile language sql as $$
  insert into U.variables values ( ¶key, ¶value )
  on conflict ( key ) do update set value = ¶value; $$;

-- ---------------------------------------------------------------------------------------------------------
do $$ begin
  perform ¶( 'username', current_user );
  end; $$;

-- =========================================================================================================
-- CONVERSION TO JSONB
-- ---------------------------------------------------------------------------------------------------------
create function jb( ¶x text ) returns jsonb immutable strict language sql as $$
  select to_jsonb( ¶x ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function jb( ¶x anyelement ) returns jsonb immutable strict language sql as $$
  select to_jsonb( ¶x ); $$;

comment on function jb( text )        is '`jb()` works almost like `to_jsonb()`, except that strings do not have to be quoted.';
comment on function jb( anyelement )  is '`jb()` works almost like `to_jsonb()`, except that strings do not have to be quoted.';

-- ---------------------------------------------------------------------------------------------------------
set role dba;
/* Expects an SQL query as text that delivers two columns, the first being names and the second JSONb
  values of the object to be built. */
create function U.facets_as_jsonb_object( sql_ text ) returns jsonb stable language plpython3u as $$
  plpy.execute( 'select INIT.py_init()' ); ctx = GD[ 'ctx' ]
  import json as JSON
  R             = {}
  result        = plpy.execute( sql_ )
  ( k, v, )     = result.colnames()
  for row in result:
    if row[ v ] == None:
      R[ row[ k ] ] = None
      continue
    R[ row[ k ] ] = JSON.loads( row[ v ] )
  return JSON.dumps( R ) $$;
reset role;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
drop function if exists U.row_as_jsonb_object cascade;
/* Expects an SQL query as text that delivers two columns, the first being names and the second JSONb
  values of the object to be built. */
create function U.row_as_jsonb_object( sql_ text ) returns jsonb stable language plpython3u as $$
  plpy.execute( 'select INIT.py_init()' ); ctx = GD[ 'ctx' ]
  import json as JSON
  R                   = {}
  result              = plpy.execute( sql_ )
  keys_and_typenames  = ctx.keys_and_typenames_from_result( ctx, result )
  #.........................................................................................................
  if len( result ) != 1:
    raise ValueError( "expected 1 result row, got " + str( len( result ) ) + " from query " + repr( sql_ ) )
  #.........................................................................................................
  for row in result:
    for key, typename in keys_and_typenames:
      R[ key ] = value = row[ key ]
      if value is not None and typename in ( 'json', 'jsonb', ):
        R[ key ] = JSON.loads( value )
  #.........................................................................................................
  return JSON.dumps( R ) $$;
reset role;


-- =========================================================================================================
-- ARRAYS
-- ---------------------------------------------------------------------------------------------------------
-- /* thx to https://stackoverflow.com/a/8142998/7568091 */
-- create function U.unnest_2d_1d( anyarray ) returns setof anyarray immutable strict language sql as $$
--   select
--       array_agg( $1[ d1 ][ d2 ] )
--   from
--     generate_subscripts( $1, 1 ) as d1,
--     generate_subscripts( $1, 2 ) as d2
--   group by d1
--   order by d1; $$;

-- ---------------------------------------------------------------------------------------------------------
/* thx to https://stackoverflow.com/a/8142998/7568091
  https://stackoverflow.com/a/41405177/7568091 */
create or replace function U.unnest_2d_1d( anyarray, out a anyarray )
  returns setof anyarray immutable strict language plpgsql as $$
  begin
    foreach a slice 1 in array $1 loop
      return next;
      end loop;
    end $$;

-- -- ---------------------------------------------------------------------------------------------------------
-- create or replace function U.filter_array( ¶array anyarray, ¶value anyelement )
--   returns anyarray immutable language sql as $$
--   select array_agg( x ) from unnest( ¶array ) as x where x is distinct from ¶value; $$;



\quit


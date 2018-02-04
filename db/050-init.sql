

/*

8888888            d8b  888
  888              Y8P  888
  888                   888
  888    88888b.   888  888888
  888    888 "88b  888  888
  888    888  888  888  888
  888    888  888  888  Y88b.
8888888  888  888  888   "Y888

*/


-- ---------------------------------------------------------------------------------------------------------
drop schema if exists INIT cascade;
create schema INIT;


-- -- ---------------------------------------------------------------------------------------------------------
-- create table PUBLIC.kbm_settings (
--   key   text unique not null primary key,
--   value text        not null
--   );

-- -- ---------------------------------------------------------------------------------------------------------
-- insert into PUBLIC.kbm_settings
--   select
--       lower( regexp_replace( key, '^kbm_', '' ) ) as key,
--       value
--     from INIT.environment
--     where key ~ '^kbm_'
--     -- order by key asc
--   ;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function INIT.py_init() returns void language plpython3u as $$
    if 'ctx' in GD: return
    import sys
    import os
    from pathlib import Path
    #.......................................................................................................
    # https://stackoverflow.com/a/29548234
    # https://stackoverflow.com/a/29548234/7568091
    class AttributeDict(dict):
      def __getattr__(self, attr):
        return self[attr]
      def __setattr__(self, attr, value):
        self[attr] = value
    #.......................................................................................................
    ctx           = AttributeDict()
    target        = AttributeDict()
    GD[ 'ctx' ]   = ctx
    ctx.plpy      = plpy
    ctx.execute   = plpy.execute
    ctx.notice    = plpy.notice
    #.......................................................................................................
    def get_os_env_value( key ):
      sql   = """select value from OS.env where key = $1"""
      plan  = plpy.prepare( sql, [ 'text', ] )
      rows  = plpy.execute( plan, [ key, ] )
      if len( rows ) != 1:
        raise Exception( "unable to find setting  bmo_python_path in OS.env" )
      return rows[ 0 ][ 'value' ]
    #.......................................................................................................
    ctx.get_os_env_value = get_os_env_value
    #.......................................................................................................
    ctx.python_path       = ctx.get_os_env_value( 'bmo_python_path'       )
    ctx.psql_output_path  = ctx.get_os_env_value( 'bmo_psql_output_path'  )
    sys.path.insert( 0, ctx.python_path )
    #.......................................................................................................
    def log( *P ):
      R = []
      for p in P:
        if isinstance( p, str ):  R.append( p )
        else:                     R.append( repr( p ) )
      R = ' '.join( R )
      with open( ctx.psql_output_path, 'ab' ) as o:
        o.write( R.encode( 'utf-8' ) + b'\n' )
      return R
    #.......................................................................................................
    ctx.log = log
    #.......................................................................................................
    import bmo_main
    bmo_main.setup( ctx )
    #.......................................................................................................
    $$;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
drop function if exists log( variadic text[] ) cascade;
create function log( value variadic text[] ) returns void language plpython3u as $$
  plpy.execute( 'select INIT.py_init()' )
  ctx = GD[ 'ctx' ]
  value_ = [ str( e ) for e in value ]
  with open( ctx.psql_output_path, 'ab' ) as o:
    o.write( ' '.join( value_ ).encode( 'utf-8' ) + b'\n' )
  $$;
reset role;

-- ---------------------------------------------------------------------------------------------------------
create function log() returns void language sql as $$ select log( '' ); $$;

/* use log like so:
do $$ begin perform log( ( 42 + 108 )::text ); end; $$;
*/

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function INIT._test() returns void language plpython3u as $$
  plpy.execute( 'select INIT.py_init()' )
  ctx = GD[ 'ctx' ]
  import sys
  for idx, path in enumerate( sys.path ):
    ctx.log( idx + 1, path )
  # ctx.log( ctx )
  ctx.log( "INIT.py_init OK" )
  import signals
  ctx.log( 'signals', signals )
  ctx.log( ctx.url_parser )
  return
  $$;
reset role;



/* ###################################################################################################### */

do $$ begin perform INIT._test(); end; $$;
do $$ begin perform log( 'using log function OK' ); end; $$;

\quit







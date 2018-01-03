

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
/* ### TAINT must separate initialization of settings tables and initialization of
Python environment */
create function INIT.py_init()
  returns void
  language plpython3u
  as $$
    if 'ctx' in GD: return
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
    ### OBS circular assignment ###
    GD[ 'ctx' ]   = ctx
    # ctx.GD        = GD
    ctx.plpy      = plpy
    ctx.notice    = plpy.notice
    #.......................................................................................................
    import sys
    import os
    from pathlib import Path
    sql   = """select value from PUBLIC.kbm_settings where key ='bin_path'"""
    rows  = plpy.execute( sql )
    if len( rows ) != 1:
      raise Exception( "unable to find setting  bin_path in PUBLIC.kbm_settings" )
    ctx.bin_path        = Path( rows[ 0 ][ 'value' ] )
    ctx.home_path       = Path( ctx.bin_path ).parent
    ctx.src_path        = ctx.home_path / 'src'
    ctx.sql_path        = ctx.home_path / 'db'
    ### OBS must be string, not a `Path` object ###
    ref_path            = str( ctx.sql_path )
    sys.path.insert( 0, ref_path )
    import my_http
    ctx.my_http         = my_http
    ### NOTE DO NOT USE os.chdir(), it will change the PostgreSQL working directory!!! ###
    # os.chdir( ref_path )
    sql = """
      insert into PUBLIC.kbm_settings values ( $1, $2 )
      on conflict ( key ) do update set value = excluded.value;
      """
    plan = plpy.prepare( sql, [ 'text', 'text', ] )
    ### TAINT another set of the same values provided by app on startup ###
    plpy.execute( plan, [         'src_path', ctx.src_path,                         ] )
    plpy.execute( plan, [         'sql_path', ctx.sql_path,                         ] )
    plpy.execute( plan, [        'home_path', ctx.home_path,                        ] )
    #.......................................................................................................
    def log( *P ):
      with open( '/tmp/psql-output', 'a' ) as o:
        o.write( ' '.join( P ) + '\n' )
    ctx.log = log
    #.......................................................................................................
    # ctx.notice( '27272-1', list( name for name in ctx ) )
    # ctx.notice( '27272-2', ctx )
    # ctx.notice( '27272-3', GD )
    # ctx.notice( '27272-4', [ key for key in GD ] )
    # ### TAINT hardcoded path ###
    # with open( '/tmp/psql-signals', 'a' ) as o:
    #   o.write( '' )
    # os.chmod( '/tmp/psql-signals', 0o666 )
  $$;
reset role;

-- create table INIT.js ( id serial, x jsonb );
-- insert into INIT.js ( x ) values ( '"foo"' );
-- insert into INIT.js ( x ) values ( '{ "a":42 }' );
-- insert into INIT.js ( x ) values ( '42' );

-- ---------------------------------------------------------------------------------------------------------
set role dba;
drop function if exists log( variadic text[] ) cascade;
create function log( value variadic text[] )
  returns void
  language plpython3u
  as $$
    value_ = [ str( e ) for e in value ]
    with open( '/tmp/psql-output', 'ab' ) as o:
      o.write( ' '.join( value_ ).encode( 'utf-8' ) + b'\n' )
    $$;
reset role;
/* use log like so:
do $$ begin perform log( ( 42 + 108 )::text ); end; $$;
*/

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function INIT._test()
  returns void
  language plpython3u
  as $$
    import sys
    import os
    # ctx = GD[ 'ctx' ]
    # import my_http as http
    # file:///home/flow/io/mingkwai-rack/mojikura/python_modules/fmt.py
    # plpy.execute("select INIT.py_init()")
    for idx, path in enumerate( sys.path ):
      plpy.notice( idx + 1, path )
    plpy.notice( os.environ )
    # import fmt
    # plpy.notice( fmt )
    # rows = plpy.execute( """select * from INIT.js;""" )
    # for row in rows:
    #   ctx.notice( '33211', row )
  $$;
reset role;



-- #########################################################################################################
-- select INIT.py_init();
-- \ir './035-sh.sql'
-- refresh materialized view OS.env;
-- \ir './update-os-env.sql'
select * from OS.env where key ~ 'PY|PAGER|^[a-z]';
-- select INIT._test();
-- \set os_environment `printenv`
-- \echo :os_environment
-- select * from PUBLIC.kbm_settings;







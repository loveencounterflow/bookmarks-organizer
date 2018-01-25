
/*

8888888888 8888888b.   888       888
888        888  "Y88b  888   o   888
888        888    888  888  d8b  888
8888888    888    888  888 d888b 888
888        888    888  888d88888b888
888        888    888  88888P Y88888
888        888  .d88P  8888P   Y8888
888        8888888P"   888P     Y888

*/

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists FLR cascade;
create schema FLR;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function FLR.read_file_lines( path_ text ) returns table ( linenr integer, line text )
  volatile language plpython3u as $$
  # plpy.execute( 'select INIT.py_init()' ); ctx = GD[ 'ctx' ]
  with open( path_, 'rb' ) as input:
    for linenr, line in enumerate( input ):
      yield [ linenr, line.decode( 'utf-8' ).rstrip(), ]
  $$;
reset role;

-- ---------------------------------------------------------------------------------------------------------
create function FLR.read_jsonlb_file( ¶path text ) returns table ( linenr integer, line jsonb )
  volatile language sql as $$
  select linenr, line::jsonb as value from FLR.read_jsonlb_file( ¶path ); $$;





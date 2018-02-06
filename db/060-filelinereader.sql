
/*

8888888888 888      8888888b.
888        888      888   Y88b
888        888      888    888
8888888    888      888   d88P
888        888      8888888P"
888        888      888 T88b
888        888      888  T88b
888        88888888 888   T88b

*/

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists FLR cascade;
create schema FLR;

-- ---------------------------------------------------------------------------------------------------------
create function FLR.is_comment( ¶line text ) returns boolean
  immutable strict language sql as $$
  select ¶line ~ '^\s*#'; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FLR.is_blank( ¶line text ) returns boolean
  immutable strict language sql as $$
  select ¶line ~ '^\s*$'; $$;

-- ---------------------------------------------------------------------------------------------------------
/* convenience function; could be optimized to use single RegEx */
create function FLR.is_comment_or_blank( ¶line text ) returns boolean
  immutable strict language sql as $$
  select FLR.is_comment( ¶line ) or FLR.is_blank( ¶line ); $$;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function FLR.read_lines( path_ text ) returns setof U.line_facet
  volatile language plpython3u as $$
  # plpy.execute( 'select INIT.py_init()' ); ctx = GD[ 'ctx' ]
  with open( path_, 'rb' ) as input:
    for line_idx, line in enumerate( input ):
      yield [ line_idx + 1, line.decode( 'utf-8' ).rstrip(), ]
  $$;
reset role;

-- ---------------------------------------------------------------------------------------------------------
create function FLR.read_lines_skip( ¶path text ) returns setof U.line_facet
  volatile language sql as $$
    select * from FLR.read_lines( ¶path ) where not FLR.is_comment_or_blank( line ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FLR.read_jsonbl( ¶path text ) returns setof U.jsonbl_facet
  volatile language sql as $$
  select linenr, line::jsonb as value from FLR.read_lines( ¶path ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FLR.read_jsonbl_skip( ¶path text ) returns setof U.jsonbl_facet
  volatile language sql as $$
  select linenr, line::jsonb as value from FLR.read_lines_skip( ¶path ); $$;





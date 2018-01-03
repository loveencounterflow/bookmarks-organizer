
\ir './010-trm.sql'
\pset tuples_only off
\timing on

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists SRC cascade;
create schema SRC;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function SRC._split_with_quotes_A( x text ) returns text[]
  immutable returns null on null input language plpython3u as $$
    import shlex as _SHLEX
    # shlex.split( s, comments=False, posix=True )
    return _SHLEX.split( x, False, False )
    $$;
create function SRC._split_with_quotes_B( x text ) returns text[]
  immutable returns null on null input language plpython3u as $$
    import shlex as _SHLEX
    # shlex.split( s, comments=False, posix=True )
    return _SHLEX.split( x, False, True )
    $$;
create function SRC._split_with_quotes_C( x text ) returns text[]
  immutable returns null on null input language plpython3u as $$
    import shlex as _SHLEX
    lex = _SHLEX.shlex( x, posix = False )
    lex.whitespace_split = True
    # plpy.notice( dir( lex ) )
    return list( lex )
    $$;
reset role;

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(1)=--':O
select FDW.create_file_lines_view(
  'src._bookmarks_000_raw',
  /* ### TAINT use proper PATH.join */
  ¶( 'paths/home') || '/' || 'bookmarks.txt' ) \g :devnull
  ;

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(2)=--':O
create view SRC._bookmarks_010_skip_comments_and_empty as ( select
    linenr,
    line
  from
    SRC._bookmarks_000_raw
  where true
    and line !~ '^\s*#'
    and line !~ '^\s*$'
  );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(3)=--':O
create view SRC._bookmarks_012_skip_tail as ( with v1 as (
  select
      linenr as stop_line_nr
    from SRC._bookmarks_010_skip_comments_and_empty where line = '*stop*'
    union all select 1e9
    order by stop_line_nr
    limit 1 )
  select
    v2.linenr   as linenr,
    v2.line     as line
  from
    SRC._bookmarks_010_skip_comments_and_empty as v2,
    v1
  where true
    and v2.linenr < coalesce( v1.stop_line_nr, 1e208 ) );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(4)=--':O
create view SRC._bookmarks_020_split_asterisk as ( select
    linenr                                                      as linenr,
    case when line ~ '^\*' then 'group'::text else '...' end    as star,
    regexp_replace( line, '^(\* |  )', '' )                     as line
  from SRC._bookmarks_012_skip_tail
  );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(5)=--':O
create view SRC._bookmarks_030_add_levels as ( select
    linenr                                                      as linenr,
    star                                                        as star,
      case when line ~ '^\s+' then 2
      else 1 end                                                as level,
    -- case when star = 'group' then 1 else
    --   case when line ~ '^\s+' then 3
    --   else 2 end end                                            as level,
    regexp_replace( line, '^\s+', '' )                          as line
  from SRC._bookmarks_020_split_asterisk
  );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(6)=--':O
create view SRC._bookmarks_040_split_fields as ( select
    linenr                                                      as linenr,
    star                                                        as star,
    level                                                       as level,
    case level
      when 1 then regexp_replace( line, '^([^:]+):.*$', '\1' )
      else '...' end                                            as key,
    case level
      when 1 then regexp_replace( line, '^[^:]+:\s*(.*?)\s*$', '\1' )
      else line end                                             as value
  from SRC._bookmarks_030_add_levels
  );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(6)=--':O
create view SRC._bookmarks_050_split_values as ( select
    linenr                                                                      as linenr,
    star                                                                        as star,
    level                                                                       as level,
    key                                                                         as key,
    value                                                                       as value,
    case when key in ( 'url', 'tags' ) then SRC._split_with_quotes_A( value )
    else null end                                                               as values_A,
    case when key in ( 'url', 'tags' ) then SRC._split_with_quotes_B( value )
    else null end                                                               as values_B,
    case when key in ( 'url', 'tags' ) then SRC._split_with_quotes_C( value )
    else null end                                                               as values_C
  from SRC._bookmarks_040_split_fields
  );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(7)=--':O
create view SRC._bookmarks as ( select * from SRC._bookmarks_050_split_values order by linenr );

/* ###################################################################################################### */

\quit

select * from U.variables where not key ~ '^[A-Z]' \g :out

-- select * from SRC._bookmarks_000_raw limit 10;
-- select * from SRC._bookmarks_010_skip_comments_and_empty;
-- select * from SRC._bookmarks_020_split_asterisk order by linenr;
-- select * from SRC._bookmarks_030_add_levels order by linenr;
select
    linenr                                                            as linenr,
    key                                                               as key,
    '∎ ' || substring( array_to_string( values_A, ' ∎ ' ) for 80 )     as values_A,
    -- '∎ ' || substring( array_to_string( values_B, ' ∎ ' ) for 80 )     as values_B,
    '∎ ' || substring( array_to_string( values_C, ' ∎ ' ) for 80 )     as values_C,
    value                                                             as value
  from SRC._bookmarks
  order by linenr;
\quit


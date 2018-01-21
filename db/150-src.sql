
\ir './010-trm.sql'
-- \pset tuples_only off
-- \timing on
-- vacuum;


-- select linenr, value, 'C', U.text_array_from_json( parts->'C' ) from SRC.bookmarks;
-- select * from SRC.bookmarks;
-- select parts->'C' from SRC.bookmarks;
-- select parts->'C' from SRC.bookmarks where ( parts->'C' ) != 'null'::jsonb;
-- -- select pg_typeof( parts->'C' ) from SRC.bookmarks;
-- select U.text_array_from_json( parts->'C' ) from SRC.bookmarks where ( parts->'C' ) != 'null'::jsonb;
-- \quit


-- \echo 'select * from SRC._bookmarks_050_split_values;'
-- select * from SRC._bookmarks_050_split_values;

-- \echo 'select * from SRC._bookmarks_060;'
-- select * from SRC._bookmarks_060;

-- \echo 'select * from SRC._bookmarks_070;'
-- select * from SRC._bookmarks_070;

-- \quit

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists SRC cascade;
create schema SRC;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function SRC.split_on_whitespace( x text ) returns text[]
  immutable strict language sql as $$
    select regexp_split_to_array( x, E'\\s+' ); $$;
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
\echo :X'--=(7)=--':O
create view SRC._bookmarks_050_split_values as ( select
    linenr                                                                      as linenr,
    star                                                                        as star,
    level                                                                       as level,
    key                                                                         as key,
    value                                                                       as value,
    case key
      when 'tags' then UTP.lex_tags(            value )
      -- when 'url'  then SRC.split_on_whitespace( value )
    else null end                                                               as dacts
  from SRC._bookmarks_040_split_fields
  );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(8)=--':O
create table SRC._bookmarks_060 as ( select
    linenr                            as linenr,
    value                             as value,
    unnest( FM.push_dacts( dacts ) )  as ac
  from SRC._bookmarks_050_split_values
  order by linenr);

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(9)=--':O
create table SRC._bookmarks_070 as ( select
    v1.linenr                                           as linenr,
    b.star                                              as star,
    b.level                                             as level,
    b.key                                               as key,
    v1.value                                            as value,
    j.ac                                                as ac,
    j.bc                                                as bc,
    U.row_as_jsonb_object( format(
      'select * from FM.board where bc = %L;', j.bc ) ) as registers
  from SRC._bookmarks_060 as v1
  left join FM.journal                      as j on ( v1.ac       = j.ac      )
  left join SRC._bookmarks_050_split_values as b on ( v1.linenr   = b.linenr  )
  order by linenr );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(10)=--':O
create view SRC.bookmarks as ( select * from SRC._bookmarks_070 order by linenr );


/* ###################################################################################################### */

\echo 'select * from FM.journal;'
select * from FM.journal;

\echo 'select * from SRC.bookmarks;'
select * from SRC.bookmarks;

\quit



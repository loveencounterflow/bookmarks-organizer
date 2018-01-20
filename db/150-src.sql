
\ir './010-trm.sql'
-- \pset tuples_only off
-- \timing on

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists SRC cascade;
create schema SRC;

-- -- ---------------------------------------------------------------------------------------------------------
-- set role dba;
-- /* ### TAINT for backwards compatibility with PostGreSQL 9.6 and below, we have to use JSONb as an
--   intermediate format. */
-- create function SRC._lex_tags_py( x text ) returns jsonb
--   immutable strict language plpython3u as $$
--   plpy.execute( 'select INIT.py_init()' ); ctx = GD[ 'ctx' ]
--   import json as JSON
--   return JSON.dumps( ctx.utp_tag_parser.lex_tags( ctx, x ) )
--   $$;
-- reset role;

-- -- ---------------------------------------------------------------------------------------------------------
-- create function SRC.lex_tags( x text ) returns text[]
--   immutable strict language plpgsql as $$
--   declare
--     R       text[];
--     ¶row    jsonb;
--   begin
--     for ¶row in ( select * from jsonb_array_elements_text( SRC._lex_tags_py( x ) ) ) loop
--       R := R || array[ U.text_array_from_json( ¶row ) ] ;
--       end loop;
--     return R;
--     end; $$;

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
\echo :X'--=(6)=--':O
create view SRC._bookmarks_050_split_values as ( select
    linenr                                                                      as linenr,
    star                                                                        as star,
    level                                                                       as level,
    key                                                                         as key,
    value                                                                       as value,
    case key
      when 'tags' then UTP.lex_tags(            value )
      -- when 'url'  then SRC.split_on_whitespace( value )
    else null end                                                               as values
  from SRC._bookmarks_040_split_fields
  );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(7)=--':O
create view SRC.bookmarks as ( select * from SRC._bookmarks_050_split_values order by linenr );

/* ###################################################################################################### */



select * from SRC.bookmarks;

create view SRC._bookmarks_and_taglexes as ( select
  linenr, UTP.taglex_as_table( values ) as act_and_data from SRC.bookmarks order by linenr );

select * from SRC._bookmarks_and_taglexes;

create table SRC.bookmarks_and_acts as (
  select
      b1.linenr                                   as linenr,
      row_number() over ( partition by linenr )   as partnr,
      -- b1.star                                    as star,
      -- b1.level                                   as level,
      -- b1.key                                     as key,
      b1.value                                    as value,
      v1.act_and_data                             as act_and_data,
      FM.push( act_and_data )                     as ac
    from SRC.bookmarks as b1
    left join SRC._bookmarks_and_taglexes as v1 using ( linenr )
    order by linenr
    )
    ;
select * from SRC.bookmarks_and_acts;
\quit

select
  linenr, UTP.lex_tags from SRC.bookmarks;

select
    linenr                                                            as linenr,
    key                                                               as key,
    -- '∎' || substring( array_to_string( values, '∎' ) for 80 ) || '∎'  as values,
    FM.feed_pairs( values ),
    values                                                            as values,
    value                                                             as value
  from SRC.bookmarks
  order by linenr;
\quit

\quit

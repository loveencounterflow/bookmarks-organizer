
/*

 .d8888b.  8888888b.   .d8888b.
d88P  Y88b 888   Y88b d88P  Y88b
Y88b.      888    888 888    888
 "Y888b.   888   d88P 888
    "Y88b. 8888888P"  888
      "888 888 T88b   888    888
Y88b  d88P 888  T88b  Y88b  d88P
 "Y8888P"  888   T88b  "Y8888P"

*/

\ir './010-trm.sql'
\timing on


-- ---------------------------------------------------------------------------------------------------------
drop schema if exists SRC cascade;
create schema SRC;


-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function SRC.split_on_whitespace( x text ) returns text[]
  immutable strict language sql as $$
    select regexp_split_to_array( x, E'\\s+' ); $$;
reset role;

-- -- ---------------------------------------------------------------------------------------------------------
-- set role dba;
-- create function SRC.keywords_from_url( ¶url text ) returns text[]
--   immutable strict language plpgsql as $$
--   begin
--     perform U.parse_url( ¶url );
--     return '{}'::text[];
--     end; $$;
-- reset role;

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(1)=--':O
create view SRC._bookmarks_000_raw as (
  select linenr, line from FLR.read_lines(
    ¶( 'paths/home' ) || '/' || 'bookmarks.txt'
    ) );

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
create materialized view SRC._bookmarks_050_split_values as ( select
    linenr                                                                      as linenr,
    star                                                                        as star,
    level                                                                       as level,
    key                                                                         as key,
    value                                                                       as value,
    case key
      when 'tags' then UTP.lex_tags( value )
      -- when 'tags' then '{{identifier,foo}}'::text[]
      -- when 'url'  then SRC.split_on_whitespace( value )
      else null end                                                             as dacts
  from SRC._bookmarks_040_split_fields
  );

\echo :X'--=(8)=--':O
create index on SRC._bookmarks_050_split_values ( linenr );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(9)=--':O
-- explain analyze
create table SRC._bookmarks_060 as ( select
    linenr                            as linenr,
    value                             as value,
    unnest( FM.push_dacts( dacts ) )  as ac
  from SRC._bookmarks_050_split_values
  order by linenr);


-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(10)=--':O
create table SRC._bookmarks_070 as ( select
    v1.linenr                                           as linenr,
    b.star                                              as star,
    b.level                                             as level,
    b.key                                               as key,
    v1.value                                            as value,
    j.ac                                                as ac,
    r.value                                             as facets
  from SRC._bookmarks_060                   as v1
  left join FM.journal                      as j on ( v1.ac       = j.ac      )
  left join SRC._bookmarks_050_split_values as b on ( v1.linenr   = b.linenr  )
  left join FM.results                      as r on ( v1.ac       = r.ac      )
  order by linenr );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(10)=--':O
create view SRC._bookmarks_075_urls as ( select
    a.linenr                                            as linenr,
    a.star                                              as star,
    a.level                                             as level,
    a.key                                               as key,
    a.value                                             as value,
    w.*                                                 as facet
  from
    SRC._bookmarks_050_split_values as a,
    lateral ( select U.unnest_2d_1d( x ) from U.parse_url_words( a.value ) as x ) as w
  where a.key = 'url' );


/* -- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(10)=--':O
create view SRC._bookmarks_075_urls as ( select
    a.linenr                                            as linenr,
    a.star                                              as star,
    a.level                                             as level,
    a.key                                               as key,
    a.value                                             as value,
    w.keytype                                           as keytype,
    w.keyword                                           as keyword
    -- SRC.keywords_from_url( a.value )
  from
    SRC._bookmarks_050_split_values as a,
    lateral (
      select
          v[ 1 ] as keytype,
          v[ 2 ] as keyword
        from U.unnest_2d_1d( U.parse_url_words( a.value ) ) as v ) as w
  where a.key = 'url' ); */

-- \quit

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(11)=--':O
create table SRC._bookmarks_080_complement_missing as ( with v1 as ( select
    linenr,
    star,
    level,
    key,
    value,
    ac,
    facets
  from SRC._bookmarks_070 )
select * from v1
union select
    linenr      as linenr,
    star        as star,
    level       as level,
    key         as key,
    value       as value,
    null        as ac,
    null        as facets
  from SRC._bookmarks_050_split_values
    /* Choose the more efficient one: */
    where not linenr = any ( select linenr from v1 )
    -- where linenr not in ( select linenr from v1 )
);

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(12)=--':O
create view SRC.bookmarks as ( select * from SRC._bookmarks_080_complement_missing order by linenr );


/* ###################################################################################################### */



select
    null::integer   as linenr,
    null::text      as value,
    null::text      as keytype,
    null::text      as keyword
  where false union
select linenr, value, 'tag/context',  unnest( U.text_array_from_json( facets->'tag/context' ) ) from SRC.bookmarks where ( facets->'tag/context' ) != 'null'::jsonb union
select linenr, value, 'tag/key',      unnest( array( select           facets->>'tag/key'    ) ) from SRC.bookmarks where ( facets->'tag/key'     ) != 'null'::jsonb union
select linenr, value, 'tag/value',    unnest( array( select           facets->>'tag/value'  ) ) from SRC.bookmarks where ( facets->'tag/value'   ) != 'null'::jsonb union
select linenr, value, 'tag/type',     unnest( array( select           facets->>'tag/type'   ) ) from SRC.bookmarks where ( facets->'tag/type'    ) != 'null'::jsonb union
select null, null, null, null where false
order by
  -- linenr,
  keytype,
  keyword,
  1
  ;

-- select * from FM.results;
\set ECHO queries
select * from SRC._bookmarks_060;
select * from SRC._bookmarks_070;
select * from SRC._bookmarks_075_urls;
select * from SRC._bookmarks_050_split_values;
select * from SRC._bookmarks_080_complement_missing;
select * from SRC.bookmarks;
\set ECHO none
\quit




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
-- \timing on


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
create function SRC.jsonb_object_as_text_facets( ¶x jsonb ) returns text[]
  /* ```
  select _X_.jsonb_object_as_text_facets( '{"a":"yes","b":42,"c":["foo","bar","baz"]}'::jsonb );
  # {yes,42,foo,bar,baz}
  ``` */
  immutable strict language plpgsql as $$
  declare
    ¶key      text;
    ¶value    jsonb;
    ¶element  text;
    R         text[];
  begin
    for ¶key, ¶value in select key, value from jsonb_each( ¶x ) loop
      -- ### TAINT special-case objects, too
      if jsonb_typeof( ¶value ) = 'array' then
        for ¶element in select value from jsonb_array_elements_text( ¶value ) loop
          R := R || array[ array[ ¶key, ¶element ] ];
          end loop;
      else
        R := R || array[ array[ ¶key, ( ¶x->>¶key ) ] ];
        end if;
      end loop;
    return R; end; $$;

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
    case when line ~ '^\*' then 'entry'::text else '...' end    as star,
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
    -- case when star = 'entry' then 1 else
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
create view SRC._bookmarks_099 as ( select * from SRC._bookmarks_040_split_fields );

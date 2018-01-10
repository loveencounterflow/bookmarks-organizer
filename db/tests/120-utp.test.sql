
/* ###################################################################################################### */
\ir './start.test.sql'
\ir '../120-utp.sql'
\timing off

/* ====================================================================================================== */
begin;
-- select plan( 10 );
-- select * from no_plan();
-- \pset format aligned
-- \pset tuples_only false

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists T cascade;
create schema T;

-- ---------------------------------------------------------------------------------------------------------
-- select tables_are( 'utp', array[ 'patterns' ] );
with v1 as ( select table_name::text
  from information_schema.tables
  where table_schema = 'utp'
  order by table_name asc )
select array_agg( table_name::text ) from v1;

-- ---------------------------------------------------------------------------------------------------------
create table T.probes_and_matchers ( function_name text not null, probe text, matcher text[] );
insert into T.probes_and_matchers values
  -- ( 'UTP.lex_camel',  null,                       null                              ),
  ( 'UTP.lex_camel',  'ABCWordDEF',               '{ABC,Word,DEF}'                  ),
  ( 'UTP.lex_camel',  'CamelCaseXYZ',             '{Camel,Case,XYZ}'                ),
  ( 'UTP.lex_camel',  'INITIAL',                  '{INITIAL}'                       ),
  ( 'UTP.lex_camel',  'Initial',                  '{Initial}'                       ),
  ( 'UTP.lex_camel',  'LearnWCFInSixEasyMonths',  '{Learn,WCF,In,Six,Easy,Months}'  ),
  ( 'UTP.lex_camel',  'dromedaryCase',            '{dromedary,Case}'                ),
  ( 'UTP.lex_camel',  'lower',                    '{lower}'                         ),
  ( 'UTP.lex_camel',  'réSumé',                   '{ré,Sumé}'                       ),
  ( 'UTP.lex_camel',  'résumé**',                   '{résumé}'                        ),
  -- .......................................................................................................
  -- ( 'UTP.split_url_phrase', null,                                                         null          ),
  ( 'UTP.split_url_phrase', '(bracketed)',                                                '{bracketed}' ),
  ( 'UTP.split_url_phrase', '...yeah',                                                    '{yeah}' ),
  ( 'UTP.split_url_phrase', 'foo(bracketed)bar',                                          '{foo,bracketed,bar}' ),
  ( 'UTP.split_url_phrase', 'foo/bar',                                                    '{foo,bar}' ),
  ( 'UTP.split_url_phrase', 'http://foo.com/a-new-way/of-thinking',                       '{http,foo,com,a,new,way,of,thinking}' ),
  ( 'UTP.split_url_phrase', 'http://foo.com/汉字编码的理论与实践/学林出版社1986年8月',    '{http,foo,com,汉字编码的理论与实践,学林出版社1986年8月}' ),
  ( 'UTP.split_url_phrase', 'this-that',                                                  '{this,that}' ),
  ( 'UTP.split_url_phrase', 'this_(that)',                                                '{this,that}' ),
  ( 'UTP.split_url_phrase', 'this_that',                                                  '{this,that}' );

-- -- ---------------------------------------------------------------------------------------------------------
-- create materialized view T.test_lex_camel as (
--   with v1 as ( select
--       probe,
--       UTP.lex_camel( probe ) as result,
--       matcher
--     from T.probes_and_matchers
--     order by probe )
--   select probe, result, result is not distinct from matcher as ok from v1 );

-- -- ---------------------------------------------------------------------------------------------------------
-- create materialized view T.test_split_url_phrase as (
--   with v1 as ( select
--       probe,
--       UTP.split_url_phrase( probe ) as result,
--       matcher
--     from T.split_url_phrase_probes_and_matchers
--     order by probe )
--   select probe, result, result is not distinct from matcher as ok from v1 );

create table T._probes_matchers_and_results (
  function_name text not null,
  probe         text,
  result_txt    text not null,
  ok            boolean not null
  );



-- ---------------------------------------------------------------------------------------------------------
create function T._is_distinct_from( anyelement, anyelement ) returns boolean immutable language sql as $$
  select $1 is distinct from $2; $$;

-- ---------------------------------------------------------------------------------------------------------
create function T._is_distinct_from( anyarray, anyarray ) returns boolean immutable language sql as $$
  select $1 is distinct from $2; $$;

-- ---------------------------------------------------------------------------------------------------------
create function T.test_functions( ¶pam_table_name text )
  -- returns setof T._probes_matchers_and_results
  -- returns text[]
  returns table (
    ¶function_name  text,
    ¶probe_txt      text,
    ¶result_txt     text,
    ¶ok             boolean )
  volatile language plpgsql as $outer$
  declare
    ¶probe          text;
    ¶x              record;
    ¶result         record;
    ¶Q              text;
  --   ¶result anyelement;
  begin
    for ¶x in execute $$ select function_name, probe, matcher from $$||¶pam_table_name loop
      ¶function_name  := ¶x.function_name;
      ¶probe          := ¶x.probe;
      ¶probe_txt      := quote_literal( ¶x.probe );
      ¶Q              := $$ select * from $$||¶function_name||$$( $$||quote_literal( ¶x.probe )||$$ ) as d $$;
      perform log( '>>>', ¶Q );
      execute ¶Q  into ¶result;
      perform log( '>>>', pg_typeof( ¶result )::text );
      perform log( '>>>', ¶result::text );
      select  into ¶result_txt  quote_literal( ¶result.d );
      select  into ¶ok  ¶result.d is not distinct from ¶x.matcher;
      -- ¶ok := T._is_distinct_from( ¶result, ¶x.matcher );
      -- select quote_literal( result ) into ¶result_txt;
      return next;
      end loop;
  end; $outer$;

        -- -- ¶ok             := T._is_distinct_from( x.matcher, ¶result );
        -- with v1 as ( select
        --     probe,
        --     UTP.split_url_phrase( probe ) as result,
        --     matcher
        --   from T.split_url_phrase_probes_and_matchers
        --   order by function_name, probe )
        -- select probe, result, result is not distinct from matcher as ok from v1;

-- -- ---------------------------------------------------------------------------------------------------------
-- create function T.test_functions( ¶pam_table_name text )
--   -- returns setof T._probes_matchers_and_results
--   -- returns text[]
--   returns table (
--     function_name text not null,
--     probe         text,
--     result_txt    text not null,
--     ok            boolean not null )
--   volatile language plpgsql as $outer$
--   declare
--     ¶function_names text[];
--   begin
--     execute $$
--       select array_agg( function_name )
--         from ( select distinct function_name from $$||¶pam_table_name||$$ ) as d; $$
--         into ¶function_names;
--     with v1 as ( select unnest ¶function_names as function_name )
--     execute $$ select
--     for ¶function_name in ¶function_names array loop
--       end loop;
--     return query execute $$
--       with v1 as ( select
--           probe,
--           UTP.split_url_phrase( probe ) as result,
--           matcher
--         from T.split_url_phrase_probes_and_matchers
--         order by function_name, probe )
--       select probe, result, result is not distinct from matcher as ok from v1;
--       $$;
--   end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
select * from T.test_functions( 'T.probes_and_matchers' );
\quit

-- ---------------------------------------------------------------------------------------------------------
select '( ' || quote_literal( probe ) || ', ' || quote_literal( result ) || ' ),' from T.test_split_url_phrase;


/* ====================================================================================================== */
create materialized view T.all_result_counts as (
  select null::text as test, null::text as category, null::integer as count where false union all
  -- .........................................................................................................
  select 'test_lex_camel', 'total',   count( * ) from T.test_lex_camel                        union all
  select 'test_lex_camel', 'passed',  count( * ) from T.test_lex_camel where      ok          union all
  select 'test_lex_camel', 'failed',  count( * ) from T.test_lex_camel where not  ok          union all
  -- .........................................................................................................
  select 'test_split_url_phrase', 'total',   count( * ) from T.test_split_url_phrase                        union all
  select 'test_split_url_phrase', 'passed',  count( * ) from T.test_split_url_phrase where      ok          union all
  select 'test_split_url_phrase', 'failed',  count( * ) from T.test_split_url_phrase where not  ok          union all
  -- .........................................................................................................
  select null, null, null where false );

-- ---------------------------------------------------------------------------------------------------------
select * from T.all_result_counts;

-- ---------------------------------------------------------------------------------------------------------
with v1 as ( select distinct
    category,
    sum( count ) over ( partition by category ) as sum
    from T.all_result_counts )
select
    array_position( array[ 'total', 'passed', 'failed' ], category ) as n,
    category,
    sum
  from v1
    order by n
    ;


/* ###################################################################################################### */

rollback;
\ir './stop.test.sql'
\quit



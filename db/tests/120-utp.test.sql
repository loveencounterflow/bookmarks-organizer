
/* ###################################################################################################### */
\ir './start.test.sql'
\ir '../120-utp.sql'
\timing off

/* ====================================================================================================== */
begin;

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
  ( 'UTP.lex_camel',  null,                       null                              ),
  ( 'UTP.lex_camel',  'ABCWordDEF',               '{ABC,Word,DEF}'                  ),
  ( 'UTP.lex_camel',  'CamelCaseXYZ',             '{Camel,Case,XYZ}'                ),
  ( 'UTP.lex_camel',  'INITIAL',                  '{INITIAL}'                       ),
  ( 'UTP.lex_camel',  'Initial',                  '{Initial}'                       ),
  ( 'UTP.lex_camel',  'LearnWCFInSixEasyMonths',  '{Learn,WCF,In,Six,Easy,Months}'  ),
  ( 'UTP.lex_camel',  'dromedaryCase',            '{dromedary,Case}'                ),
  ( 'UTP.lex_camel',  'lower',                    '{lower}'                         ),
  ( 'UTP.lex_camel',  'réSumé',                   '{ré,Sumé}'                       ),
  ( 'UTP.lex_camel',  'résumé',                   '{résumé}'                        ),
  -- .......................................................................................................
  ( 'UTP.split_url_phrase', null,                                                         null          ),
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
-- create function T._is_distinct_from( anyelement, anyelement ) returns boolean immutable language sql as $$
--   select $1 is distinct from $2; $$;

-- -- ---------------------------------------------------------------------------------------------------------
-- create function T._is_distinct_from( anyarray, anyarray ) returns boolean immutable language sql as $$
--   select $1 is distinct from $2; $$;

-- ---------------------------------------------------------------------------------------------------------
create function T.test_functions( ¶pam_table_name regclass )
  returns table (
    function_name_txt text,
    probe_txt         text,
    result_txt        text,
    ok                boolean )
  volatile language plpgsql as $outer$
  declare
    ¶function_name  text;
    ¶probe          text;
    ¶x              record;
    ¶result         record;
    ¶Q1             text;
    ¶Q2             text;
  begin
    ¶Q1 := format( $$ select function_name, probe, matcher from %s $$, ¶pam_table_name );
    for ¶x in execute ¶Q1 loop
      ¶function_name    :=  ¶x.function_name;
      function_name_txt :=  quote_literal( ¶function_name );
      ¶probe            :=  ¶x.probe;
      probe_txt         :=  quote_nullable( ¶x.probe );
      ¶Q2               :=  $$ select * from $$||¶function_name||$$( $$||quote_nullable( ¶x.probe )||$$ ) as d $$;
      execute ¶Q2 into ¶result;
      select      into result_txt  quote_nullable( ¶result.d );
      select      into ok          ¶result.d is not distinct from ¶x.matcher;
      if not ok then
        perform log( '10091', probe_txt, result_txt );
        end if;
      return next;
      end loop;
  end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create materialized view T.test_functions_results as (
  select * from T.test_functions( 'T.probes_and_matchers' ) );

-- ---------------------------------------------------------------------------------------------------------
select
    function_name_txt,
    probe_txt,
    result_txt,
    case when ok then '' else '!!!' end as ok
  from T.test_functions_results;

-- ---------------------------------------------------------------------------------------------------------
create materialized view T.all_result_counts as (
  select null::text as category, null::integer as count where false union all
  -- .........................................................................................................
  select 'total',   count(*) from T.test_functions_results                union all
  select 'passed',  count(*) from T.test_functions_results where      ok  union all
  select 'failed',  count(*) from T.test_functions_results where  not ok  union all
  -- .........................................................................................................
  select null, null where false );

-- ---------------------------------------------------------------------------------------------------------
select * from T.all_result_counts;


/* ====================================================================================================== */
rollback;
\ir './stop.test.sql'
\quit



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

  -- -- .........................................................................................................
  -- select 'test_lex_camel', 'total',   count( * ) from T.test_lex_camel                        union all
  -- select 'test_lex_camel', 'passed',  count( * ) from T.test_lex_camel where      ok          union all
  -- select 'test_lex_camel', 'failed',  count( * ) from T.test_lex_camel where not  ok          union all
  -- -- .........................................................................................................
  -- select 'test_split_url_phrase', 'total',   count( * ) from T.test_split_url_phrase                        union all
  -- select 'test_split_url_phrase', 'passed',  count( * ) from T.test_split_url_phrase where      ok          union all
  -- select 'test_split_url_phrase', 'failed',  count( * ) from T.test_split_url_phrase where not  ok          union all

-- select
--     '( ' || function_name_txt || ', ' || probe_txt || ', ' || result_txt || ' ),'
--   from T.test_functions_results;


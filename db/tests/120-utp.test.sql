
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
create table T.lex_camel_probes_and_matchers ( probe text not null, matcher text[] );
insert into T.lex_camel_probes_and_matchers values
  ( 'ABCWordDEF',              '{ABC,Word,DEF}'                 ),
  ( 'CamelCaseXYZ',            '{Camel,Case,XYZ}'               ),
  ( 'INITIAL',                 '{INITIAL}'                      ),
  ( 'Initial',                 '{Initial}'                      ),
  ( 'LearnWCFInSixEasyMonths', '{Learn,WCF,In,Six,Easy,Months}' ),
  ( 'dromedaryCase',           '{dromedary,Case}'               ),
  ( 'lower',                   '{lower}'                        ),
  ( 'réSumé',                  '{ré,Sumé}'                      ),
  ( 'résumé**',                  '{résumé}'                       );

-- ---------------------------------------------------------------------------------------------------------
create table T.split_url_phrase_probes_and_matchers ( probe text not null, matcher text[] );
insert into T.split_url_phrase_probes_and_matchers values
  ( '(bracketed)', '{bracketed}' ),
  ( '...yeah', '{yeah}' ),
  ( 'foo(bracketed)bar', '{foo,bracketed,bar}' ),
  ( 'foo/bar', '{foo,bar}' ),
  ( 'http://foo.com/a-new-way/of-thinking', '{http,foo,com,a,new,way,of,thinking}' ),
  ( 'http://foo.com/汉字编码的理论与实践/学林出版社1986年8月', '{http,foo,com,汉字编码的理论与实践,学林出版社1986年8月}' ),
  ( 'this-that', '{this,that}' ),
  ( 'this_(that)', '{this,that}' ),
  ( 'this_that', '{this,that}' );

-- ---------------------------------------------------------------------------------------------------------
create materialized view T.test_lex_camel as (
  with v1 as ( select
      probe,
      UTP.lex_camel( probe ) as result,
      matcher
    from T.lex_camel_probes_and_matchers
    order by probe )
  select probe, result, result = matcher as ok from v1 );

-- ---------------------------------------------------------------------------------------------------------
create materialized view T.test_split_url_phrase as (
  with v1 as ( select
      probe,
      UTP.split_url_phrase( probe ) as result,
      matcher
    from T.split_url_phrase_probes_and_matchers
    order by probe )
  select probe, result, result = matcher as ok from v1 );

-- ---------------------------------------------------------------------------------------------------------
select '( ' || quote_literal( probe ) || ', ' || quote_literal( result ) || ' ),' from T.test_split_url_phrase;


/* ====================================================================================================== */
create materialized view T.all_result_counts as (
  select null::text as test, null::text as category, null::integer as count where false union all
  -- .........................................................................................................
  select 'test_lex_camel', 'total',   count( * ) from T.test_lex_camel                        union all
  select 'test_lex_camel', 'passed',  count( * ) from T.test_lex_camel where      ok          union all
  select 'test_lex_camel', 'failed',  count( * ) from T.test_lex_camel where not  ok          union all
  select 'test_lex_camel', 'null',    count( * ) from T.test_lex_camel where      ok is null  union all
  -- .........................................................................................................
  select 'test_split_url_phrase', 'total',   count( * ) from T.test_split_url_phrase                        union all
  select 'test_split_url_phrase', 'passed',  count( * ) from T.test_split_url_phrase where      ok          union all
  select 'test_split_url_phrase', 'failed',  count( * ) from T.test_split_url_phrase where not  ok          union all
  select 'test_split_url_phrase', 'null',    count( * ) from T.test_split_url_phrase where      ok is null  union all
  -- .........................................................................................................
  select null, null, null where false );

select * from T.all_result_counts;

select distinct category, sum( count ) over ( partition by category ) as sum from T.all_result_counts;


/* ###################################################################################################### */

rollback;
\ir './stop.test.sql'
\quit



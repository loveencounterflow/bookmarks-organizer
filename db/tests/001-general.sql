


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
set role dba;
create function T."Python function returning 1d text array"() returns text[] immutable
  language plpython3u as $$
  return [ 'helo', 'world', ]
  $$;

-- ---------------------------------------------------------------------------------------------------------
create table T.probes_and_matchers ( probe text, matcher text[] );
insert into T.probes_and_matchers values
  ( 'select T."Python function returning 1d text array"() as d', null );

-- ---------------------------------------------------------------------------------------------------------
create function T.test()
  returns table (
    probe_q           text,
    result_q          text,
    ok                boolean )
  volatile language plpgsql as $outer$
  declare
    ¶row            record;
    ¶result         record;
    ¶result_q       text;
  begin
    -- .....................................................................................................
    for ¶row in ( select probe, matcher from T.probes_and_matchers ) loop
      execute ¶row.probe                                  into ¶result;
      perform log( '33391', ¶result::text );
      select  quote_nullable( ¶row.probe )                into probe_q;
      select  quote_nullable( ¶result.d )                 into result_q;
      select  ¶result.d is not distinct from ¶row.matcher into ok;
      -- ...................................................................................................
      if not ok then
        perform log( '10091', probe_q, result_q );
        end if;
      return next;
      end loop;
    -- .....................................................................................................
    end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create materialized view T.test_functions_results as (
  select * from T.test() );

-- ---------------------------------------------------------------------------------------------------------
select
    probe_q,
    result_q,
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





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
create table T.probes_and_matchers ( function_name NAMEOF.function not null, probe text, matcher text[] );
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
  ( 'UTP.split_url_phrase', 'this_that',                                                  '{this,that}' ),
  -- .......................................................................................................
  ( 'UTP.lex_tags', null,                                                         null          ),
  ( 'UTP.lex_tags', $$tag$$,                                                        '{tag}'               ),
  ( 'UTP.lex_tags', $$name=tag$$,                                                   '{name,=,tag}'        ),
  ( 'UTP.lex_tags', 'tag foo ''bar'' "baz" ''gnu x'' "moo y"'                   , '{tag," ",foo," ",bar," ",baz," ","gnu x"," ","moo y"}'                               ),
  ( 'UTP.lex_tags', 'tag=''value with spaces 1'''                               , '{tag,=,"value with spaces 1"}'                                                       ),
  ( 'UTP.lex_tags', 'tag="value with spaces 2"'                                 , '{tag,=,"value with spaces 2"}'                                                       ),
  ( 'UTP.lex_tags', 'tag="value with spaces and \"quotes\" 2"'                  , '{tag,=,"value with spaces and \"quotes\" 2"}'                     ),
  ( 'UTP.lex_tags', 'q=tag q=foo q=''bar'' q="baz" q=''gnu x'' q="moo y"'       , '{q,=,tag," ",q,=,foo," ",q,=,bar," ",q,=,baz," ",q,=,"gnu x"," ",q,=,"moo y"}'       ),
  ( 'UTP.lex_tags', 'tag::q foo::q ''bar''::q "baz"::q ''gnu x''::q "moo y"::q' , '{tag,::,q," ",foo,::,q," ",bar,::,q," ",baz,::,q," ","gnu x",::,q," ","moo y",::,q}' ),
  ( 'UTP.lex_tags', 'programming/languages/sql'                                 , '{programming,/,languages,/,sql}'                                                     ),
  ( 'UTP.lex_tags', 'ctx/tag'                                                   , '{ctx,/,tag}'                                                                         ),
  ( 'UTP.lex_tags', 'tag=value'                                                 , '{tag,=,value}'                                                                       ),
  ( 'UTP.lex_tags', 'ctx/tag=''value with spaces 1'''                           , '{ctx,/,tag,=,"value with spaces 1"}'                                                 ),
  ( 'UTP.lex_tags', 'ctx/tag="value with spaces 2"'                             , '{ctx,/,tag,=,"value with spaces 2"}'                                                 ),
  ( 'UTP.lex_tags', '"Gun, Son of A." ::name'                                   , '{"Gun, Son of A."," ",::,name}'                                                      ),
  ( 'UTP.lex_tags', '"Gun, Son of A."::name'                                    , '{"Gun, Son of A.",::,name}'                                                          ),
  ( 'UTP.lex_tags', '"Gun, Son of A.::name"'                                    , '{"Gun, Son of A.::name"}'                                                            ),
  ( 'UTP.lex_tags', 'name="Gun, Son of A." ''another tag'''                     , '{name,=,"Gun, Son of A."," ","another tag"}'                                         ),
  ( 'UTP.lex_tags', '''tag with spaces'''                                       , '{"tag with spaces"}'                                                                 ),
  ( 'UTP.lex_tags', 'tag foo ''bar baz'''                                       , '{tag," ",foo," ","bar baz"}'                                                         ),
  ( 'UTP.lex_tags', 'tag foo "bar baz"'                                         , '{tag," ",foo," ","bar baz"}'                                                         ),
  ( 'UTP.lex_tags', 'IT/programming/language=SQL::name'                         , '{IT,/,programming,/,language,=,SQL,::,name}'                                                         ),
  ( 'UTP.lex_tags', 'IT/programming/language'                                   , '{IT,/,programming,/,language}'                                                         ),
  ( 'UTP.lex_tags', 'tag ''foo "bar baz" gnu'''                                 , E'{tag," ","foo \\"bar baz\\" gnu"}'                                                  ),
  ( 'UTP.lex_tags', 'tag'                                                       , '{tag}'                                                                               );

  -- ( 'tag' '{{identifier,tag}}' ),
  -- ( 'name=tag' '{{identifier,name},{equals,=},{identifier,tag}}' ),
  -- ( 'tag foo ''bar'' "baz" ''gnu x'' "moo y"' '{{identifier,tag},{blank," "},{identifier,foo},{blank," "},{identifier,bar},{blank," "},{identifier,baz},{blank," "},{identifier,"gnu x"},{blank," "},{identifier,"moo y"}}' ),
  -- ( 'tag=''value with spaces 1''' '{{identifier,tag},{equals,=},{identifier,"value with spaces 1"}}' ),
  -- ( 'tag="value with spaces 2"' '{{identifier,tag},{equals,=},{identifier,"value with spaces 2"}}' ),
  -- ( E'tag="value with spaces and \\"quotes\\" 2"' E'{{identifier,tag},{equals,=},{identifier,"value with spaces and \\"quotes\\" 2"}}' ),
  -- ( 'q=tag q=foo q=''bar'' q="baz" q=''gnu x'' q="moo y"' '{{identifier,q},{equals,=},{identifier,tag},{blank," "},{identifier,q},{equals,=},{identifier,foo},{blank," "},{identifier,q},{equals,=},{identifier,bar},{blank," "},{identifier,q},{equals,=},{identifier,baz},{blank," "},{identifier,q},{equals,=},{identifier,"gnu x"},{blank," "},{identifier,q},{equals,=},{identifier,"moo y"}}' ),
  -- ( 'tag::q foo::q ''bar''::q "baz"::q ''gnu x''::q "moo y"::q' '{{identifier,tag},{dcolon,::},{identifier,q},{blank," "},{identifier,foo},{dcolon,::},{identifier,q},{blank," "},{identifier,bar},{dcolon,::},{identifier,q},{blank," "},{identifier,baz},{dcolon,::},{identifier,q},{blank," "},{identifier,"gnu x"},{dcolon,::},{identifier,q},{blank," "},{identifier,"moo y"},{dcolon,::},{identifier,q}}' ),
  -- ( 'programming/languages/sql' '{{identifier,programming},{slash,/},{identifier,languages},{slash,/},{identifier,sql}}' ),
  -- ( 'ctx/tag' '{{identifier,ctx},{slash,/},{identifier,tag}}' ),
  -- ( 'tag=value' '{{identifier,tag},{equals,=},{identifier,value}}' ),
  -- ( 'ctx/tag=''value with spaces 1''' '{{identifier,ctx},{slash,/},{identifier,tag},{equals,=},{identifier,"value with spaces 1"}}' ),
  -- ( 'ctx/tag="value with spaces 2"' '{{identifier,ctx},{slash,/},{identifier,tag},{equals,=},{identifier,"value with spaces 2"}}' ),
  -- ( '"Gun, Son of A." ::name' '{{identifier,"Gun, Son of A."},{blank," "},{dcolon,::},{identifier,name}}' ),
  -- ( '"Gun, Son of A."::name' '{{identifier,"Gun, Son of A."},{dcolon,::},{identifier,name}}' ),
  -- ( '"Gun, Son of A.::name"' '{{identifier,"Gun, Son of A.::name"}}' ),
  -- ( 'name="Gun, Son of A." ''another tag''' '{{identifier,name},{equals,=},{identifier,"Gun, Son of A."},{blank," "},{identifier,"another tag"}}' ),
  -- ( '''tag with spaces''' '{{identifier,"tag with spaces"}}' ),
  -- ( 'tag foo ''bar baz''' '{{identifier,tag},{blank," "},{identifier,foo},{blank," "},{identifier,"bar baz"}}' ),
  -- ( 'tag foo "bar baz"' '{{identifier,tag},{blank," "},{identifier,foo},{blank," "},{identifier,"bar baz"}}' ),
  -- ( 'IT/programming/language=SQL::name' '{{identifier,IT},{slash,/},{identifier,programming},{slash,/},{identifier,language},{equals,=},{identifier,SQL},{dcolon,::},{identifier,name}}' ),
  -- ( 'IT/programming/language' '{{identifier,IT},{slash,/},{identifier,programming},{slash,/},{identifier,language}}' ),
  -- ( 'tag ''foo "bar baz" gnu''' E'{{identifier,tag},{blank," "},{identifier,"foo \\"bar baz\\" gnu"}}' ),
  -- ( 'tag' '{{identifier,tag}}' ),

-- ---------------------------------------------------------------------------------------------------------
/* thx to https://stackoverflow.com/a/10711349/7568091 for using `regclass` and `format( '...%s...' )` */
create function T.test_functions( ¶pm_table_name NAMEOF.relation )
  returns table (
    function_name_q   text,
    probe_q           text,
    result_q          text,
    ok                boolean )
  volatile language plpgsql as $outer$
  declare
    ¶x              record;
    ¶result         record;
    ¶Q1             text;
    ¶Q2             text;
  begin
    ¶Q1 := format( $$ select function_name::NAMEOF.function, probe, matcher from %s $$, ¶pm_table_name );
    -- .....................................................................................................
    for ¶x in execute ¶Q1 loop
      function_name_q   :=  quote_literal( ¶x.function_name );
      probe_q           :=  quote_nullable( ¶x.probe );
      ¶Q2               :=  format( $$ select * from %s( $1 ) as d $$, ¶x.function_name );
      -- ...................................................................................................
      execute ¶Q2 using ¶x.probe                          into ¶result;
      select  quote_nullable( ¶result.d )                 into result_q;
      select  ¶result.d is not distinct from ¶x.matcher   into ok;
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
  select * from T.test_functions( 'T.probes_and_matchers' ) );

-- ---------------------------------------------------------------------------------------------------------
select
    function_name_q,
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


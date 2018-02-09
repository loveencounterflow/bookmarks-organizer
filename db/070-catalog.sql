

/*

 .d8888b.        d8888 88888888888    d8888  888      .d88888b.   .d8888b.
d88P  Y88b      d88888     888       d88888  888     d88P" "Y88b d88P  Y88b
888    888     d88P888     888      d88P888  888     888     888 888    888
888           d88P 888     888     d88P 888  888     888     888 888
888          d88P  888     888    d88P  888  888     888     888 888  88888
888    888  d88P   888     888   d88P   888  888     888     888 888    888
Y88b  d88P d8888888888     888  d8888888888  888     Y88b. .d88P Y88b  d88P
 "Y8888P" d88P     888     888 d88P     888  88888888 "Y88888P"   "Y8888P88

*/


-- ---------------------------------------------------------------------------------------------------------
drop schema if exists CATALOG cascade;
create schema CATALOG;

-- ---------------------------------------------------------------------------------------------------------
create function CATALOG.count_tuples( schema text, name text )
  returns integer
  language plpgsql
  as $$
    declare
      R integer;
    begin
      if schema || '.' || name in
        ( 'catalog.catalog', 'catalog._tables_and_views', 'catalog._materialized_views' ) then
        raise exception using message = 'Recursion not allowed for schema "catalog"', errcode = '42P19';
        return -2;
        end if;
      execute 'select count(*) from ' || schema || '.' || name
         into R;
      return R;
    end;
  $$;

-- ---------------------------------------------------------------------------------------------------------
create function CATALOG.count_tuples_dsp( schema text, name text )
  returns text
  language plpgsql
  as $$
    declare
      R integer;
    begin
      select CATALOG.count_tuples( schema, name ) into R;
      return to_char( R, '9,999,999' );
      exception
        when invalid_recursion then -- 38000
          return '(recursive)';
        when external_routine_exception then -- 38000
          return '(error)';
        when object_not_in_prerequisite_state then -- sqlstate = 55000
          return '(not ready)';
        when others then
          raise notice 'error while retrieving %.%: (%) %', schema, name, sqlstate, sqlerrm;
          -- raise exception 'error while retrieving %.%: (%) %', schema, name, sqlstate, sqlerrm;
          return '(???)';
    end;
  $$;


-- =========================================================================================================
-- VERSIONS
-- ---------------------------------------------------------------------------------------------------------
-- drop table if exists CATALOG.versions cascade;
create table CATALOG.versions (
  key           text primary key,
  version       text );

-- ---------------------------------------------------------------------------------------------------------
create function CATALOG.upsert_versions( ¶key text, ¶version text ) returns void
  language plpgsql volatile as $$
    begin
      insert into CATALOG.versions ( key, version ) values ( ¶key, ¶version )
        on conflict ( key ) do update set version = ¶version;
      end; $$;

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT these values should in the future be read from options, package.json etc ### */
insert into CATALOG.versions values
  ( 'server', '3.0.3' ),
  ( 'api',    '2' );

-- do $$ begin perform CATALOG.upsert_versions( 'sthelse', '3.141' ); end; $$;
-- do $$ begin perform CATALOG.upsert_versions( 'api',     '3'     ); end; $$;

-- select * from CATALOG.versions;
-- \quit

-- =========================================================================================================
--
-- ---------------------------------------------------------------------------------------------------------
/* thx to http://stackoverflow.com/a/16632213 */
create view CATALOG._functions_with_defs_all as (
  select
      -- pp.*,
      pl.lanname                    as language_name,
      pn.nspname                    as schema_name,
      pp.proname                    as function_name,
      pp.proargnames                as parameters,
      pg_get_functiondef( pp.oid )  as def
  from pg_proc as pp
  inner join pg_namespace pn on ( pp.pronamespace = pn.oid )
  inner join pg_language  pl on ( pp.prolang      = pl.oid )
  );

-- ---------------------------------------------------------------------------------------------------------
create view CATALOG._functions_all as (
  select
      'f   '::text                              as t,
      schema_name                               as schema,
      function_name                             as name,
      language_name || '; ' || parameters::text as remarks
    from
      CATALOG._functions_with_defs_all
  );

-- ---------------------------------------------------------------------------------------------------------
create view CATALOG._functions as (
  select
      t                 as t,
      schema            as schema,
      name              as name,
      null::text        as size,
      remarks           as remarks
    from
      CATALOG._functions_all
  where true
    and schema not in ( 'information_schema' )
    and schema !~ '^pg_'
    and schema !~ '^_'
  );

-- ---------------------------------------------------------------------------------------------------------
create function CATALOG._get_table_remarks( insertable text, typed text )
returns text
language sql
as $$
  with v1 as (
    select
      case insertable when 'YES' then 'insertable'  else null end as insertable,
      case typed      when 'YES' then 'typed'       else null end as typed )
  select array_to_string( array[ insertable, typed ], ', ' ) from v1;
  $$;

-- ---------------------------------------------------------------------------------------------------------
create view CATALOG._tables_and_views_all as (
  select
    case table_type when 'BASE TABLE' then 'rt' when 'VIEW' then 'rvo' else table_type end as t,
    table_schema  as schema,
    table_name    as name,
    CATALOG._get_table_remarks( is_insertable_into, is_typed ) as remarks
    -- case is_insertable_into when 'YES' then 'Y' else '' end as insertable,
    -- case is_typed           when 'YES' then 'Y' else '' end as typed
  from information_schema.tables
  );

-- ---------------------------------------------------------------------------------------------------------
create view CATALOG._tables_and_views as (
  select
      t,
      schema,
      name,
      CATALOG.count_tuples_dsp( schema, name ) as size,
      remarks
    from CATALOG._tables_and_views_all
    where true
      -- and t = 'rt'
      and schema not in (
        'pg_toast',
        'pg_catalog',
        'information_schema' )
  );

-- ---------------------------------------------------------------------------------------------------------
create view CATALOG._materialized_views as (
  with v1 as (
    select
        'rvm'::text                       as t,
        schemaname                        as schema,
        matviewname                       as name,
        ''::text                          as remarks
      from pg_matviews
    )
    select
        t,
        schema,
        name,
        CATALOG.count_tuples_dsp( schema, name ) as size,
        remarks
      from v1
    );

-- ---------------------------------------------------------------------------------------------------------
create view CATALOG.catalog as (
  with v1 as (
              select * from CATALOG._tables_and_views
    union all select * from CATALOG._materialized_views
    union all select * from CATALOG._functions
    )
    select * from v1 order by t, schema, name
  );



-- ---------------------------------------------------------------------------------------------------------
drop schema if exists report cascade;
create schema report;

/* # ## # ### # ## # ### # ## # ### # ## # ### # ## # ### # ## # ### # ## # ### # ## # ### # ## # ### ##  */
/* # ## # ### # ## # ### # ## # ### # ## # ### # ## # ### # ## # ### # ## # ### # ## # ### # ## # ### ##  */
/* # ## # ### # ## # ### # ## # ### # ## # ### # ## # ### # ## # ### # ## # ### # ## # ### # ## # ### ##  */
/* thx to https://stackoverflow.com/a/46594226/7568091 */

WITH RECURSIVE view_deps AS (
SELECT DISTINCT dependent_ns.nspname as dependent_schema
, dependent_view.relname as dependent_view
, source_ns.nspname as source_schema
, source_table.relname as source_table
FROM pg_depend
JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
JOIN pg_class as dependent_view ON pg_rewrite.ev_class = dependent_view.oid
JOIN pg_class as source_table ON pg_depend.refobjid = source_table.oid
JOIN pg_namespace dependent_ns ON dependent_ns.oid = dependent_view.relnamespace
JOIN pg_namespace source_ns ON source_ns.oid = source_table.relnamespace
WHERE NOT (dependent_ns.nspname = source_ns.nspname AND dependent_view.relname = source_table.relname)
UNION
SELECT DISTINCT dependent_ns.nspname as dependent_schema
, dependent_view.relname as dependent_view
, source_ns.nspname as source_schema
, source_table.relname as source_table
FROM pg_depend
JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
JOIN pg_class as dependent_view ON pg_rewrite.ev_class = dependent_view.oid
JOIN pg_class as source_table ON pg_depend.refobjid = source_table.oid
JOIN pg_namespace dependent_ns ON dependent_ns.oid = dependent_view.relnamespace
JOIN pg_namespace source_ns ON source_ns.oid = source_table.relnamespace
INNER JOIN view_deps vd
    ON vd.dependent_schema = source_ns.nspname
    AND vd.dependent_view = source_table.relname
    AND NOT (dependent_ns.nspname = vd.dependent_schema AND dependent_view.relname = vd.dependent_view)
)

SELECT *
FROM view_deps
where true
  and ( dependent_schema not in ( 'information_schema', 'pg_catalog' ) )
ORDER BY
  dependent_schema,
  dependent_view,
  source_schema,
  source_table,
  1;
'xxxx integrate xxxx'


-- ---------------------------------------------------------------------------------------------------------
-- create view CATALOG.catalog_tsn  as select t, schema, name, remarks from CATALOG.catalog order by t, schema, name;
-- create view CATALOG.catalog_stn  as select t, schema, name, remarks from CATALOG.catalog order by schema, t, name;
-- create view CATALOG.catalog_snt  as select t, schema, name, remarks from CATALOG.catalog order by schema, name, t;



-- select * from CATALOG.catalog;
-- select * from CATALOG._functions;
-- select * from CATALOG.catalog_stn;
-- select * from CATALOG.catalog_snt;

/*

Show indexes:

thx to https://stackoverflow.com/a/2213199/7568091

see also https://www.alberton.info/postgresql_meta_info.html
https://www.postgresql.org/docs/current/static/catalog-pg-index.html
https://www.postgresql.org/docs/current/static/catalog-pg-class.html


select
    i.oid,
    t.oid,
    t.relnamespace,
    -- *
    i.relname as index_name,
    t.relname as table_name,
    a.attname as column_name,
    t.relkind as type,
    ix.indisunique
from
    pg_class t,
    pg_class i,
    pg_index ix,
    pg_attribute a
where true
    and t.oid       = ix.indrelid
    and i.oid       = ix.indexrelid
    and a.attrelid  = t.oid
    and a.attnum    = any( ix.indkey )
    -- and t.relkind = 'r'
    and t.relname !~ '^(pg_|sql_)'
    -- and t.relname like 'test%'
order by
    t.relname,
    i.relname;
*/


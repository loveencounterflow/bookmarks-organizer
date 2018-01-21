

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _X_ cascade;
create schema _X_;

create table _X_.a (
  id serial,
  list text[] );

insert into _X_.a ( list ) values
  ( '{foo}'       ),
  ( '{bar,baz}'   ),
  ( null          ),
  ( '{}'          ),
  ( '{gnu,knew}'  );

\echo a
select * from _X_.a;

\echo solution 1
select null::integer as id, null::text[] as list, null::text as element from _X_.a where false union
select
    a1.id,
    a1.list,
    unnest( a1.list ) as element
    -- a1.*,
    -- a2.*
  from _X_.a as a1
union
select id, list, null from _X_.a;
  -- join _X_.a as a2 using ( id );

\echo solution 2
with v1 as ( select
    a1.id,
    a1.list,
    unnest( a1.list ) as element
    -- a1.*,
    -- a2.*
  from _X_.a as a1
  )
select * from v1
union
select id, list, null from _X_.a as a2
  -- where not any ( a1.id = a2.id );
  where not exists ( select 1 from _X_.a as a3, v1 where v1.id = a2.id );

\echo solution 3
with v1 as ( select
    a1.id,
    a1.list,
    unnest( a1.list ) as element
    -- a1.*,
    -- a2.*
  from _X_.a as a1
  )
select * from v1
union select id, list, null from _X_.a as a2
  where not id = any ( select id from v1 );

\quit

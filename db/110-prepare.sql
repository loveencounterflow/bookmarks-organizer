

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists APP cascade;
create schema APP;


-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function APP._get_pwd() returns text volatile language plsh as $$#!/bin/bash
  pwd; $$;
reset role;

\set cwd `pwd`
-- select * from APP._get_pwd();
-- insert into U.variables values ( 'paths/home', :'cwd'::text )
  -- on conflict ( key ) do update set value = :'cwd'::text;

\ir './010-trm.sql'
select ¶( 'paths/home', :'cwd'::text ) \g :devnull




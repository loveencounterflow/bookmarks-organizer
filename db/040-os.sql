

/*

 .d88888b.    .d8888b.
d88P" "Y88b  d88P  Y88b
888     888  Y88b.
888     888   "Y888b.
888     888      "Y88b.
888     888        "888
Y88b. .d88P  Y88b  d88P
 "Y88888P"    "Y8888P"

*/


-- ---------------------------------------------------------------------------------------------------------
drop schema if exists OS cascade;
create schema OS;


-- =========================================================================================================
-- NODEJS
-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function OS._nodejs_versions() returns jsonb volatile language plsh as $$#!/usr/local/bin/node
  console.log( JSON.stringify( process.versions ) ); $$;
  -- R = ( { key: value, } for key, value of process.versions )
  -- $$#!/usr/local/bin/coffee
  --   console.log 'helo'
  --   $$;
reset role;

-- ---------------------------------------------------------------------------------------------------------
create materialized view OS.nodejs_versions as (
  select * from jsonb_each_text( OS._nodejs_versions() ) );

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function OS._get_hostname() returns text language plpython3u as $$
  import socket as _SOCKET; return _SOCKET.gethostname() $$;
reset role;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function OS._get_architecture_etc() returns jsonb volatile language plsh as $$#!/usr/local/bin/node
  console.log( JSON.stringify( {
    architecture: process.arch,
    platform:     process.platform,
    } ) ); $$;
reset role;

-- -- ---------------------------------------------------------------------------------------------------------
-- create materialized view OS.machine as (
--   select * from jsonb_each_text( OS._get_architecture_etc() ) union all
--   select 'hostname' as key, OS._get_hostname() as value );


-- =========================================================================================================
-- ABSORB OS ENVIRONMENT
-- ---------------------------------------------------------------------------------------------------------
create table OS.env (
  key   text unique not null primary key,
  value text        not null );

-- ---------------------------------------------------------------------------------------------------------
\ir './update-os-env.sql'


-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT use environment to check for this */
create function OS.is_dev() returns boolean volatile language sql as $$
select count(*) > 0 from OS.env where key = 'NODE_ENV' $$;

-- ---------------------------------------------------------------------------------------------------------
do $$ begin perform ¶( 'OS/nodejs/versions/'   || key, value ) from jsonb_each_text( OS._nodejs_versions() );         end; $$;
do $$ begin perform ¶( 'OS/machine/'           || key, value ) from jsonb_each_text( OS._get_architecture_etc() ) ;   end; $$;
do $$ begin perform ¶( 'OS/machine/hostname',          OS._get_hostname() );                                          end; $$;
do $$ begin perform ¶( 'OS/env/' || key,               substring( value for 50 ) ) from OS.env;                       end; $$;

-- \set pwd `pwd`
-- \echo :pwd
\quit


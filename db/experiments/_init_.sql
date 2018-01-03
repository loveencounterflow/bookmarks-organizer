

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _INIT_ cascade;
create schema _INIT_;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function _INIT_.ls() returns text volatile language plsh as
  $$#!/bin/bash
    ls -AlF $$;
reset role;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function _INIT_.home() returns text volatile language plsh as
  $$#!/bin/bash
    echo ~ $$;
reset role;



/* ###################################################################################################### */

-- ---------------------------------------------------------------------------------------------------------
select * from INIT.ls();
select * from INIT.home();
select * from INIT.nodejs_versions;
-- select * from INIT.environment;
select * from INIT.os;

\quit

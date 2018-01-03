-- ---------------------------------------------------------------------------------------------------------
drop schema if exists SH cascade;
create schema SH;
set role dba;

-- ---------------------------------------------------------------------------------------------------------
create function SH.concat( text, text ) returns text
language plsh
as $$#!/bin/bash
  echo "$1$2"
  $$;

-- ---------------------------------------------------------------------------------------------------------
create function SH.pwd() returns text
language plsh
as $$#!/bin/bash
  echo "PWD FTW!!"
  pwd
  $$;

-- ---------------------------------------------------------------------------------------------------------
create function SH.printenv() returns text
language plsh
as $$#!/bin/bash
  printenv
  $$;

-- -- ---------------------------------------------------------------------------------------------------------
-- create function SH.nodes() returns text
-- language plsh
-- as $$
-- #!/bin/sh
-- psql -U kbm -c "select * from nodes"
-- $$;

-- -- ---------------------------------------------------------------------------------------------------------
-- create function SH.repeat() returns text
-- language plsh
-- as $$
-- #!/bin/sh
-- # ( sleep 1 ; echo 'yes' ) &
-- while true; do ( echo yes; sleep 0.5 ); done
-- $$;

-- -- ---------------------------------------------------------------------------------------------------------
-- select SH.concat( 'foo', 'bar' );
-- select SH.pwd();
-- select SH.printenv();

reset role;

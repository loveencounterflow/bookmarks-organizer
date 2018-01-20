
/* ###################################################################################################### */
-- select * from OS.nodejs_versions;
-- select * from OS.env;
-- \set log          '/tmp/psql-output'
-- do $$ begin perform log( 'machine:' ); end; $$;

\pset tuples_only off

-- -- ---------------------------------------------------------------------------------------------------------
-- -- select 'OS.machine' \g :out
-- \echo
-- \pset title 'OS.machine'
-- select * from OS.machine \g :out

-- ---------------------------------------------------------------------------------------------------------
do $$ begin perform log( 'is dev:', U.truth( OS.is_dev() ) ); end; $$;

-- ---------------------------------------------------------------------------------------------------------
-- select 'U.variables' \g :out
\echo
\echo 'U.variables'
select * from U.variables where key ~ '^OS/machine/' order by key \g :out


\quit


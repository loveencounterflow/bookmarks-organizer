


/* ### NOTE should at any rate turn off pager, otherwise some informative intermittent select statements may
  cause the scripts to stop and wait for user input to terminate paged output:*/
\ir './010-trm.sql'
\pset pager off
-- \pset tuples_only on
\set _TITLE       :blue:reverse'  ':O:blue' '

\echo :_TITLE'110-prepare.sql':O            \ir './110-prepare.sql'
\echo :_TITLE'120-src.sql':O                \ir './120-src.sql'



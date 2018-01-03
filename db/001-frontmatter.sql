
/* ### NOTE should at any rate turn off pager, otherwise some informative intermittent select statements may
  cause the scripts to stop and wait for user input to terminate paged output:*/
\pset pager off
\pset tuples_only on
\set orange       '\x1b[38;05;208m'
\set yellow       '\x1b[38;05;226m'
\set reset        '\x1b[0m'
\set reverse      '\x1b[7m'
\set _O           :reset
\set _TITLE       :yellow:reverse'  ':_O:yellow' '

\echo :_TITLE'010-trm':_O             \ir './010-trm.sql'
\echo :_TITLE'020-extensions':_O      \ir './020-extensions.sql'
\echo :_TITLE'030-utilities':_O       \ir './030-utilities.sql'
\echo :_TITLE'035-sh':_O              \ir './035-sh.sql'
\echo :_TITLE'040-os':_O              \ir './040-os.sql'
\echo :_TITLE'050-init':_O            \ir './050-init.sql'
\echo :_TITLE'060-fdw':_O             \ir './060-fdw.sql'
\echo :_TITLE'199-bye':_O             \ir './199-bye.sql'

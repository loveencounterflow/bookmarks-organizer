


/* ### NOTE should at any rate turn off pager, otherwise some informative intermittent select statements may
  cause the scripts to stop and wait for user input to terminate paged output:*/
\ir './010-trm.sql'
\pset pager off
-- \pset tuples_only on
\set _TITLE       :blue:reverse'  ':O:blue' '

\echo :_TITLE'110-prepare.sql':O                              \ir './110-prepare.sql'
\echo :_TITLE'120-utp.sql':O                                  \ir './120-utp.sql'
\echo :_TITLE'125-flowmatic.sql':O                            \ir './125-flowmatic.sql'
\echo :_TITLE'126-flowmatic-tagparser.sql':O                  \ir './126-flowmatic-tagparser.sql'
\echo :_TITLE'150-src-000-read-lines.sql':O                   \ir './150-src-000-read-lines.sql'
\echo :_TITLE'150-src-100-add-and-aggregate-groupings.sql':O  \ir './150-src-100-add-and-aggregate-groupings.sql'
\echo :_TITLE'150-src-200-split-tags-and-urls.sql':O          \ir './150-src-200-split-tags-and-urls.sql'
\echo :_TITLE'150-src-300-merge-into-documents.sql':O         \ir './150-src-300-merge-into-documents.sql'
\echo :_TITLE'150-src-400-document-tsvectors.sql':O           \ir './150-src-400-document-tsvectors.sql'



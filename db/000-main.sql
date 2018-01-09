
/* ### NOTE should at any rate turn off pager, otherwise some informative intermittent select statements may
  cause the scripts to stop and wait for user input to terminate paged output:*/
\pset pager off
-- \pset tuples_only on
\pset null '∎'

\ir './010-trm.sql'
\set _TITLE       :yellow:reverse'  ':O:yellow' '

-- \ir '/home/flow/io/bookmarks-organizer/aquameta/core/000-meta/000-meta_identifiers.sql'
-- \ir '/home/flow/io/bookmarks-organizer/aquameta/core/000-meta/001-meta_catalog.sql'
-- \ir '/home/flow/io/bookmarks-organizer/aquameta/core/000-meta/002-utils.sql'

\echo :_TITLE'001-frontmatter':O              \ir './001-frontmatter.sql'
\echo :_TITLE'101-app':O                      \ir './101-app.sql'





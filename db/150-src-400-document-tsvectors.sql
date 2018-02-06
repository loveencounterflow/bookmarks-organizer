
/*

 .d8888b.  8888888b.   .d8888b.
d88P  Y88b 888   Y88b d88P  Y88b
Y88b.      888    888 888    888
 "Y888b.   888   d88P 888
    "Y88b. 8888888P"  888
      "888 888 T88b   888    888
Y88b  d88P 888  T88b  Y88b  d88P
 "Y8888P"  888   T88b  "Y8888P"

*/

\ir './010-trm.sql'
-- \timing on

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _SRC_ cascade;
create schema _SRC_;

/*  ========================================================================================================

--------------------------------------------------------------------------------------------------------- */


-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(11)=--':O
create table _SRC_._bookmarks_400_tsvectors as ( select
    entrynr,
    document
  from SRC._bookmarks_399
    );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(12)=--':O
create view _SRC_._bookmarks_499 as ( select *
  from _SRC_._bookmarks_400_tsvectors order by entrynr );


/* ###################################################################################################### */

\pset pager off
\set ECHO queries
-- select * from SRC._bookmarks_099 order by linenr;
-- select * from SRC._bookmarks_199 order by linenr;
-- select * from SRC._bookmarks_299 order by linenr;
-- select * from _SRC_._bookmarks_301_join_entry_and_hunk_nrs;
-- select * from _SRC_._bookmarks_310_fragments_from_non_url_or_tags_pre order by entrynr;
-- select * from _SRC_._bookmarks_311_fragments_from_non_url_or_tags order by entrynr;
-- select * from _SRC_._bookmarks_320_fragments_from_urls_and_tags order by entrynr;
select * from _SRC_._bookmarks_499 order by entrynr;
-- select * from _SRC_._bookmarks_399 order by linenr;
\set ECHO none
\quit


\set ECHO queries
-- select * from SRC._bookmarks_000_raw;
-- select * from _SRC_._bookmarks_276_keywords_from_urls;
-- select * from SRC._bookmarks_099;
-- select * from _SRC_._bookmarks_280_merge;
select * from SRC.bookmarks order by linenr, keytype, keyword;
select *
  from SRC.bookmarks
  where to_tsvector( 'english', keyword ) @@ to_tsquery( 'english', 'contxt' );
\set ECHO none


-- select * from FM.results;


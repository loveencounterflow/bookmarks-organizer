
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


/*  ========================================================================================================

--------------------------------------------------------------------------------------------------------- */


-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(1)=--':O
create view SRC._bookmarks_300_consolidate as ( select
    linenr,
    key,
    values,
    keytype,
    keyword
  from SRC._bookmarks_299
union select
    linenr      as linenr,
    key         as key,
    values      as values,
    null        as keytype,
    null        as keyword
  from SRC._bookmarks_199
    where not linenr = any ( select linenr from SRC._bookmarks_299 ) );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(2)=--':O
create view SRC._bookmarks_301_join_entry_and_hunk_nrs as ( select
    c.linenr          as linenr,
    n.hunknr          as hunknr,
    n.entrynr         as entrynr,
    c.key             as key,
    c.values          as values,
    c.keytype         as keytype,
    c.keyword         as keyword
  from      SRC._bookmarks_300_consolidate          as c
  left join SRC._bookmarks_100_add_entry_and_hunk_nrs as n using ( linenr )
  order by
    linenr,
    entrynr,
    hunknr );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(3)=--':O
create view SRC._bookmarks_310_fragments_from_non_url_or_tags_pre as ( select
    entrynr                                       as entrynr,
    key                                           as key,
    array_to_string( values, e'\n' )              as fragment
  from SRC._bookmarks_301_join_entry_and_hunk_nrs
  where not key in ( 'url', 'tags' ) );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(4)=--':O
create view SRC._bookmarks_311_fragments_from_non_url_or_tags as ( select distinct on ( entrynr )
    entrynr                                                         as entrynr,
    string_agg( fragment, e'\n\n' ) over ( partition by entrynr )   as fragment
  from SRC._bookmarks_310_fragments_from_non_url_or_tags_pre );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(5)=--':O
create view SRC._bookmarks_320_fragments_from_urls_and_tags as ( select distinct on ( entrynr )
    entrynr                                                         as entrynr,
    string_agg( keyword, e'\n' ) over ( partition by entrynr )      as fragment
  from SRC._bookmarks_301_join_entry_and_hunk_nrs
  where key in ( 'url', 'tags' ) );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(6)=--':O
create view SRC._bookmarks_330_documents_from_fragments as ( select distinct on ( entrynr )
  entrynr                                                           as entrynr,
  string_agg( fragment, e'\n\n' ) over ( partition by entrynr )     as document
  from (
    select * from SRC._bookmarks_311_fragments_from_non_url_or_tags
    union select * from SRC._bookmarks_320_fragments_from_urls_and_tags ) as x );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(7)=--':O
create view SRC._bookmarks_399 as ( select *
  from SRC._bookmarks_330_documents_from_fragments order by entrynr );


/* ###################################################################################################### */

\quit
\pset pager off
\set ECHO queries
-- select * from SRC._bookmarks_099 order by linenr;
-- select * from SRC._bookmarks_199 order by linenr;
-- select * from SRC._bookmarks_299 order by linenr;
-- select * from SRC._bookmarks_301_join_entry_and_hunk_nrs;
-- select * from SRC._bookmarks_310_fragments_from_non_url_or_tags_pre order by entrynr;
-- select * from SRC._bookmarks_311_fragments_from_non_url_or_tags order by entrynr;
-- select * from SRC._bookmarks_320_fragments_from_urls_and_tags order by entrynr;
select * from SRC._bookmarks_399 order by entrynr;
-- select * from SRC._bookmarks_399 order by linenr;
\set ECHO none



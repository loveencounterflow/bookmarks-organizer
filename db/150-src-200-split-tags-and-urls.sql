
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
    TAGS
--------------------------------------------------------------------------------------------------------- */

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(7)=--':O
create materialized view SRC._bookmarks_200_add_dacts as ( select
    linenr                                                                      as linenr,
    key                                                                         as key,
    values                                                                      as values,
    case key
      when 'tags' then UTP.lex_tags( array_to_string( values, ' ' ) )
      else null end                                                             as dacts
  from SRC._bookmarks_199
  );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(8)=--':O
create index on SRC._bookmarks_200_add_dacts ( linenr );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(9)=--':O
-- explain analyze
create table SRC._bookmarks_260_push_dacts as ( select
    linenr                            as linenr,
    values                            as values,
    unnest( FM.push_dacts( dacts ) )  as ac
  from SRC._bookmarks_200_add_dacts
  order by linenr);

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(10)=--':O
create view SRC._bookmarks_270_keywords_from_tags_as_jsonb as ( select
    v1.linenr                                           as linenr,
    b.key                                               as key,
    v1.values                                           as values,
    -- j.ac                                                as ac,
    r.value                                             as facets
  from SRC._bookmarks_260_push_dacts        as v1
  left join FM.journal                        as j on ( v1.ac       = j.ac      )
  left join SRC._bookmarks_099                as b on ( v1.linenr   = b.linenr  )
  left join FM.results                        as r on ( v1.ac       = r.ac      )
  order by linenr );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(10)=--':O
create view SRC._bookmarks_271_keywords_from_tags_as_facets as ( select
    linenr                                                        as linenr,
    key                                                           as key,
    values                                                        as values,
    U.unnest_2d_1d( SRC.jsonb_object_as_text_facets( facets ) )   as facet
  from SRC._bookmarks_270_keywords_from_tags_as_jsonb );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(10)=--':O
create view SRC._bookmarks_272_keywords_from_tags as ( select
    linenr                                                        as linenr,
    key                                                           as key,
    values                                                        as values,
    facet[ 1 ]                                                    as keytype,
    facet[ 2 ]                                                    as keyword
  from SRC._bookmarks_271_keywords_from_tags_as_facets );


/*  ========================================================================================================
    URLS
--------------------------------------------------------------------------------------------------------- */

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(10)=--':O
create view SRC._bookmarks_275_keywords_from_urls_as_facets as ( select
    a.linenr                                            as linenr,
    a.key                                               as key,
    array[ a.value ]                                             as values,
    w.*
  from
    SRC._bookmarks_099 as a,
    lateral ( select U.unnest_2d_1d( x ) as facet from U.parse_url_words( a.value ) as x ) as w
  where a.key = 'url' );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(10)=--':O
create view SRC._bookmarks_276_keywords_from_urls as ( select
    linenr                                                        as linenr,
    key                                                           as key,
    values                                                        as values,
    facet[ 1 ]                                                    as keytype,
    facet[ 2 ]                                                    as keyword
  from SRC._bookmarks_275_keywords_from_urls_as_facets );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(11)=--':O
create view SRC._bookmarks_280_merge as (
  with v1 as ( select
      linenr,
      key,
      values,
      keytype,
      keyword
    from SRC._bookmarks_272_keywords_from_tags ),
  v2 as ( select
      linenr,
      key,
      values,
      keytype,
      keyword
  from SRC._bookmarks_276_keywords_from_urls )
  select        * from v1
  union select  * from v2 );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(12)=--':O
create view SRC._bookmarks_299 as ( select * from SRC._bookmarks_280_merge order by linenr );


/* ###################################################################################################### */

\quit

select * from SRC._bookmarks_199 order by linenr;
select * from SRC._bookmarks_299 order by linenr;


\set ECHO queries
-- select * from SRC._bookmarks_000_raw;
-- select * from SRC._bookmarks_276_keywords_from_urls;
-- select * from SRC._bookmarks_099;
-- select * from SRC._bookmarks_280_merge;
select * from SRC.bookmarks order by linenr, keytype, keyword;
select *
  from SRC.bookmarks
  where to_tsvector( 'english', keyword ) @@ to_tsquery( 'english', 'contxt' );
\set ECHO none


-- select * from FM.results;


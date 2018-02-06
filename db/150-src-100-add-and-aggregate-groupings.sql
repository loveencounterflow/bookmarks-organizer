
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
\echo :X'--=(1)=--':O
create view SRC._bookmarks_100_add_entry_and_hunk_nrs as ( select
    /* This solution to add group numbers took a lot longer to write than I had thought. Check out why
    here:
    * https://dba.stackexchange.com/questions/197125/in-postgresql-how-can-i-assign-group-ids-depending-on-content
    * https://stackoverflow.com/questions/48628743/define-a-window-over-consecutive-rows-with-a-particular-value
    * https://stackoverflow.com/a/48630284/7568091

    Thx to https://dba.stackexchange.com/a/197126/126933 */
    linenr                                                        as linenr,
    count( key  != '...' or null ) over ( order by linenr )       as hunknr,
    count( star != '...' or null ) over ( order by linenr )       as entrynr
  from SRC._bookmarks_099 );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(2)=--':O
create view SRC._bookmarks_110_aggregated_hunks as ( with
  v1 as ( select
      b.linenr                                                    as linenr,
      g.hunknr                                                    as hunknr,
      g.entrynr                                                   as entrynr,
      b.key                                                       as key,
      array_agg( value ) over ( partition by hunknr )             as values
    from SRC._bookmarks_099                       as b
    left join SRC._bookmarks_100_add_entry_and_hunk_nrs  as g using ( linenr ) )
  select * from v1 where key != '...' );


-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(3)=--':O
create view SRC._bookmarks_199 as ( select * from SRC._bookmarks_110_aggregated_hunks );



/* ###################################################################################################### */


\quit
\pset pager off
\set ECHO queries
select * from SRC._bookmarks_099 order by linenr;
select *
  from SRC._bookmarks_100_add_entry_and_hunk_nrs as v1
  left join SRC._bookmarks_099 as v2 using ( linenr )
  order by linenr;
select * from SRC._bookmarks_199 order by linenr;
\set ECHO none
xxx


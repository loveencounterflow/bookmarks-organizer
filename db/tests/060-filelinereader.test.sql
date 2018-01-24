

\ir '../010-trm.sql'
\pset numericlocale on
-- \set ECHO all
-- \set ECHO errors
-- \set ECHO none
\set ECHO queries

/*

8888888888 8888888b.   888       888   888                      888
888        888  "Y88b  888   o   888   888                      888
888        888    888  888  d8b  888   888                      888
8888888    888    888  888 d888b 888   888888  .d88b.  .d8888b  888888
888        888    888  888d88888b888   888    d8P  Y8b 88K      888
888        888    888  88888P Y88888   888    88888888 "Y8888b. 888
888        888  .d88P  8888P   Y8888   Y88b.  Y8b.          X88 Y88b.
888        8888888P"   888P     Y888    "Y888  "Y8888   88888P'  "Y888

*/

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _FLR_test_ cascade;
create schema _FLR_test_;


-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(1)=--':O
select FLR.create_file_lines_view(
  '_FLR_test_._sample_000_raw',
  /* ### TAINT use proper PATH.join */
  ¶( 'paths/home') || '/db/experiments/' || 'line-json-test.json' ) \g :devnull
  ;

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(2)=--':O
create view _FLR_test_._sample_010_skip_comments_and_empty as ( select
    linenr,
    line
  from
    _FLR_test_._sample_000_raw
  where true
    and line !~ '^\s*#'
    and line !~ '^\s*$'
  );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(3)=--':O
create view _FLR_test_._sample_020_as_jsonb as ( select
    linenr        as linenr,
    line::jsonb   as entry
  from
    _FLR_test_._sample_010_skip_comments_and_empty
  where true
    and line !~ '^\s*#'
    and line !~ '^\s*$' );

select * from _FLR_test_._sample_000_raw;
select * from _FLR_test_._sample_010_skip_comments_and_empty;
select * from _FLR_test_._sample_020_as_jsonb;









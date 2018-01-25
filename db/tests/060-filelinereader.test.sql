

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

-- create view _FLR_test_.a as ( select '{"key":"valuewith \n\u000b𠀀\\u{20000} \"special\"characters\n"}' as d );
-- -- create view _FLR_test_.a as ( select '{"key":"valuewith \n\u000b𠀀 \"special\"characters\n"}' as d );
-- -- create view _FLR_test_.a as ( select '"foo\n\x0a \"bar\"' as d );
-- create view _FLR_test_.b as ( select d::jsonb as d from _FLR_test_.a );
-- create view _FLR_test_.c as ( select d->>'key' as d from _FLR_test_.b );
-- select * from _FLR_test_.a;
-- select * from _FLR_test_.b;
-- select * from _FLR_test_.c;
-- \quit


-- ---------------------------------------------------------------------------------------------------------
\echo :X'--=(1)=--':O
create view _FLR_test_._sample_000_raw as (
  select linenr, line from FLR.read_file_lines(
    ¶( 'paths/home' ) || '/db/experiments/' || 'line-json-test.json'
    ) );

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








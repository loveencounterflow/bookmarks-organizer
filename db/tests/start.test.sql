
\ir '../010-trm.sql'
\timing off
\set X :yellow


-- turn off echo and keep things quiet.
-- format the output for nice tap.
\set echo none
\set quiet 1
-- \pset format unaligned
-- \pset tuples_only true
\pset pager

-- revert all changes on failure.
\set on_error_rollback 1
\set on_error_stop true

-- drop extension if exists pgtap;
-- create extension if not exists pgtap;

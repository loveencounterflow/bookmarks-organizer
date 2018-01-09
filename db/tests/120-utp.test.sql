
\ir '../010-trm.sql'
\pset tuples_only off
\timing on
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

drop extension if exists pgtap;
create extension if not exists pgtap;

/* ###################################################################################################### */
\echo :X'-=(tap)=-':O

-- begin;
-- select * from plan( 23 );
select * from no_plan();

\echo :X'-=(1)=-':O
select * from _LEX_.phrase_splitters;
select tables_are( '_LEX_', array[ 'word_probes', 'patterns', 'phrase_probes', 'phrase_splitters' ] );

-- select sequences_are( 'queue', array[ '_message_seq' ] );
-- select has_index( 'queue', 'queue', 'myindex', array[ 't' ], );
-- select has_index( 'queue', 'queue', 'myindex', array[ 'key', 'value' ], );

-- select function_returns( 'queue', 'send',               array[ 'text', 'jsonb'  ],  'bigint',            'send returns ...'               );
-- select is_empty( 'select * from QUEUE.queue;' );
select * from finish();
rollback;


/* ###################################################################################################### */
drop extension if exists pgtap;
\quiet

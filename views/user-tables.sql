

with v1 as ( select
    -- relid,
    schemaname || '.' || relname          as name,
    seq_scan + idx_scan                   as scans,
    seq_tup_read + idx_tup_fetch          as reads,
    n_tup_ins + n_tup_upd + n_tup_del     as changes
    -- n_tup_hot_upd,
    -- n_live_tup,
    -- n_dead_tup,
    -- n_mod_since_analyze
    -- last_vacuum
    -- last_autovacuum
    -- last_analyze
    -- last_autoanalyze
    -- vacuum_c
  from pg_stat_user_tables
  -- where true
  --   -- and ( not query ~ '^LISTEN queue_' )
  --   and ( not query ~ '8FDE61F6087C88EB8D4111757AFD7C23' ) /* <- tag to omit this query */
  )
select * from v1 order by scans + reads + changes desc nulls last
  ;


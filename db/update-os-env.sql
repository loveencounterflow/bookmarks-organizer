

-- ---------------------------------------------------------------------------------------------------------
/* Update OS.env to reflect current environment: */
/* thx to https://dba.stackexchange.com/a/134538/126933 */
\set os_environment `printenv`
insert into OS.env with
    v1 as ( select regexp_split_to_table( :'os_environment'::text, '\n' ) as setting  ),
    v2 as ( select regexp_matches( setting, '^([^=]+)=(.*)$' ) as kv_pairs from v1    )
    select
        kv_pairs[ 1 ] as key,
        kv_pairs[ 2 ] as value
      from v2
      on conflict ( key ) do update set value = excluded.value;

/* ###################################################################################################### */
\quit

select * from OS.env where key ~ 'PY|PAGER|^[a-z]';


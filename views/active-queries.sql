
/* `hexdump -n 16 -e '4/4 "%08X" 1 "\n"' /dev/random` */
;
select
    TIME.age_as_text( query_start )                               as age,
    usename                                                       as user,
    client_hostname || '=' || client_addr || ':' || client_port   as from,
    state                                                         as state,
    query                                                         as query
  from pg_stat_activity
  where true
    -- and ( not query ~ '^LISTEN queue_' )
    and ( not query ~ '8FDE61F6087C88EB8D4111757AFD7C23' ) /* <- tag to omit this query */
  order by query_start;




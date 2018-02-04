
\pset numericlocale on

with max as ( select
    max( calls )        as calls,
    max( self_time )    as self_time,
    max( total_time )   as total_time
  from pg_stat_user_functions as main
  where not ( main.schemaname = 'bar' and main.funcname = 'bar' ) ),
pcts as ( select
    main.funcid,
    ( main.calls::float  / max.calls::float  * 100 )::integer as  "c%",
    ( main.total_time    / max.total_time    * 100 )::integer as "tt%",
    ( main.self_time     / max.self_time     * 100 )::integer as "st%"
  from
    pg_stat_user_functions as main,
    max
  where not ( main.schemaname = 'bar' and main.funcname = 'bar' ) ),
results as ( select
    /* !!!!!!!!!!!!!!!!!!!!!!!! */
    case when main.funcname ~ '_taint_' then '▋ ▋ ▋ ' else '' end ||
    /* !!!!!!!!!!!!!!!!!!!!!!!! */
  case when main.schemaname = 'baseline' then '█ ' else '' end ||
    main.schemaname || '.' || main.funcname   as name,
    main.calls                                as calls,
    ( self_time   / calls * 1000 )::integer   as "1k st/ms",
    ( total_time  / calls * 1000 )::integer   as "1k tt/ms",
    pcts."c%"                                 as "c%",
    BAR.bar( "c%" )                           as "(calls)",
    main.total_time::integer                  as "total/ms",
    pcts."tt%"                                as "tt%",
    BAR.bar( pcts."tt%" )                     as "(total)",
    main.self_time::integer                   as "self/ms",
    pcts."st%"                                as "st%",
    BAR.bar( pcts."st%" )                     as "(self)"
  from
    pg_stat_user_functions as main
  join pcts on ( main.funcid = pcts.funcid ) )
select * from results
  order by
    "self/ms" desc,
    "total/ms" desc,
    calls desc,
    "1k st/ms" desc,
    "1k tt/ms" desc,
    1
  ;


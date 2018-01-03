
/*

888b     d888          888 888    d8b          888
8888b   d8888          888 888    Y8P          888
88888b.d88888          888 888                 888
888Y88888P888 888  888 888 888888 888 88888b.  888  .d88b.  .d8888b
888 Y888P 888 888  888 888 888    888 888 "88b 888 d8P  Y8b 88K
888  Y8P  888 888  888 888 888    888 888  888 888 88888888 "Y8888b.
888   "   888 Y88b 888 888 Y88b.  888 888 d88P 888 Y8b.          X88
888       888  "Y88888 888  "Y888 888 88888P"  888  "Y8888   88888P'
                                      888
                                      888
                                      888
*/

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _MULTIPLES_ cascade;
create schema _MULTIPLES_;


-- ---------------------------------------------------------------------------------------------------------
create function _MULTIPLES_.date_from_js_timestamp_woz( ts bigint )
  returns timestamp without time zone
  language sql
  immutable
  returns null on null input
  as $$
    -- select ( timestamp with time zone 'epoch' + ts * interval '1 millisecond' ) at time zone 'utc';
    -- select ( timestamp with time zone 'epoch' + ts * interval '1 millisecond' );
    -- select ( timestamp 'epoch' + ts * interval '1 millisecond' );
    select ( timestamp 'epoch' + ts * interval '1 millisecond' );
    $$;

-- ---------------------------------------------------------------------------------------------------------
create function _MULTIPLES_.date_from_js_timestamp_wz( ts bigint )
  returns timestamp with time zone
  language sql
  immutable
  returns null on null input
  as $$
    -- select ( timestamp with time zone 'epoch' + ts * interval '1 millisecond' ) at time zone 'utc';
    select ( timestamp with time zone 'epoch' + ts * interval '1 millisecond' );
    -- select ( timestamp 'epoch' + ts * interval '1 millisecond' );
    -- select ( timestamp 'epoch' + ts * interval '1 millisecond' );
    $$;

-- #########################################################################################################

\pset tuples_only on

\echo ----------------------------------------------------------
\echo 'ISO'
set datestyle = 'ISO';
select _MULTIPLES_.date_from_js_timestamp_wz( 1488821615577 );
select _MULTIPLES_.date_from_js_timestamp_wz( 1498259910635 );

\echo ----------------------------------------------------------
\echo 'SQL'
set datestyle = 'SQL';
select _MULTIPLES_.date_from_js_timestamp_wz( 1488821615577 );
select _MULTIPLES_.date_from_js_timestamp_wz( 1498259910635 );

\echo ----------------------------------------------------------
\echo 'German'
set datestyle = 'German';
select _MULTIPLES_.date_from_js_timestamp_wz( 1488821615577 );
select _MULTIPLES_.date_from_js_timestamp_wz( 1498259910635 );

\pset tuples_only off
with
  v1 as (
    select _MULTIPLES_.date_from_js_timestamp_wz( 1488821615577 ) as d
    ),
  v2 as (
    select d, age( clock_timestamp(), d ) as a from v1
    )
  select d, a, extract( month from a ), to_char( d, 'YYYY Mon DD HH24:MI:SS TZ' ) from v2;

select _MULTIPLES_.date_from_js_timestamp_wz( 0 );

create function _MULTIPLES_.interval_from_bigint( n bigint ) returns interval
language sql
as $$
  select _MULTIPLES_.date_from_js_timestamp_wz( n ) - _MULTIPLES_.date_from_js_timestamp_wz( 0 );
$$;


create table _MULTIPLES_.seconds_per (
  period  text unique not null primary key,
  n       bigint );

insert into _MULTIPLES_.seconds_per values
  ( 'year',    60 * 60 * 24     * 30.4375 * 12  ),
  ( 'month',   60 * 60 * 24     * 30.4375       ),
  ( 'week',    60 * 60 * 24 * 7                 ),
  ( 'day',     60 * 60 * 24                     ),
  ( 'hour',    60 * 60                          ),
  ( 'minute',  60                               ),
  ( 'second',  1                                );

-- select 365.25 / 12 ;
select * from _MULTIPLES_.seconds_per;

-- select y.n, m.n, y.n / m.n
--   from
--   ( select n from _MULTIPLES_.seconds_per where period = 'year'  ) as y,
--   ( select n from _MULTIPLES_.seconds_per where period = 'month' ) as m;



-- ---------------------------------------------------------------------------------------------------------
create function _MULTIPLES_.age_as_text( age_s double precision )
  returns text immutable language sql as $$
    select ''
      || case when age_s >=        31557600                then ( age_s /  31557600 )::numeric( 16, 1 )::text || ' years'   else '' end
      || case when age_s between    2629800 and   31557600 then ( age_s /   2629800 )::numeric( 16, 1 )::text || ' months'  else '' end
      || case when age_s between     604800 and    2629800 then ( age_s /    604800 )::numeric( 16, 1 )::text || ' weeks'   else '' end
      || case when age_s between      86400 and     604800 then ( age_s /     86400 )::numeric( 16, 1 )::text || ' days'    else '' end
      || case when age_s between       3600 and      86400 then ( age_s /      3600 )::numeric( 16, 1 )::text || ' hours'   else '' end
      || case when age_s between         60 and       3600 then ( age_s /        60 )::numeric( 16, 1 )::text || ' minutes' else '' end
      || case when age_s <                              60 then ( age_s /         1 )::numeric( 16, 1 )::text || ' seconds' else '' end
      ;
  $$;
-- ---------------------------------------------------------------------------------------------------------
create function _MULTIPLES_.age_as_text( t timestamp with time zone )
  returns text immutable language sql as $$
    select _MULTIPLES_.age_as_text( extract( epoch from clock_timestamp() - t ) ) as age
  $$;


-- ---------------------------------------------------------------------------------------------------------
create view _MULTIPLES_.v as (
  with v1 as ( select generate_series( 1, 30 ) as e ),
  v2 as ( select e, ( 10 ^ ( e::float / 3 ) )::double precision as d from v1 )
  select
      d,
      _MULTIPLES_.age_as_text( d )
    from v2
    order by d
  );


with v1 as ( values
  ( '2017/09/18 12:00' ),
  ( '2017/09/18' ),
  ( '2017/08/18' ),
  ( '2017/07/18' ),
  ( '2017/06/18' ),
  ( '2017/05/18' ),
  ( '2017/04/18' ),
  ( '2017/03/18' ),
  ( '2017/02/18' ),
  ( '2017/01/18' ),
  ( '2016/12/18' ),
  ( '2016/09/18' ) ),
v2 as ( select column1::timestamp with time zone as date from v1 )
select date, extract( epoch from clock_timestamp() - date ) as epoch, _MULTIPLES_.age_as_text( date ) from v2;




create function _MULTIPLES_.as_fields(
  in  s       bigint,
  out years   bigint,
  out months  bigint,
  out weeks   bigint,
  out days    bigint,
  out hours   bigint,
  out minutes bigint,
  out seconds bigint )
language plpgsql
as $$
  begin
    years   :=  s / ( select n from _MULTIPLES_.seconds_per where period = 'year'   );
    months  :=  s / ( select n from _MULTIPLES_.seconds_per where period = 'month'  );
    weeks   :=  s / ( select n from _MULTIPLES_.seconds_per where period = 'week'   );
    days    :=  s / ( select n from _MULTIPLES_.seconds_per where period = 'day'    );
    hours   :=  s / ( select n from _MULTIPLES_.seconds_per where period = 'hour'   );
    minutes :=  s / ( select n from _MULTIPLES_.seconds_per where period = 'minute' );
    seconds :=  s / ( select n from _MULTIPLES_.seconds_per where period = 'second' );
    end;
$$;

create view _MULTIPLES_.seconds_comparison as (
  with v1 as (
    select generate_series( 0, 18 ) as n
    ),
    v2 as (
      select
          n,
          ( 10 ^ n )::bigint as s
        from v1

      union all select null as n,               32768 as s /* smallint  */
      union all select null as n,          2147483648  as s /* integer   */
      union all select null as n, 9223372036854775807   as s /* bigint    */
      )
    select
        -- v2.n,
        log( v2.s ) as e10,
        log( v2.s ) / log( 2 ) as e2,
        _MULTIPLES_.age_as_text( v2.s ) as age,
        v2.s,
        -- pg_typeof( v2.s ),
        v3.*
      from
        v2,
        _MULTIPLES_.as_fields( v2.s ) as v3
      order by e2
  );

-- =========================================================================================================
--
-- ---------------------------------------------------------------------------------------------------------
create table _MULTIPLES_.alphabets (
  base integer,
  positions integer,
  size bigint

  );

  -- b2
  -- b16
  -- b26

create view _MULTIPLES_.alphabet_sizes as (
  /* The creche pattern */
  select null::text as name, null::integer as size where false union all
  select 'bits',        2       union all
  select 'triplets',    3       union all
  select 'octets',      8       union all
  select 'decades',     10      union all
  select 'dozend',      12      union all
  select 'nibbles',     16      union all
  select '[a-z]',       26      union all
  select '[a-zA-Z]',    52      union all
  select 'bytes',       256
  );

-- insert into _MULTIPLES_.alphabets
-- with v1 as ( select generate_series( 1, 10 ) as positions )
with v1 as ( select
    a.name                        as name,
    a.size                        as size,
    positions                     as positions,
    ( size ^ positions )  as choices
    -- ( size ^ positions )::bigint  as choices
  from
    generate_series( 1, 17 ) as positions,
    _MULTIPLES_.alphabet_sizes as a
    order by
      name,
      positions
  )
  select
      name,
      size,
      positions,
      choices,
      floor( log( choices ) ) as magnitude_l,
      ceil( log( choices ) ) as magnitude_h
    from v1
  ;


/* ###################################################################################################### */

-- select * from _MULTIPLES_.seconds_comparison;

\quit







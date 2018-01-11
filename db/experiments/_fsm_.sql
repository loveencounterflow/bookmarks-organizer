
/* thx to http://felixge.de/2017/07/27/implementing-state-machines-in-postgresql.html */

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _FSM_ cascade;
create schema _FSM_;

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(1)=-'
create table _FSM_.states (
  state text unique not null primary key );

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM_.states values
   ( '(start)'            ),
   ( 'awaiting_payment'   ),
   ( 'awaiting_shipment'  ),
   ( 'awaiting_refund'    ),
   ( 'shipped!'           ),
   ( 'canceled!'          ),
   ( 'stop'               );

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(2)=-'
create table _FSM_.events (
  event text unique not null primary key );

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM_.events values
  ( '!create'   ),
  ( 'pay'       ),
  ( 'cancel'    ),
  ( 'ship'      ),
  ( 'refund'    );

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(3)=-'
create table _FSM_.transitions (
  prv_state     text references _FSM_.states ( state ),
  event         text references _FSM_.events ( event ),
  nxt_state     text references _FSM_.states ( state ) );

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM_.transitions values
  ( '(start)',             '!create',    'awaiting_payment'     ),
  ( 'awaiting_payment',    'pay',        'awaiting_shipment'    ),
  ( 'awaiting_payment',    'cancel',     'canceled!'            ),
  ( 'awaiting_refund',     'cancel',     'awaiting_shipment'    ),
  ( 'awaiting_shipment',   'cancel',     'awaiting_refund'      ),
  ( 'awaiting_shipment',   'ship',       'shipped!'             ),
  ( 'awaiting_refund',     'refund',     'canceled!'            );

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(4)=-'
/* ### TAINT probably better to use domains or other means to ensure integrity */
create function _FSM_.proceed( ¶prv_state text, ¶event text ) returns text stable language plpgsql as $$
  declare
    R text;
  begin
    select into R
        nxt_state
      from _FSM_.transitions
      where ( prv_state = ¶prv_state ) and ( event = ¶event );
  return R;
  end; $$;

-- ---------------------------------------------------------------------------------------------------------
create aggregate _FSM_.proceed_agg( text ) (
  sfunc     = _FSM_.proceed,
  stype     = text,
  initcond  = '(start)' );

-- ---------------------------------------------------------------------------------------------------------
create table _FSM_.journal (
  id        serial    primary key,
  job_id    int       not null,
  event     text      not null,
  time      timestamp not null default now()
);

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT should probably use `lock for update` */
create function _FSM_.on_before_insert_into_journal() returns trigger language plpgsql as $$
  declare
    ¶new_state  text;
    ¶prv_state  text;
  begin
    select _FSM_.proceed_agg( event order by id )
      from (
        select id, event from _FSM_.journal where job_id = new.job_id union
        select new.id, new.event ) as s
      into ¶new_state;
    -- .....................................................................................................
    if ¶new_state is null then
      select nxt_state
        from _FSM_._jobs_events_and_next_states
        where job_id = new.job_id
        order by id desc
        limit 1
        into ¶prv_state;
      raise exception
        'invalid event: ( state %, event % ) -> null for entry (%)',
          ¶prv_state, new.event, row_to_json( new );
      end if;
    -- .....................................................................................................
    return new; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create trigger on_before_insert_into_journal before insert on _FSM_.journal
for each row execute procedure _FSM_.on_before_insert_into_journal();

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(7)=-'
create view _FSM_._jobs_events_and_next_states as ( select
    id                                                                                  as id,
    time                                                                                as time,
    job_id                                                                              as job_id,
    event                                                                               as event,
    _FSM_.proceed_agg( event ) over ( partition by job_id order by id )                 as nxt_state
  from _FSM_.journal );

-- ---------------------------------------------------------------------------------------------------------
create view _FSM_.job_transitions as ( select
    id                                                                                  as id,
    time                                                                                as time,
    job_id                                                                              as job_id,
    coalesce( lag( nxt_state ) over ( partition by job_id order by id ), '(start)' )    as prv_state,
    event                                                                               as event,
    nxt_state                                                                           as nxt_state
  from _FSM_._jobs_events_and_next_states );

/* ###################################################################################################### */



-- ---------------------------------------------------------------------------------------------------------
insert into _FSM_.journal ( job_id, event ) values
  (1, '!create'),
  (1, 'pay'),
  (1, 'ship');

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(5)=-'
-- truncate _FSM_.journal;
insert into _FSM_.journal ( job_id, event, time ) values  ( 13, '!create',  '2017-07-23 00:00:00' );
insert into _FSM_.journal ( job_id, event, time ) values  ( 11, '!create',  '2017-07-23 00:00:00' );
insert into _FSM_.journal ( job_id, event, time ) values  ( 12, '!create',  '2017-07-23 00:00:00' );
insert into _FSM_.journal ( job_id, event, time ) values  ( 11, 'pay',      '2017-07-23 12:00:00' );
insert into _FSM_.journal ( job_id, event, time ) values  ( 11, 'ship',     '2017-07-24 00:00:00' );
insert into _FSM_.journal ( job_id, event, time ) values  ( 12, 'cancel',   '2017-07-24 00:00:00' );
insert into _FSM_.journal ( job_id, event, time ) values  ( 13, 'pay',      '2017-07-24 00:00:00' );
insert into _FSM_.journal ( job_id, event, time ) values  ( 13, 'cancel',   '2017-07-25 00:00:00' );
insert into _FSM_.journal ( job_id, event, time ) values  ( 13, 'cancel',   '2017-07-25 00:00:00' );
-- insert into _FSM_.journal ( job_id, event, time ) values  ( 13, 'refund',   '2017-07-26 00:00:00' );
insert into _FSM_.journal ( job_id, event, time ) values  ( 13, 'ship',     '2017-07-26 00:00:00' );
-- insert into _FSM_.journal (job_id, event) values
--   (2, '!create'),
--   (2, 'ship');


-- ---------------------------------------------------------------------------------------------------------
\echo '-=(6)=-'
select * from _FSM_.journal;
\echo '-=(13)=-'
select * from _FSM_.transitions;
\echo '-=(13)=-'
select * from _FSM_._jobs_events_and_next_states;
select * from _FSM_.job_transitions;



-- ---------------------------------------------------------------------------------------------------------



\quit


-- ---------------------------------------------------------------------------------------------------------
\echo '-=(12)=-'
select
    date::date,
    prv_state,
    count( 1 )
  from
    generate_series( '2017-07-23'::date, '2017-07-26', '1 day' ) as date,
    lateral (
      select
          job_id,
          _FSM_.proceed_agg( event order by id ) as prv_state
      from _FSM_.journal
      where time < date + '1 day'::interval
      group by 1
    ) as orders
  group by 1, 2
  order by 1, 2;

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(10)=-'
select id, job_id, event from _FSM_.journal;

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(11)=-'
select time, _FSM_.proceed_agg(event) over (order by id)
from _FSM_.journal
where job_id = 3;

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(13)=-'
select * from _FSM_.journal;


-- ---------------------------------------------------------------------------------------------------------
\echo '-=(14)=-'
create view _FSM_._all_transitions as (
  select
      s.state                                           as prv_state,
      e.event                                           as event,
      _FSM_.proceed( s.state, e.event ) as nxt_state
      -- _FSM_.proceed( s.prv_state, event)
    from
      _FSM_.states      as s,
      _FSM_.events      as e
      -- _FSM_.transitions as t
    -- where nxt_state is not null
    );

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(15)=-'
select prv_state, event, _FSM_.proceed(prv_state, event)
from (values
  ('(start)', '!create'),
  ('awaiting_payment', 'pay'),
  ('awaiting_payment', 'cancel'),
  ('awaiting_payment', 'ship'),
  ('awaiting_shipment', 'ship')
) as examples(prv_state, event);


/* ###################################################################################################### */
/* ###################################################################################################### */
/* ###################################################################################################### */
\quit


-- ---------------------------------------------------------------------------------------------------------
\echo '-=(16)=-'
select prv_state, event, _FSM_.proceed(prv_state, event)
from (values
  ('(start)', '!create'),
  ('awaiting_payment', 'pay'),
  ('awaiting_payment', 'cancel'),
  ('awaiting_payment', 'ship'),
  ('awaiting_shipment', 'ship')
) as examples(prv_state, event);


-- ---------------------------------------------------------------------------------------------------------
/* aggregation demo */
\echo '-=(17)=-'
select _FSM_.proceed_agg( event order by id )
  from (values
    (1, '!create'),
    (2, 'pay'),
    (3, 'cancel')
  ) examples(id, event);
select _FSM_.proceed_agg( event order by id )
  from (values
    (1, '!create'),
    (2, 'pay'),
    (3, 'ship'),
    (4, 'cancel')
  ) examples(id, event);

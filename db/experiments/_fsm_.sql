
/* thx to http://felixge.de/2017/07/27/implementing-state-machines-in-postgresql.html */

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _FSM_ cascade;
create schema _FSM_;

-- ---------------------------------------------------------------------------------------------------------
create table _FSM_.order_events (
  id        serial    primary key,
  order_id  int       not null,
  event     text      not null,
  time      timestamp not null default now()
);

-- ---------------------------------------------------------------------------------------------------------
create function _FSM_.order_events_transition( state text, event text )
  returns text volatile language sql as $$
  select case state
    -- .....................................................................................................
    when 'start' then
      case event
        when 'create' then 'awaiting_payment'
        else 'error'
        end
    -- .....................................................................................................
    when 'awaiting_payment' then
      case event
        when 'pay'    then 'awaiting_shipment'
        when 'cancel' then 'canceled'
        else 'error'
        end
    -- .....................................................................................................
    when 'awaiting_shipment' then
      case event
        when 'cancel' then 'awaiting_refund'
        when 'ship'   then 'shipped'
        else 'error'
        end
    -- .....................................................................................................
    when 'awaiting_refund' then
      case event
        when 'refund' then 'canceled'
        else 'error'
        end
    -- .....................................................................................................
    else 'error'
    -- .....................................................................................................
    end $$;

-- ---------------------------------------------------------------------------------------------------------
create aggregate _FSM_.order_events_fsm( text ) (
  sfunc     = _FSM_.order_events_transition,
  stype     = text,
  initcond  = 'start' );

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT should probably use `lock for update` */
create function _FSM_.order_events_tigger_func() returns trigger language plpgsql as $$
  declare
    new_state text;
  begin
    select _FSM_.order_events_fsm( event order by id )
    from (
      select id, event from _FSM_.order_events where order_id = new.order_id union
      select new.id, new.event ) as s
    into new_state;
    -- .....................................................................................................
    if new_state = 'error' then
      raise exception 'invalid event: %', row_to_json( new );
      end if;
    -- .....................................................................................................
    return new; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create trigger order_events_trigger before insert on _FSM_.order_events
for each row execute procedure _FSM_.order_events_tigger_func();

/* ###################################################################################################### */

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(1)=-'
select state, event, _FSM_.order_events_transition(state, event)
from (values
  ('start', 'create'),
  ('awaiting_payment', 'pay'),
  ('awaiting_payment', 'cancel'),
  ('awaiting_payment', 'ship'),
  ('awaiting_shipment', 'ship')
) as examples(state, event);

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(2)=-'
select _FSM_.order_events_fsm(event order by id)
from (values
  (1, 'create'),
  (2, 'pay'),
  (3, 'cancel')
) examples(id, event);

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM_.order_events (order_id, event) values
  (1, 'create'),
  (1, 'pay'),
  (1, 'ship');

-- insert into _FSM_.order_events (order_id, event) values
--   (2, 'create'),
--   (2, 'ship');

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(3)=-'
-- truncate _FSM_.order_events;
insert into _FSM_.order_events ( order_id, event, time ) values
  ( 11, 'create', '2017-07-23 00:00:00' ),
  ( 11, 'pay',    '2017-07-23 12:00:00' ),
  ( 11, 'ship',   '2017-07-24 00:00:00' ),
  ( 12, 'create', '2017-07-23 00:00:00' ),
  ( 12, 'cancel', '2017-07-24 00:00:00' ),
  ( 13, 'create', '2017-07-23 00:00:00' ),
  ( 13, 'pay',    '2017-07-24 00:00:00' ),
  ( 13, 'cancel', '2017-07-25 00:00:00' ),
  ( 13, 'refund', '2017-07-26 00:00:00' );

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(4)=-'
select id, order_id, event from _FSM_.order_events;

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(5)=-'
select time, _FSM_.order_events_fsm(event) over (order by id)
from _FSM_.order_events
where order_id = 3;

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(6)=-'
select
    date::date,
    state,
    count( 1 )
  from
    generate_series( '2017-07-23'::date, '2017-07-26', '1 day' ) as date,
    lateral (
      select
          order_id,
          _FSM_.order_events_fsm( event order by id ) as state
      from _FSM_.order_events
      where time < date + '1 day'::interval
      group by 1
    ) as orders
  group by 1, 2
  order by 1, 2;

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(7)=-'
select * from _FSM_.order_events;

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(8)=-'
create materialized view _FSM_.states as (
  select null::text as state where false  union all
  select 'start'                          union all
  select 'awaiting_payment'               union all
  select 'awaiting_shipment'              union all
  select 'awaiting_refund'                union all
  select 'shipped'                        union all
  select 'canceled'                       union all
  select 'error'
  );

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(9)=-'
create materialized view _FSM_.events as (
  select null::text as event where false  union all
  select 'create'                         union all
  select 'pay'                            union all
  select 'cancel'                         union all
  select 'ship'                           union all
  select 'refund'
  );

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(9)=-'
create materialized view _FSM_.transitions as (
  select null::text as transition where false  union all
  select 'start'                          union all
  select 'awaiting_payment'               union all
  select 'awaiting_shipment'              union all
  select 'awaiting_refund'                union all
  select 'shipped'                        union all
  select 'canceled'                       union all
  select 'error'
  );

-- ---------------------------------------------------------------------------------------------------------
\echo '-=(10)=-'
select
    s.state                                           as state,
    e.event                                           as event,
    _FSM_.order_events_transition( s.state, e.event ) as transition
    -- _FSM_.order_events_transition( s.state, event)
  from
    _FSM_.states      as s,
    _FSM_.events      as e
    -- _FSM_.transitions as t
    ;
\quit

select state, event, _FSM_.order_events_transition(state, event)
from (values
  ('start', 'create'),
  ('awaiting_payment', 'pay'),
  ('awaiting_payment', 'cancel'),
  ('awaiting_payment', 'ship'),
  ('awaiting_shipment', 'ship')
) as examples(state, event);

       state       | event  |    transition
-------------------+--------+-------------------
 start             | create | awaiting_payment
 awaiting_payment  | pay    | awaiting_shipment
 awaiting_payment  | cancel | canceled
 awaiting_shipment | cancel | awaiting_refund
 awaiting_shipment | ship   | shipped
 awaiting_refund   | refund | canceled
 canceled            null     stop
 shipped
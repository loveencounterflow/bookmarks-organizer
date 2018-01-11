
/* thx to http://felixge.de/2017/07/27/implementing-state-machines-in-postgresql.html */

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _FSM2_ cascade;
create schema _FSM2_;

-- ---------------------------------------------------------------------------------------------------------
create table _FSM2_.states (
  state text unique not null primary key );

-- ---------------------------------------------------------------------------------------------------------
create table _FSM2_.acts (
  act text unique not null primary key );

-- ---------------------------------------------------------------------------------------------------------
create table _FSM2_.recipes (
  rcpkey        text unique not null primary key,
  recipe        text );

-- ---------------------------------------------------------------------------------------------------------
create table _FSM2_.transitions (
  tail          text references _FSM2_.states   ( state   ),
  act           text references _FSM2_.acts     ( act     ),
  pre           text references _FSM2_.recipes  ( rcpkey  ),
  point         text references _FSM2_.states   ( state   ),
  primary key ( tail, act ) );

-- ---------------------------------------------------------------------------------------------------------
create table _FSM2_.journal (
  aid       serial    primary key,
  bid       integer   not null,
  act       text      not null,
  data      text );

-- ---------------------------------------------------------------------------------------------------------
create table _FSM2_.registers (
  regkey  text unique not null primary key check ( regkey::U.chr = regkey ),
  name    text unique not null,
  data    text default null );

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT probably better to use domains or other means to ensure integrity */
create function _FSM2_.proceed( ¶tail text, ¶act text ) returns text stable language plpgsql as $$
  declare
    R text;
  begin
    select into R
        point
      from _FSM2_.transitions
      where ( tail = ¶tail ) and ( act = ¶act );
    return R;
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create aggregate _FSM2_.proceed_agg( text ) (
  sfunc     = _FSM2_.proceed,
  stype     = text,
  initcond  = '(start)' );

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT should probably use `lock for update` */
create function _FSM2_.on_before_insert_into_journal() returns trigger language plpgsql as $$
  declare
    ¶new_state  text;
    ¶tail       text;
  begin
    select _FSM2_.proceed_agg( act order by aid )
      from (
        select aid, act from _FSM2_.journal where bid = new.bid union
        select new.aid, new.act ) as s
      into ¶new_state;
    -- .....................................................................................................
    if ¶new_state is null then
      select point
        from _FSM2_._batches_events_and_next_states
        where bid = new.bid
        order by aid desc
        limit 1
        into ¶tail;
      raise exception
        'invalid act: ( state %, act % ) -> null for entry (%)',
          ¶tail, new.act, row_to_json( new );
      end if;
    -- .....................................................................................................
    return new; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create trigger on_before_insert_into_journal before insert on _FSM2_.journal
for each row execute procedure _FSM2_.on_before_insert_into_journal();

-- ---------------------------------------------------------------------------------------------------------
create view _FSM2_._batches_events_and_next_states as ( select
    aid                                                                                 as aid,
    bid                                                                                 as bid,
    act                                                                                 as act,
    _FSM2_.proceed_agg( act ) over ( partition by bid order by aid )                    as point,
    data                                                                                as data
  from _FSM2_.journal );

-- ---------------------------------------------------------------------------------------------------------
create view _FSM2_.job_transitions as ( select
    aid                                                                                 as aid,
    bid                                                                                 as bid,
    coalesce( lag( point ) over ( partition by bid order by aid ), '(start)' )          as tail,
    act                                                                                 as act,
    point                                                                               as point,
    data                                                                                as data
  from _FSM2_._batches_events_and_next_states );


/*

 .d8888b.  888b     d888        d8888 888
d88P  Y88b 8888b   d8888       d88888 888
Y88b.      88888b.d88888      d88P888 888
 "Y888b.   888Y88888P888     d88P 888 888
    "Y88b. 888 Y888P 888    d88P  888 888
      "888 888  Y8P  888   d88P   888 888
Y88b  d88P 888   "   888  d8888888888 888
 "Y8888P"  888       888 d88P     888 88888888

State Machine Assembly Language

LD T    # load data to register T
MV T C  # move contents of register T to register C and set register T to NULL
NL *    # set all registers to NULL
NL Y    # set register Y to NULL

*/

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.LD( ¶aid integer, ¶regkey text ) returns void volatile language sql as $$
  update _FSM2_.registers
    set data = ( select data from _FSM2_.journal where aid = ¶aid )
    where regkey = ¶regkey; $$;



/* ====================================================================================================== */

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM2_.states values
   ( '(start)'    ),
   ( 's1'         ),
   ( 's2'         ),
   ( 's3'         ),
   ( 's4'         ),
   ( 'complete'   );

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM2_.acts values
  ( '!start'          ),
  ( 'identifier'      ),
  ( 'equals'          ),
  ( 'stop!'           );

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM2_.recipes values
  ( 'NOP',   null          ),
  ( 'LD T',  $$_FSM2_.LD( 'T' )$$  );

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM2_.transitions values
  ( '(start)',            '!start',      'NOP',     's1'          ),
  ( 's1',                 'identifier',  'LD T',    's2'          ),
  ( 's2',                 'equals',      'NOP',     's3'          ),
  ( 's3',                 'identifier',  'NOP',     's4'          ),
  ( 's4',                 'stop!',       'NOP',     'complete'    );

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM2_.registers ( regkey, name ) values
  ( 'C', 'context'   ),
  ( 'T', 'tag'       ),
  ( 'V', 'value'     ),
  ( 'Y', 'type'      );


/* ###################################################################################################### */

-- ---------------------------------------------------------------------------------------------------------
-- truncate _FSM2_.journal;
insert into _FSM2_.journal ( bid, act, data ) values ( 1, '!start',      null    );
insert into _FSM2_.journal ( bid, act, data ) values ( 1, 'identifier',  'color' );
insert into _FSM2_.journal ( bid, act, data ) values ( 1, 'equals',      '='     );
insert into _FSM2_.journal ( bid, act, data ) values ( 1, 'identifier',  'red'   );


-- ---------------------------------------------------------------------------------------------------------
\echo 'journal'
select * from _FSM2_.journal;
-- \echo 'transitions'
-- select * from _FSM2_.transitions;
-- \echo '_batches_events_and_next_states'
-- select * from _FSM2_._batches_events_and_next_states;
\echo 'job_transitions'
select * from _FSM2_.job_transitions;

select * from _FSM2_.registers order by regkey;
do $$ begin perform _FSM2_.LD( 3, 'C' ); end; $$;
select * from _FSM2_.registers order by regkey;



-- ---------------------------------------------------------------------------------------------------------



\quit




------------------------------------+------------------------------------------------------------------------
notation                            |  context         tag         value       type
------------------------------------+------------------------------------------------------------------------
IT/programming/language=SQL::name   |  IT/programming  language    SQL         name
foo::q                              |  ∎               foo         ∎           q





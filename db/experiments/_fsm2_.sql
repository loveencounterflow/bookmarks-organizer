
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

-- -- ---------------------------------------------------------------------------------------------------------
-- create table _FSM2_.recipes (
--   rcpkey        text unique not null primary key,
--   recipe        text );

-- ---------------------------------------------------------------------------------------------------------
create table _FSM2_.transitions (
  tail          text                    references _FSM2_.states    ( state   ),
  act           text                    references _FSM2_.acts      ( act     ),
  precmd        text,                    -- references _FSM2_.recipes   ( rcpkey  ),
  point         text                    references _FSM2_.states    ( state   ),
  primary key ( tail, act ) );

-- ---------------------------------------------------------------------------------------------------------
create table _FSM2_.journal (
  aid           serial    primary key,
  bid           integer   not null,
  tail          text                    references _FSM2_.states    ( state   ),
  act           text      not null      references _FSM2_.acts      ( act     ),
  point         text                    references _FSM2_.states    ( state   ),
  data          text,
  registers     json );

-- ---------------------------------------------------------------------------------------------------------
create view _FSM2_.receiver as ( select
    bid,
    act,
    data
  from _FSM2_.journal );

-- ---------------------------------------------------------------------------------------------------------
create table _FSM2_.registers (
  regkey  text unique not null primary key check ( regkey::U.chr = regkey ),
  name    text unique not null,
  data    text default null );

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.registers_as_json() returns json stable language sql as $$
  with  keys    as ( select array_agg( regkey order by regkey ) as x from _FSM2_.registers ),
        values  as ( select array_agg( data   order by regkey ) as x from _FSM2_.registers )
    select json_object( keys.x, values.x ) from keys, values; $$;

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.proceed2( ¶tail text, ¶act text ) returns _FSM2_.transitions stable language sql as $$
  select * from _FSM2_.transitions where ( tail = ¶tail ) and ( act = ¶act ); $$;

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT should probably use `lock for update` */
create function _FSM2_.instead_of_insert_into_receiver() returns trigger language plpgsql as $$
  declare
    ¶new_state  text;
    ¶tail       text;
    ¶aid        integer;
    ¶transition _FSM2_.transitions%rowtype;
    X text;
  begin
    -- .....................................................................................................
    if new.act = '!start' then
      if exists ( select 1 from _FSM2_.journal where bid = new.bid ) then
        raise exception 'batch with BatchID % already exists', new.bid;
        end if;
      end if;
    -- -- .....................................................................................................
    -- if ¶new_state is null then
    --   select point
    --     from _FSM2_._batches_events_and_next_states
    --     where bid = new.bid
    --     order by aid desc
    --     limit 1
    --     into ¶tail;
    --   raise exception
    --     'invalid act: ( state %, act % ) -> null for entry (%)',
    --       ¶tail, new.act, row_to_json( new );
    --   end if;
    -- .....................................................................................................
    if new.act = '!start' then
      ¶tail := '(start)';
    else
      select into ¶tail
          point as tail
        from _FSM2_.journal
        where bid = new.bid
        order by aid desc
        limit 1;
      end if;
    -- .....................................................................................................
    /* Perform associated SMAL commands: */
    perform log( '00902', 'tail', ¶tail );
    ¶transition :=  _FSM2_.proceed2( ¶tail, new.act );
    X := json_agg( t )::text from ( select ¶transition ) as t;
    perform log( '00902', 'transition', X );
    perform _FSM2_.smal( ¶transition.precmd, new.data );
    -- .....................................................................................................
    /* Insert new line into journal and update register copy: */
    insert into _FSM2_.journal ( bid, tail, act, point, data ) values
      ( new.bid, ¶tail, new.act, ¶transition.point, new.data )
      returning aid into ¶aid;
    -- .....................................................................................................
    update _FSM2_.journal set registers = _FSM2_.registers_as_json() where aid = ¶aid;
    -- .....................................................................................................
    return null; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create trigger instead_of_insert_into_receiver instead of insert on _FSM2_.receiver
for each row execute procedure _FSM2_.instead_of_insert_into_receiver();

-- -- ---------------------------------------------------------------------------------------------------------
-- create view _FSM2_._batches_events_and_next_states as ( select
--     aid                                                                                 as aid,
--     bid                                                                                 as bid,
--     act                                                                                 as act,
--     _FSM2_.proceed_agg( act ) over ( partition by bid order by aid )                    as point,
--     data                                                                                as data
--   from _FSM2_.journal );

-- -- ---------------------------------------------------------------------------------------------------------
-- create view _FSM2_.job_transitions as ( select
--     aid                                                                                 as aid,
--     bid                                                                                 as bid,
--     coalesce( lag( point ) over ( partition by bid order by aid ), '(start)' )          as tail,
--     act                                                                                 as act,
--     point                                                                               as point,
--     data                                                                                as data
--   from _FSM2_._batches_events_and_next_states );


/*

███████╗███╗   ███╗ █████╗ ██╗
██╔════╝████╗ ████║██╔══██╗██║
███████╗██╔████╔██║███████║██║
╚════██║██║╚██╔╝██║██╔══██║██║
███████║██║ ╚═╝ ██║██║  ██║███████╗
╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝ http://www.patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=SmAL

State Machine Assembly Language

LD T    # load data to register T
MV T C  # move contents of register T to register C and set register T to NULL
NL *    # set all registers to NULL
NL Y    # set register Y to NULL

*/

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.smal( ¶cmd text, ¶data text ) returns void volatile strict language plpgsql as $$
  declare
    ¶parts  text[];
    ¶base   text;
    ¶regkey text;
  begin
    if ¶cmd is null then return; end if;
    if ¶cmd = 'NOP' then return; end if;
    ¶cmd    :=  trim( both from ¶cmd );
    ¶parts  :=  regexp_split_to_array( ¶cmd, '\s+' );
    ¶base   :=  ¶parts[ 1 ];
    case ¶base
      when 'LD' then
        ¶regkey :=  ¶parts[ 2 ];
        update _FSM2_.registers
          set data = ¶data
          where regkey = ¶regkey;
      end case;
    end; $$;



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

-- -- ---------------------------------------------------------------------------------------------------------
-- insert into _FSM2_.recipes values
--   ( 'NOP',   null          ),
--   ( 'LD T',  $$_FSM2_.LD( 'T' )$$  );

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM2_.transitions
  ( tail,                 act,            precmd,   point         ) values
  ( '(start)',            '!start',       'NOP',    's1'          ),
  ( 's1',                 'identifier',   'LD T',   's2'          ),
  ( 's2',                 'equals',       'NOP',    's3'          ),
  ( 's3',                 'identifier',   'NOP',    's4'          ),
  ( 's4',                 'stop!',        'NOP',    'complete'    );

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM2_.registers ( regkey, name ) values
  ( 'C', 'context'   ),
  ( 'T', 'tag'       ),
  ( 'V', 'value'     ),
  ( 'Y', 'type'      );


/* ###################################################################################################### */

-- ---------------------------------------------------------------------------------------------------------
-- truncate _FSM2_.journal;
insert into _FSM2_.receiver values ( 1, '!start',      null    );
insert into _FSM2_.receiver values ( 1, 'identifier',  'color' );
insert into _FSM2_.receiver values ( 1, 'equals',      '='     );
-- insert into _FSM2_.receiver values ( 1, 'equals',      '='     );
insert into _FSM2_.receiver values ( 1, 'identifier',  'red'   );


-- ---------------------------------------------------------------------------------------------------------
\echo 'journal'
select * from _FSM2_.journal;
-- \echo 'transitions'
-- select * from _FSM2_.transitions;
-- \echo '_batches_events_and_next_states'
-- select * from _FSM2_._batches_events_and_next_states;
-- \echo 'job_transitions'
-- select * from _FSM2_.job_transitions;

\quit

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




\quit


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


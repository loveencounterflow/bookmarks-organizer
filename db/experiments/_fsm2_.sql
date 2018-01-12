
/* thx to http://felixge.de/2017/07/27/implementing-state-machines-in-postgresql.html */


/*

███████╗███████╗███╗   ███╗
██╔════╝██╔════╝████╗ ████║
█████╗  ███████╗██╔████╔██║
██╔══╝  ╚════██║██║╚██╔╝██║
██║     ███████║██║ ╚═╝ ██║
╚═╝     ╚══════╝╚═╝     ╚═╝

*/


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
  precmd        text,
  point         text                    references _FSM2_.states    ( state   ),
  postcmd       text,
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
create function _FSM2_.proceed( ¶tail text, ¶act text ) returns _FSM2_.transitions stable language sql as $$
  select * from _FSM2_.transitions where ( tail = ¶tail ) and ( act = ¶act ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_._journal_excerpt_as_tabular( ¶bid integer ) returns text
  immutable strict language plpgsql as $$
  declare
    excerpt json;
  begin
    /* thx to https://stackoverflow.com/a/39456483/7568091 */
    select into excerpt
           '[["aid","bid","tail","act","point","data","registers"]]'::jsonb ||  -- !!!!
        jsonb_agg( info ) from (
          select jsonb_build_array(
            aid, bid, tail, act, point, data, registers                         -- !!!!
            ) as info from ( select
            aid, bid, tail, act, point, data, registers                         -- !!!!
            from _FSM2_.journal where bid = ¶bid order by aid ) as x1 ) as x2;
    return U.tabulate( excerpt );
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT should probably use `lock for update` */
create function _FSM2_.instead_of_insert_into_receiver() returns trigger language plpgsql as $$
  declare
    ¶new_state  text;
    ¶tail       text;
    ¶aid        integer;
    ¶transition _FSM2_.transitions%rowtype;
    -- X text;
  begin
    -- .....................................................................................................
    if new.act = '!start' then
      if exists ( select 1 from _FSM2_.journal where bid = new.bid ) then
        raise exception 'batch with BatchID % already exists', new.bid;
        end if;
      ¶tail := '(start)';
    -- .....................................................................................................
    else
      /* ### TAINT consider to use lag() instead */
      select into ¶tail point from _FSM2_.journal where bid = new.bid order by aid desc limit 1;
      end if;
    -- .....................................................................................................
    /* Obtain transition from tail and act: */
    ¶transition :=  _FSM2_.proceed( ¶tail, new.act );
    -- .....................................................................................................
    /* Error out in case no matching transition was found: */
    if ¶transition is null then
      perform log( '19088', 'Journal excerpt up to problematic act:' );
      perform log( _FSM2_._journal_excerpt_as_tabular( new.bid ) );
      raise exception
        'invalid act: ( state %, act % ) -> null for entry (%)',
          ¶tail, new.act, row_to_json( new );
      end if;
    -- .....................................................................................................
    /* Perform associated SMAL pre-update commands: */
    -- X := json_agg( t )::text from ( select ¶transition ) as t; perform log( '00902', 'transition', X );
    perform _FSM2_.smal( ¶transition.precmd, new.data );
    -- .....................................................................................................
    /* Insert new line into journal and update register copy: */
    insert into _FSM2_.journal ( bid, tail, act, point, data ) values
      ( new.bid, ¶tail, new.act, ¶transition.point, new.data )
      returning aid into ¶aid;
    -- .....................................................................................................
    /* Perform associated SMAL post-update commands: */
    perform _FSM2_.smal( ¶transition.postcmd, new.data );
    -- .....................................................................................................
    update _FSM2_.journal set registers = _FSM2_.registers_as_json() where aid = ¶aid;
    -- .....................................................................................................
    return null; end; $$;

    -- perform log( '00902', 'tail', ¶tail );

-- ---------------------------------------------------------------------------------------------------------
create trigger instead_of_insert_into_receiver instead of insert on _FSM2_.receiver
for each row execute procedure _FSM2_.instead_of_insert_into_receiver();


/*

███████╗███╗   ███╗ █████╗ ██╗
██╔════╝████╗ ████║██╔══██╗██║
███████╗██╔████╔██║███████║██║
╚════██║██║╚██╔╝██║██╔══██║██║
███████║██║ ╚═╝ ██║██║  ██║███████╗
╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝ http://www.patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=SMAL

State Machine Assembly Language

NOP       # no operation (may also use SQL `null` value)
LOD T     # load data to register T
MOV T C   # move contents of register T to register C and set register T to NULL
NUL *     # set all registers to NULL
NUL Y     # set register Y to NULL

*/

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.smal( ¶cmd text, ¶data text ) returns void volatile language plpgsql as $$
  declare
    ¶parts      text[];
    ¶base       text;
    ¶regkey_1   text;
    ¶regkey_2   text;
    ¶count      integer := 0;
  begin
    if ¶cmd is null then return; end if;
    /* ### TAINT should check whether there are extraneous arguments with NOP */
    if ¶cmd = 'NOP' then return; end if;
    ¶cmd    :=  trim( both from ¶cmd );
    ¶parts  :=  regexp_split_to_array( ¶cmd, '\s+' );
    ¶base   :=  ¶parts[ 1 ];
    -- .....................................................................................................
    <<on_count_null>> begin case ¶base
      -- ...................................................................................................
      when 'NUL' then
        ¶regkey_1 :=  ¶parts[ 2 ];
        if ¶regkey_1 = '*' then
          update _FSM2_.registers set data = null;
        else
          update _FSM2_.registers set data = null where regkey = ¶regkey_1 returning 1 into ¶count;
          end if;
      -- ...................................................................................................
      when 'LOD' then
        ¶regkey_1 :=  ¶parts[ 2 ];
        update _FSM2_.registers set data = ¶data where regkey = ¶regkey_1 returning 1 into ¶count;
      -- ...................................................................................................
      when 'MOV' then
        ¶regkey_1 :=  ¶parts[ 2 ];
        ¶regkey_2 :=  ¶parts[ 3 ];
        update _FSM2_.registers
          set data = r1.data from ( select data from _FSM2_.registers where regkey = ¶regkey_1 ) as r1
          where regkey = ¶regkey_2 returning 1 into ¶count;
        exit on_count_null when ¶count is null;
        update _FSM2_.registers set data = null where regkey = ¶regkey_1 returning 1 into ¶count;
      -- ...................................................................................................
      end case; end;
    -- .....................................................................................................
    if ¶count is null then
      raise exception 'invalid regkey in %', ¶cmd;
      end if;
    -- .....................................................................................................
    end; $$;



/* ====================================================================================================== */

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM2_.states values
   ( '(start)'    ),
   ( 's1'         ),
   ( 's2'         ),
   ( 's3'         ),
   ( 's4'         ),
   ( 's5'         ),
   ( 'complete'   );

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM2_.acts values
  ( '!start'          ),
  ( 'identifier'      ),
  ( 'equals'          ),
  ( 'dcolon'          ),
  ( 'stop!'           );

-- -- ---------------------------------------------------------------------------------------------------------
-- insert into _FSM2_.recipes values
--   ( 'NOP',   null          ),
--   ( 'LOD T',  $$_FSM2_.LOD( 'T' )$$  );

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM2_.transitions
  ( tail,                 act,            precmd,   point,      postcmd       ) values
  ( '(start)',            '!start',       'NUL *',  's1',       'NOP'         ),
  ( 's1',                 'identifier',   'NOP',    's2',       'LOD T'       ),
  ( 's2',                 'equals',       'NOP',    's3',       'NOP'         ),
  ( 's3',                 'identifier',   'NOP',    's4',       'LOD V'       ),
  ( 's4',                 'dcolon',       'NOP',    's5',       'NOP'         ),
  ( 's5',                 'identifier',   'NOP',    's5',       'LOD Y'       ),
  ( 's4',                 'stop!',        'NOP',    'complete', 'NOP'         );

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

insert into _FSM2_.receiver values ( 2, '!start',      null    );
insert into _FSM2_.receiver values ( 2, 'identifier',  'foo'    );
insert into _FSM2_.receiver values ( 2, 'equals',      '::'   );
-- insert into _FSM2_.receiver values ( 2, 'equals',      '='     );
insert into _FSM2_.receiver values ( 2, 'identifier',  'q'   );

insert into _FSM2_.receiver values ( 3, '!start',      null    );
insert into _FSM2_.receiver values ( 3, 'identifier',  'author'    );
insert into _FSM2_.receiver values ( 3, 'equals',      '='     );
insert into _FSM2_.receiver values ( 3, 'identifier',  'Faulkner'    );
insert into _FSM2_.receiver values ( 3, 'dcolon',      '::'   );
-- insert into _FSM2_.receiver values ( 3, 'equals',      '='     );
insert into _FSM2_.receiver values ( 3, 'identifier',  'name'   );


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
do $$ begin perform _FSM2_.LOD( 3, 'C' ); end; $$;
select * from _FSM2_.registers order by regkey;



-- ---------------------------------------------------------------------------------------------------------



\quit




------------------------------------+------------------------------------------------------------------------
notation                            |  context          tag         value       type
------------------------------------+------------------------------------------------------------------------
color=red                           |  ∎                color       red         ∎
IT/programming/language=SQL::name   |  IT/programming   language    SQL         name
foo::q                              |  ∎                foo         ∎           q




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




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

-- ---------------------------------------------------------------------------------------------------------
create table _FSM2_.transitions (
  tail          text                    references _FSM2_.states    ( state   ),
  act           text                    references _FSM2_.acts      ( act     ),
  precmd        text,
  point         text                    references _FSM2_.states    ( state   ),
  postcmd       text,
  primary key ( tail, act ) );

-- -- ---------------------------------------------------------------------------------------------------------
create function _FSM2_._act_is_starred( ¶act text ) returns boolean stable language sql as $$
  select exists ( select 1 from _FSM2_.transitions where act = ¶act and tail = '*' ); $$;

-- -- ---------------------------------------------------------------------------------------------------------
create function _FSM2_._star_count_ok( ¶tail text, ¶act text ) returns boolean volatile language sql as $$
  select case when ¶tail = '*' or _FSM2_._act_is_starred( ¶act ) then
    ( select count(*) = 0 from _FSM2_.transitions where act = ¶act )
    else true end; $$;

-- ---------------------------------------------------------------------------------------------------------
alter table _FSM2_.transitions
  add constraint "starred acts must have no more than one transition"
  check ( _FSM2_._star_count_ok( tail, act ) );

-- ---------------------------------------------------------------------------------------------------------
create table _FSM2_.journal (
  aid           serial    primary key,
  tail          text                    references _FSM2_.states    ( state   ),
  act           text      not null      references _FSM2_.acts      ( act     ),
  point         text                    references _FSM2_.states    ( state   ),
  data          text,
  registers     json );

-- ---------------------------------------------------------------------------------------------------------
create view _FSM2_.receiver as ( select
    act,
    data
  from _FSM2_.journal
  order by aid );

-- ---------------------------------------------------------------------------------------------------------
create table _FSM2_.registers (
  regkey  text unique not null primary key check ( regkey::U.chr = regkey ),
  name    text unique not null,
  data    text default null );

create function _FSM2_._on_before_insert_into_registers() returns trigger volatile language plpgsql as $outer$
  declare
    ¶q  text;
  begin
    perform log( '44090', new::text );
    execute format( $$ alter table _FSM2_.journal
      add column %I text; $$, new.regkey );
    return new;
    end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create trigger on_before_insert_into_registers before insert on _FSM2_.registers
for each row execute procedure _FSM2_._on_before_insert_into_registers();

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.registers_as_json() returns json stable language sql as $$
  with  keys    as ( select array_agg( regkey order by regkey ) as x from _FSM2_.registers ),
        values  as ( select array_agg( data   order by regkey ) as x from _FSM2_.registers )
    select json_object( keys.x, values.x ) from keys, values; $$;

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.proceed( ¶tail text, ¶act text ) returns _FSM2_.transitions stable language sql as $$
  select * from _FSM2_.transitions where ( tail = ¶tail ) and ( act = ¶act ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_._journal_as_tabular() returns text
  immutable strict language sql as $outer$
    select U.tabulate_query( $$ select * from _FSM2_.journal order by aid; $$ );
    $outer$;

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
    if _FSM2_._act_is_starred( new.act ) then
      perform log( '77981', 'act', new.act, 'is a star' );
      ¶tail := '*';
    -- .....................................................................................................
    else
      /* ### TAINT consider to use lag() instead */
      select into ¶tail point from _FSM2_.journal order by aid desc limit 1;
      end if;
    -- .....................................................................................................
    /* Obtain transition from tail and act: */
    ¶transition :=  _FSM2_.proceed( ¶tail, new.act );
    -- .....................................................................................................
    /* Error out in case no matching transition was found: */
    if ¶transition is null then
      perform log( '19088', 'Journal up to problematic act:' );
      perform log( _FSM2_._journal_as_tabular() );
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
    insert into _FSM2_.journal ( tail, act, point, data ) values
      ( ¶tail, new.act, ¶transition.point, new.data )
      returning aid into ¶aid;
    perform _FSM2_._smal_cpy();
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
create function _FSM2_._smal_get_current_aid() returns integer stable language sql as $$
  select max( aid ) from _FSM2_.journal; $$;

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT functions that use registers should be compiled once before first use */
/* ### TAINT inefficient; could be single statement instead of loop */
create function _FSM2_._smal_cpy() returns void volatile language plpgsql as $outer$
  declare
    ¶aid  integer := _FSM2_._smal_get_current_aid();
    ¶row  record;
  -- .......................................................................................................
  begin
    if ( select count(*) from _FSM2_.journal limit 2 ) < 2 then return; end if;
    for ¶row in ( select * from _FSM2_.registers ) loop
      execute format( $$
          with prv_row as ( select %I from _FSM2_.journal where aid = $1 - 1 )
          update _FSM2_.journal
          set %I = prv_row.%I
          from prv_row
          where aid = $2;
        $$, ¶row.regkey, ¶row.regkey, ¶row.regkey )
        using ¶aid, ¶aid;
      end loop;
    end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT functions that use registers should be compiled once before first use */
create function _FSM2_._smal_lod( ¶regkey text, ¶data text ) returns void volatile language plpgsql as $outer$
  declare
    ¶aid  integer := _FSM2_._smal_get_current_aid();
    ¶row  record;
  -- .......................................................................................................
  begin
    -- .....................................................................................................
    /* set ¶data to all registers when key is star: */
    if ¶regkey = '*' then
      for ¶row in ( select * from _FSM2_.registers ) loop
        execute format(
          $$ update _FSM2_.journal set %I = null where aid = $1; $$, ¶row.regkey )
          using ¶aid;
        end loop;
    -- .....................................................................................................
    else
      execute format(
        $$ update _FSM2_.journal set %I = $1 where aid = $2; $$, ¶regkey )
        using ¶data, ¶aid;
      end if;
    -- .....................................................................................................
    end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.smal( ¶cmd text, ¶data text ) returns void volatile language plpgsql as $outer$
  declare
    ¶parts      text[];
    ¶base       text;
    ¶regkey_1   text;
    ¶regkey_2   text;
    ¶count      integer :=  0;
    ¶next_cmd   text    :=  null;
  -- .......................................................................................................
  begin
    -- .....................................................................................................
    loop
      -- ...................................................................................................
      if ¶next_cmd is not null then
        ¶cmd      :=  ¶next_cmd;
        ¶next_cmd :=  null;
      elsif ¶cmd is null then
        return;
        end if;
      -- ...................................................................................................
      /* ### TAINT should check whether there are extraneous arguments with NOP */
      if ¶cmd = 'NOP' then return; end if;
      ¶cmd    :=  trim( both from ¶cmd );
      ¶parts  :=  regexp_split_to_array( ¶cmd, '\s+' );
      ¶base   :=  ¶parts[ 1 ];
      -- ...................................................................................................
      <<on_count_null>> begin case ¶base
        -- .................................................................................................
        when 'CLR' then
          truncate table _FSM2_.journal;
          ¶next_cmd := 'NUL *';
        -- .................................................................................................
        when 'NUL' then
          ¶regkey_1 := ¶parts[ 2 ];
          if ¶regkey_1 = '*' then
            update _FSM2_.registers set data = null;
            perform _FSM2_._smal_lod( '*', null );
          else
            update _FSM2_.registers set data = null where regkey = ¶regkey_1 returning 1 into ¶count;
            end if;
        -- .................................................................................................
        when 'LOD' then
          ¶regkey_1 :=  ¶parts[ 2 ];
          update _FSM2_.registers set data = ¶data where regkey = ¶regkey_1 returning 1 into ¶count;
          perform _FSM2_._smal_lod( ¶regkey_1, ¶data );
        -- .................................................................................................
        when 'MOV' then
          ¶regkey_1 :=  ¶parts[ 2 ];
          ¶regkey_2 :=  ¶parts[ 3 ];
          update _FSM2_.registers
            set data = r1.data from ( select data from _FSM2_.registers where regkey = ¶regkey_1 ) as r1
            where regkey = ¶regkey_2 returning 1 into ¶count;
          exit on_count_null when ¶count is null;
          update _FSM2_.registers set data = null where regkey = ¶regkey_1 returning 1 into ¶count;
        -- .................................................................................................
        else raise exception 'unknown command %', ¶cmd;
        end case; end;
      -- ...................................................................................................
      if ¶count is null then raise exception 'invalid regkey in %', ¶cmd; end if;
      exit when ¶next_cmd is null;
      end loop;
    end; $outer$;



/* ====================================================================================================== */

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM2_.states values
   ( '*'          ),
   ( 'FIRST'      ),
   ( 's1'         ),
   ( 's2'         ),
   ( 's3'         ),
   ( 's4'         ),
   ( 's5'         ),
   ( 'LAST'       );

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM2_.acts values
  ( 'CLEAR'           ),
  ( 'START'           ),
  ( 'identifier'      ),
  ( 'equals'          ),
  ( 'dcolon'          ),
  ( 'RESET'           ),
  ( 'STOP'            );

-- ---------------------------------------------------------------------------------------------------------
insert into _FSM2_.transitions
  ( tail,                 act,                precmd,       point,          postcmd           ) values
  ( '*',                  'RESET',            'CLR',        'FIRST',        'NOP'             ),
  ( 'LAST',               'CLEAR',            'CLR',        'FIRST',        'NOP'             ),
  ( 'FIRST',              'START',            'NUL *',      's1',           'NOP'             ),
  ( 's1',                 'identifier',       'NOP',        's2',           'LOD T'           ),
  ( 's2',                 'equals',           'NOP',        's3',           'NOP'             ),
  ( 's3',                 'identifier',       'NOP',        's4',           'LOD V'           ),
  ( 's4',                 'dcolon',           'NOP',        's5',           'NOP'             ),
  ( 's5',                 'identifier',       'NOP',        's5',           'LOD Y'           ),
  ( 's1',                 'STOP',             'NOP',        'LAST',         'NOP'             ),
  ( 's5',                 'STOP',             'NOP',        'LAST',         'NOP'             ),
  ( 's4',                 'STOP',             'NOP',        'LAST',         'NOP'             );


-- ---------------------------------------------------------------------------------------------------------
insert into _FSM2_.registers ( regkey, name ) values
  ( 'C', 'context'   ),
  ( 'T', 'tag'       ),
  ( 'V', 'value'     ),
  ( 'Y', 'type'      );


/* ###################################################################################################### */

-- select array_agg( tail ) as "start" from _FSM2_.transitions where act = 'START';
-- select array_agg( tail ) as "stop"  from _FSM2_.transitions where act = 'STOP';
-- select array_agg( tail ) as "reset" from _FSM2_.transitions where act = 'RESET';
-- select array_agg( tail ) as "clear" from _FSM2_.transitions where act = 'CLEAR';
-- select exists ( select 1 from _FSM2_.transitions where act = 'RESET' and tail = '*' );
-- select exists ( select 1 from _FSM2_.transitions where act = 'CLEAR' and tail = '*' );

-- \quit

-- ---------------------------------------------------------------------------------------------------------
-- truncate _FSM2_.journal;
insert into _FSM2_.receiver values ( 'RESET'                      );
insert into _FSM2_.receiver values ( 'START'                      );
insert into _FSM2_.receiver values ( 'identifier',  'color'       );
insert into _FSM2_.receiver values ( 'equals',      '='           );
-- insert into _FSM2_.receiver values ( 'equals',      '='          );
-- insert into _FSM2_.receiver values ( 'START',      null           );
insert into _FSM2_.receiver values ( 'identifier',  'red'         );
insert into _FSM2_.receiver values ( 'STOP'                       );
select * from _FSM2_.journal;
-- select registers from _FSM2_.journal where point = 'LAST';
-- insert into _FSM2_.receiver values ( 'CLEAR'                      );

-- \quit


insert into _FSM2_.receiver values ( 'RESET'                      );
insert into _FSM2_.receiver values ( 'START'                      );
-- insert into _FSM2_.receiver values ( 'STOP'                      );
insert into _FSM2_.receiver values ( 'identifier',  'foo'         );
insert into _FSM2_.receiver values ( 'equals',      '::'          );
-- insert into _FSM2_.receiver values ( 'equals',      '='          );
insert into _FSM2_.receiver values ( 'identifier',  'q'           );
insert into _FSM2_.receiver values ( 'STOP'                       );
select * from _FSM2_.journal;

insert into _FSM2_.receiver values ( 'CLEAR'                      );
insert into _FSM2_.receiver values ( 'START'                      );
insert into _FSM2_.receiver values ( 'identifier',  'author'      );
insert into _FSM2_.receiver values ( 'equals',      '='           );
insert into _FSM2_.receiver values ( 'identifier',  'Faulkner'    );
insert into _FSM2_.receiver values ( 'dcolon',      '::'          );
insert into _FSM2_.receiver values ( 'identifier',  'name'        );
insert into _FSM2_.receiver values ( 'STOP'                       );
-- insert into _FSM2_.receiver values ( 'equals',      '='          );
select * from _FSM2_.journal;

\quit

-- ---------------------------------------------------------------------------------------------------------
\echo 'journal'
select * from _FSM2_.journal;
\echo 'journal (completed)'
select * from _FSM2_.journal where point = 'LAST';
-- select * from _FSM2_.receiver;
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
  initcond  = 'FIRST' );


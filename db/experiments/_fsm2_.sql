






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
create table _FSM2_.raw_journal (
  aid           serial    primary key,
  tail          text                    references _FSM2_.states    ( state   ),
  act           text      not null      references _FSM2_.acts      ( act     ),
  point         text                    references _FSM2_.states    ( state   ),
  data          jsonb,
  registers     jsonb );

-- ---------------------------------------------------------------------------------------------------------
create view _FSM2_.raw_result as ( select * from _FSM2_.raw_journal where point = 'LAST' );

-- ---------------------------------------------------------------------------------------------------------
create table _FSM2_.registers (
  id      serial,
  regkey  text unique not null primary key check ( regkey::U.chr = regkey ),
  name    text unique not null,
  data    jsonb );

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.registers_as_jsonb() returns jsonb stable language sql as $$
  select jsonb_agg( r.data order by id ) from _FSM2_.registers as r; $$;

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.get_current_aid() returns integer stable language sql as $$
  select max( aid ) from _FSM2_.raw_journal; $$;

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.proceed( ¶tail text, ¶act text ) returns _FSM2_.transitions stable language sql as $$
  select * from _FSM2_.transitions where ( tail = ¶tail ) and ( act = ¶act ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_._get_create_journal_statement() returns text volatile language plpgsql as $outer$
  declare
    R         text;
    ¶names    text[];
    ¶row      record;
  begin
    R := '
      create view _FSM2_.journal as ( select
          j1.aid      as aid,
          j1.tail     as tail,
          j1.act      as act,
          j1.point    as point,
          j1.data     as data,
          ';
    select array_agg( format( 'j2.%I', regkey ) order by id ) from _FSM2_.registers into ¶names;
    R := R || array_to_string( ¶names, ', ' );
    R := R || E'\n        from _FSM2_.raw_journal as j1
      left join ( select
        aid,
        ';
    select array_agg( format( 'registers->>%s as %I', id, regkey ) order by id ) from _FSM2_.registers into ¶names;
    R := R || array_to_string( ¶names, ', ' );
    R := R || E'\n        from _FSM2_.raw_journal ) as j2 using ( aid ) );';
    return R;
    end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.create_journal() returns void volatile language plpgsql as $outer$
  begin
    drop view if exists _FSM2_.journal; -- cascade???
    drop view if exists _FSM2_.result; -- cascade???
    execute _FSM2_._get_create_journal_statement();
    create view _FSM2_.result as ( select * from _FSM2_.journal where point = 'LAST' );
    end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_._journal_as_tabular() returns text
  immutable strict language sql as $outer$
    select U.tabulate_query( $$ select * from _FSM2_.journal order by aid; $$ );
    $outer$;

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT should probably use `lock for update` */
create function _FSM2_.step( ¶act text, ¶data jsonb ) returns void volatile language plpgsql as $$
  declare
    ¶new_state  text;
    ¶tail       text;
    ¶aid        integer;
    ¶transition _FSM2_.transitions%rowtype;
    -- X text;
  -- .......................................................................................................
  begin
    /* ### TAINT rewrite this as
      ¶transition :=  _FSM2_.proceed( '*', ¶act );
      if ¶transition is null then ...
    */
    if _FSM2_._act_is_starred( ¶act ) then
      /* Starred acts always succeed, even on an empty raw_journal where there is no previous act and, thus, no
      tail; when can therefore always set the tail to '*'. */
      ¶tail := '*';
    -- .....................................................................................................
    else
      /* ### TAINT consider to use lag() instead */
      select into ¶tail point from _FSM2_.raw_journal order by aid desc limit 1;
      end if;
    -- .....................................................................................................
    /* Obtain transition from tail and act: */
    ¶transition :=  _FSM2_.proceed( ¶tail, ¶act );
    -- .....................................................................................................
    /* Error out in case no matching transition was found: */
    if ¶transition is null then
      perform log( '19088', 'Journal up to problematic act:' );
      perform log( _FSM2_._journal_as_tabular() );
      raise exception
        'invalid act: { state: %, act: %, data: %, } -> null',
          ¶tail, ¶act, ¶data;
      end if;
    -- .....................................................................................................
    /* Perform associated SMAL pre-update commands: */
    -- X := json_agg( t )::text from ( select ¶transition ) as t; perform log( '00902', 'transition', X );
    perform _FSM2_.smal( ¶transition.precmd, ¶data );
    -- .....................................................................................................
    /* Insert new line into raw_journal and update register copy: */
    insert into _FSM2_.raw_journal ( tail, act, point, data ) values
      ( ¶tail, ¶act, ¶transition.point, ¶data )
      returning aid into ¶aid;
    -- perform _FSM2_._smal_cpy();
    -- .....................................................................................................
    /* Perform associated SMAL post-update commands: */
    perform _FSM2_.smal( ¶transition.postcmd, ¶data );
    -- .....................................................................................................
    /* Reflect state of registers table into `raw_journal ( registers )`: */
    update _FSM2_.raw_journal set registers = _FSM2_.registers_as_jsonb() where aid = ¶aid;
    -- .....................................................................................................
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.step( ¶act text, ¶data text ) returns void volatile language sql as $$
  select _FSM2_.step( ¶act, jb( ¶data ) ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.step( ¶act text, ¶data anyelement ) returns void volatile language sql as $$
  select _FSM2_.step( ¶act, jb( ¶data ) ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.step( ¶act text ) returns void volatile language sql as $$
  select _FSM2_.step( ¶act, jb( null ) ); $$;



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
/* ### TAINT functions that use registers should be compiled once before first use */
/* ### TAINT inefficient; could be single statement instead of loop */
/*
create function _FSM2_._smal_cpy() returns void volatile language plpgsql as $outer$
  declare
    ¶aid  integer := _FSM2_.get_current_aid();
    ¶row  record;
  -- .......................................................................................................
  begin
    if ( select count(*) from _FSM2_.raw_journal limit 2 ) < 2 then return; end if;
    for ¶row in ( select * from _FSM2_.registers ) loop
      execute format( $$
          with prv_row as ( select %I from _FSM2_.raw_journal where aid = $1 - 1 )
          update _FSM2_.raw_journal
          set %I = prv_row.%I
          from prv_row
          where aid = $2;
        $$, ¶row.regkey, ¶row.regkey, ¶row.regkey )
        using ¶aid, ¶aid;
      end loop;
    end; $outer$;
*/

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_._smal_lod( ¶cmd_parts text[], ¶data jsonb ) returns text volatile language plpgsql as $$
  declare
    ¶count        integer :=  0;
    ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
  begin
    -- ¶regkey_1 := ¶cmd_parts[ 2 ];
    update _FSM2_.registers
      set data = to_jsonb( ¶data )
      where regkey = ¶regkey_1 returning 1 into ¶count;
    return null; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function _FSM2_.smal( ¶cmd text, ¶data jsonb ) returns void volatile language plpgsql as $outer$
  declare
    ¶cmd_parts    text[];
    ¶base         text;
    ¶regkey_1     text;
    ¶regkey_2     text;
    ¶count        integer :=  0;
    ¶next_cmd     text    :=  null;
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
      ¶cmd        :=  trim( both from ¶cmd );
      ¶cmd_parts  :=  regexp_split_to_array( ¶cmd, '\s+' );
      ¶base       :=  ¶cmd_parts[ 1 ];
      -- ...................................................................................................
      <<on_count_null>> begin case ¶base
        -- .................................................................................................
        when 'CLR' then
          truncate table _FSM2_.raw_journal;
          ¶next_cmd := 'NUL *';
        -- .................................................................................................
        when 'NUL' then
          ¶regkey_1 := ¶cmd_parts[ 2 ];
          if ¶regkey_1 = '*' then
            update _FSM2_.registers set data = null;
            -- perform _FSM2_._smal_lod( '*', null );
          else
            update _FSM2_.registers set data = null where regkey = ¶regkey_1 returning 1 into ¶count;
            end if;
        -- .................................................................................................
        when 'LOD' then ¶next_cmd := _FSM2_._smal_lod( ¶cmd_parts, ¶data );
        -- .................................................................................................
        when 'MOV' then
          ¶regkey_1 :=  ¶cmd_parts[ 2 ];
          ¶regkey_2 :=  ¶cmd_parts[ 3 ];
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
  ( 'slash'           ),
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

  ( 's2',                 'slash',            'MOV T C',      's1',           'NOP'             ),

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

-- ---------------------------------------------------------------------------------------------------------
do $$ begin perform _FSM2_.create_journal(); end; $$;


/* ###################################################################################################### */

-- select array_agg( tail ) as "start" from _FSM2_.transitions where act = 'START';
-- select array_agg( tail ) as "stop"  from _FSM2_.transitions where act = 'STOP';
-- select array_agg( tail ) as "reset" from _FSM2_.transitions where act = 'RESET';
-- select array_agg( tail ) as "clear" from _FSM2_.transitions where act = 'CLEAR';
-- select exists ( select 1 from _FSM2_.transitions where act = 'RESET' and tail = '*' );
-- select exists ( select 1 from _FSM2_.transitions where act = 'CLEAR' and tail = '*' );

-- \quit



-- ---------------------------------------------------------------------------------------------------------
/* color=red */
do $$ begin
  perform _FSM2_.step( 'RESET'                      );
  perform _FSM2_.step( 'START'                      );
  perform _FSM2_.step( 'identifier',  'color'       );
  perform _FSM2_.step( 'equals',      '='           );
  -- perform _FSM2_.step( 'equals',      '='          );
  -- perform _FSM2_.step( 'START',      null           );
  perform _FSM2_.step( 'identifier',  'red'         );
  perform _FSM2_.step( 'STOP'                       );
  end; $$;
-- perform _FSM2_.step( 'CLEAR'                      );
select * from _FSM2_.journal;



/* foo::q */
do $$ begin
  perform _FSM2_.step( 'RESET'                      );
  perform _FSM2_.step( 'START'                      );
  -- perform _FSM2_.step( 'STOP'                      );
  perform _FSM2_.step( 'identifier',  'foo'         );
  perform _FSM2_.step( 'equals',      '::'          );
  -- perform _FSM2_.step( 'equals',      '='          );
  perform _FSM2_.step( 'identifier',  'q'           );
  perform _FSM2_.step( 'STOP'                       );
  end; $$;
select * from _FSM2_.journal;

/* author=Faulkner::name */
do $$ begin
  perform _FSM2_.step( 'CLEAR'                      );
  perform _FSM2_.step( 'START'                      );
  perform _FSM2_.step( 'identifier',  'author'      );
  perform _FSM2_.step( 'equals',      '='           );
  perform _FSM2_.step( 'identifier',  'Faulkner'    );
  perform _FSM2_.step( 'dcolon',      '::'          );
  perform _FSM2_.step( 'identifier',  'name'        );
  perform _FSM2_.step( 'STOP'                       );
  -- perform _FSM2_.step( 'equals',      '='          );
  end; $$;
select * from _FSM2_.journal;

/* IT/programming/language=SQL::name */
/* '{IT,/,programming,/,language,=,SQL,::,name}' */
do $$ begin
  perform _FSM2_.step( 'CLEAR'                        );
  perform _FSM2_.step( 'START'                        );
  perform _FSM2_.step( 'identifier',  'IT'            );
  perform _FSM2_.step( 'slash',       '/'             );
  perform _FSM2_.step( 'identifier',  'programming'   );
  perform _FSM2_.step( 'slash',       '/'             );
  perform _FSM2_.step( 'identifier',  'language'      );
  perform _FSM2_.step( 'equals',      '='             );
  perform _FSM2_.step( 'identifier',  'SQL'           );
  perform _FSM2_.step( 'dcolon',      '::'            );
  perform _FSM2_.step( 'identifier',  'name'          );
  perform _FSM2_.step( 'STOP'                         );
  end; $$;
select * from _FSM2_.journal;
select * from _FSM2_.result;
select * from _FSM2_.raw_result;

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



create table _FSM2_.journal (
  aid serial primary key,
  foo text
  );
create table _FSM2_.registers (
  aid integer references _FSM2_.journal ( aid ),
  facets jsonb
  );

insert into _FSM2_.journal ( foo ) values ( 42 ), ( 'helo' ), ( array[ 1, '2' ] );
insert into _FSM2_.registers values ( 1, '{"a":1,"b":2}' );
insert into _FSM2_.registers values ( 2, '{"a":42,"b":12}' );
select * from _FSM2_.journal;
select * from _FSM2_.registers;

select from _FSM2_.journal;

-- select aid, ( select * from jsonb_each( facets ) ) as v1 from _FSM2_.registers;
-- select
--     j.aid,
--     j.foo,

--   from _FSM2_.journal as j
--   left join _FSM2_.registers as r using ( aid );

\quit


/* aggregate function */

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


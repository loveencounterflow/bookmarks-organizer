





/* thx to http://felixge.de/2017/07/27/implementing-state-machines-in-postgresql.html */


/*

_______________/\\\\\\\\\\\\\\\__/\\\___________________/\\\\\_______/\\\______________/\\\________
 ______________\/\\\///////////__\/\\\_________________/\\\///\\\____\/\\\_____________\/\\\________
  ______________\/\\\_____________\/\\\_______________/\\\/__\///\\\__\/\\\_____________\/\\\________
   ______________\/\\\\\\\\\\\_____\/\\\______________/\\\______\//\\\_\//\\\____/\\\____/\\\_________
    ______________\/\\\///////______\/\\\_____________\/\\\_______\/\\\__\//\\\__/\\\\\__/\\\__________
     ______________\/\\\_____________\/\\\_____________\//\\\______/\\\____\//\\\/\\\/\\\/\\\___________
      ______________\/\\\_____________\/\\\______________\///\\\__/\\\_______\//\\\\\\//\\\\\____________
       ______________\/\\\_____________\/\\\\\\\\\\\\\\\____\///\\\\\/_________\//\\\__\//\\\_____________
        ______________\///______________\///////////////_______\/////____________\///____\///______________
         ___________________________________________________________________________________________________
          _____/\\\\____________/\\\\_____/\\\\\\\\\_____/\\\\\\\\\\\\\\\__/\\\\\\\\\\\________/\\\\\\\\\____
           ____\/\\\\\\________/\\\\\\___/\\\\\\\\\\\\\__\///////\\\/////__\/////\\\///______/\\\////////_____
            ____\/\\\//\\\____/\\\//\\\__/\\\/////////\\\_______\/\\\___________\/\\\_______/\\\/______________
             ____\/\\\\///\\\/\\\/_\/\\\_\/\\\_______\/\\\_______\/\\\___________\/\\\______/\\\________________
              ____\/\\\__\///\\\/___\/\\\_\/\\\\\\\\\\\\\\\_______\/\\\___________\/\\\_____\/\\\________________
               ____\/\\\____\///_____\/\\\_\/\\\/////////\\\_______\/\\\___________\/\\\_____\//\\\_______________
                ____\/\\\_____________\/\\\_\/\\\_______\/\\\_______\/\\\___________\/\\\______\///\\\_____________
                 ____\/\\\_____________\/\\\_\/\\\_______\/\\\_______\/\\\________/\\\\\\\\\\\____\////\\\\\\\\\____
                  ____\///______________\///__\///________\///________\///________\///////////________\/////////_____
                   ___________________________________________________________________________________________________

                                                   An Observable Finite Automaton Engine
                                                        implemented in PostGreSQL

art rendered with
http://www.patorjk.com/software/taag/#p=display&f=Slant%20Relief&t=FLOWMATIC
*/


-- ---------------------------------------------------------------------------------------------------------
drop schema if exists FM cascade;
create schema FM;

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists FMAS cascade;
create schema FMAS;

-- ---------------------------------------------------------------------------------------------------------
create type FMAS.cmd_output as (
  next_cmd    text,
  next_cc     boolean,
  ok_ac       integer,
  error       text );


/*  ========================================================================================================
    STATES AND ACTS
--------------------------------------------------------------------------------------------------------- */


-- ---------------------------------------------------------------------------------------------------------
create table FM.states (
  state text unique not null primary key );

-- ---------------------------------------------------------------------------------------------------------
create table FM.acts (
  act text unique not null primary key );


/*  ========================================================================================================
    TRANSITIONS
--------------------------------------------------------------------------------------------------------- */

-- ---------------------------------------------------------------------------------------------------------
create type FM.transition as (
  tc            integer,
  tail          text,
  act           text,
  cmd           text,
  point         text );

-- ---------------------------------------------------------------------------------------------------------
/* thx to https://stackoverflow.com/a/16474780/7568091 for detailing how to set up a sequence in a
  typed table that behaves like `serial` */
create sequence FM.tc_seq;

-- ---------------------------------------------------------------------------------------------------------
create table FM.transitions of FM.transition (
  tc            unique not null default nextval( 'FM.tc_seq' ),
  tail          references FM.states    ( state   ),
  act           references FM.acts      ( act     ),
  point         references FM.states    ( state   ),
  primary key ( tail, act ) );

-- ---------------------------------------------------------------------------------------------------------
alter sequence FM.tc_seq owned by FM.transitions.tc;

-- -- ---------------------------------------------------------------------------------------------------------
create function FM._act_is_starred( ¶act text ) returns boolean stable language sql as $$
  select exists ( select 1 from FM.transitions where act = ¶act and tail = '*' ); $$;

-- -- ---------------------------------------------------------------------------------------------------------
create function FM._star_count_ok( ¶tail text, ¶act text ) returns boolean volatile language sql as $$
  select case when ¶tail = '*' or FM._act_is_starred( ¶act ) then
    ( select count(*) = 0 from FM.transitions where act = ¶act )
    else true end; $$;

-- ---------------------------------------------------------------------------------------------------------
alter table FM.transitions
  add constraint "starred acts must have no more than one transition"
  check ( FM._star_count_ok( tail, act ) );

-- ---------------------------------------------------------------------------------------------------------
create function FM.proceed( ¶tail text, ¶act text ) returns FM.transition stable language sql as $$
  select * from FM.transitions where ( tail = ¶tail ) and ( act = ¶act ); $$;


/*  ========================================================================================================
    THE BOARD (REGISTERS)
--------------------------------------------------------------------------------------------------------- */

-- ---------------------------------------------------------------------------------------------------------
/*

The 'board' is where register data gets collected. 'BC' is the board counter, which identifies rows;
referenced by `FM.journal ( bc )`.

Modus operandi of the `FM.board` table:

* `value` is of type JSONb;
* `value` can be primitive JSONb value or JSONb list, object;
* current value always at index zero;
* on creation current value is set to JSONb `null`;
* operations on board either use update; this can be an update to the entire field (as in `update FM.board
  values set value = x where bc = 0;`) or else an update to a single data member of a complex field value
  (as in `... set value = jsonb_set( '{"X":"second"}', '{X}', '"third"' ) where bc = 0;`) (in either case,
  the entire field will technically be rewritten, but conceptually it's an update nonetheless);
* at any point in time, a copy of row zero may be appended to the board table;
* results may be linked (or copied?) to other tables.

```sql
insert into FM.board values ( 0, null );                                      select * from FM.board order by bc;
update FM.board values set value = '"first"'  where bc = 0;                     select * from FM.board order by bc;
insert into FM.board ( value ) select value from FM.board where bc = 0 ;  select * from FM.board order by bc;
update FM.board values set value = '{"X":"second"}' where bc = 0;                     select * from FM.board order by bc;
insert into FM.board ( value ) select value from FM.board where bc = 0 ;  select * from FM.board order by bc;
update FM.board values set value = jsonb_set( '{"X":"second"}', '{X}', '"third"' ) where bc = 0;                     select * from FM.board order by bc;
insert into FM.board ( value ) select value from FM.board where bc = 0 ;  select * from FM.board order by bc;
```

*/
-- ---------------------------------------------------------------------------------------------------------
/* thx to https://stackoverflow.com/a/25393923/7568091 */
create table FM.board (
  _onerow boolean primary key default true,
  value   jsonb,
  constraint "board can not have more than one row" check ( _onerow ) );


/*  ========================================================================================================
    JOURNAL
--------------------------------------------------------------------------------------------------------- */

-- ---------------------------------------------------------------------------------------------------------
create table FM.journal (
  ac            serial    unique  not null  primary key,
  cc            integer           not null,
  tc            integer           not null  references FM.transitions ( tc      ),
  tail          text                        references FM.states      ( state   ),
  act           text              not null  references FM.acts        ( act     ),
  cmd           text,
  point         text                        references FM.states      ( state   ),
  data          jsonb,
  ok            boolean                                                           default false );

-- ---------------------------------------------------------------------------------------------------------
create index on FM.journal ( cc );

-- ---------------------------------------------------------------------------------------------------------
create sequence FM.cc_seq minvalue 0 start 0;
do $$ begin perform nextval( 'FM.cc_seq' ); end; $$;

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT max( sequence ) is not concurrency-proof */
create function FM.ac()  returns integer stable language sql as $$ select max( ac ) from FM.journal;  $$;
/* ### TAINT max( sequence ) is not concurrency-proof */
create function FM.cc()  returns integer stable language sql as $$ select coalesce( max( cc ), 0 ) from FM.journal;  $$;
-- create function FM.cc()  returns bigint stable language sql as $$
--   select coalesce( ( select last_value from FM.cc_seq ), 0 ) from FM.journal;  $$;

-- ---------------------------------------------------------------------------------------------------------
create table FM.results (
  ac    integer references FM.journal ( ac ),
  value jsonb );

-- ---------------------------------------------------------------------------------------------------------
create view FM.journal_and_board as ( select distinct
    j.ac                                    as ac,
    -- j.bc                                    as bc,
    j.cc                                    as cc,
    j.tc                                    as tc,
    j.tail                                  as tail,
    j.act                                   as act,
    j.cmd                                   as cmd,
    j.point                                 as point,
    j.data                                  as data,
    j.ok                                    as ok,
    case when j.ok then '->' else '' end    as "R",
    r.value                                 as results
  from FM.journal       as j
  left join FM.results  as r on ( j.ac = r.ac )
  order by j.ac );

-- ---------------------------------------------------------------------------------------------------------
create function FM.save_board() returns void volatile language sql as $$
  insert into FM.results ( ac, value )
    select
        j.ac,
        b.value
      from
        FM.board as b
        left join FM.journal as j on ( j.ac = FM.ac() ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.log_board() returns void volatile language sql as $$
  select case when false then FM.save_board() else null end; $$;
  /*               ^^^^                   */
  /* imagine configuration variable here  */

-- ---------------------------------------------------------------------------------------------------------
create function FM.new_boardline() returns void volatile language sql as $$
  select FM.save_board(); $$;
  -- insert into FM.board ( value ) select value from FM.board where bc = 0; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.get_board_value() returns jsonb stable language sql as $$
  select value from FM.board limit 1; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM._board_as_tabular() returns text stable language sql as $outer$
  select U.tabulate_query( $$ select * from FM.board; $$ ); $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function FM._journal_as_tabular( n integer ) returns text stable language sql as $outer$
    select case
      when n is not distinct from null then
        U.tabulate_query( $$
          select * from FM.journal_and_board
          order by ac;
          $$ )
      when n > 0 then
        U.tabulate_query( format( $$
          select * from FM.journal_and_board
          order by ac
          limit %L;
          $$, n ) )
      else
        U.tabulate_query( format( $$
          with j as ( select * from FM.journal_and_board order by ac desc limit 0 - %L )
          select * from j
          order by ac
          $$, n ) )
      end;
  $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function FM._journal_as_tabular() returns text stable language sql as $$
    select FM._journal_as_tabular( null ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM._log_journal_context() returns void stable language plpgsql as $$
  begin
    perform log();
    perform log( 'FM #19002 Journal up to problematic act:' );        perform log();
    perform log( FM._journal_as_tabular() );                          perform log();
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM._log_journal_context( n integer ) returns void stable language plpgsql as $$
  begin
    perform log();
    perform log( 'FM #19002 Journal up to problematic act:' );        perform log();
    perform log( FM._journal_as_tabular( n ) );                       perform log();
    end; $$;


/*  ========================================================================================================
    PUSH
--------------------------------------------------------------------------------------------------------- */


-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT should probably use `lock for update` */
/* ### TAINT we assume that a single `push()` can only return up to one 'good' `ac`; in general that might
  not necessarily apply. */
create function FM.push( ¶act text, ¶data jsonb ) returns integer volatile language plpgsql as $$
  declare
    -- R                 integer;
    ¶new_state        text;
    ¶tail             text;
    ¶ac               integer;
    ¶cc               integer;
    ¶transition       FM.transition;
    ¶next_transition  FM.transition;
    ¶cmd_output       FMAS.cmd_output;
  -- .......................................................................................................
  begin
    -- .....................................................................................................
    ¶transition :=  FM.proceed( '*', ¶act );
    if not ( ¶transition is null ) then
      /* Starred acts always succeed, even on an empty journal where there is no previous act and, thus, no
      tail; when can therefore always set the tail to '*'. */
      ¶tail := '*';
    -- .....................................................................................................
    else
      /* ### TAINT consider to use lag() instead */
      select into ¶tail point from FM.journal order by ac desc limit 1;
      end if;
    -- .....................................................................................................
    /* Obtain transition from tail and act: */
    ¶transition :=  FM.proceed( ¶tail, ¶act );
    -- .....................................................................................................
    loop
      -- perform log( 'push77631', ¶act::text, ¶data::text, ¶transition::text );
      -- ...................................................................................................
      if not ( ¶next_transition is null ) then
        ¶transition       :=  ¶next_transition;
        ¶act              :=  ¶next_transition.act;
        ¶tail             :=  ¶next_transition.tail;
        ¶data             :=  null;
        ¶next_transition  :=  null;
        end if;
      -- ...................................................................................................
      /* Error out in case no matching transition was found: */
      if ¶transition is null then
        perform log( 'FM #19001', 'Journal up to problematic act:' );
        perform log( FM._journal_as_tabular() );
        raise exception
          'invalid act: { state: %, act: %, data: %, } -> null',
            ¶tail, ¶act, ¶data;
        end if;
      -- ...................................................................................................
      /* Perform associated FMAS command: */
      ¶cmd_output := FMAS.do( ¶transition.cmd, ¶data, ¶transition );
      -- ...................................................................................................
      /* Start new case in journal when FMAS command says so: */
      -- perform log( '29921-1', ¶cc::text );
      -- ¶cc := currval( 'FM.cc_seq' );
      ¶cc := FM.cc();
      if ¶cmd_output.next_cc then ¶cc = nextval( 'FM.cc_seq' ); end if;
      if ¶cmd_output.ok_ac is distinct from null then ¶ac := ¶cmd_output.ok_ac; end if;
      -- ...................................................................................................
      /* Insert new line into journal and update register copy: */
      insert into FM.journal ( cc, tc, tail, act, cmd, point, data ) values
        ( ¶cc,
          ¶transition.tc,
          ¶tail,
          ¶act,
          regexp_replace( ¶transition.cmd, '^NOP$', '' ),
          ¶transition.point,
          ¶data );
      -- ...................................................................................................
      /* Reflect state of registers table into `FM.results`: */
      perform FM.log_board();
      -- ...................................................................................................
      if ¶transition.point = '...' then
        select * from FM.transitions
          where tc = ¶transition.tc + 1
          into ¶next_transition;
      else
        select * from FM.transitions
          where true
            and tail  = ¶transition.point
            and act   = '->'
          into ¶next_transition;
        end if;
      -- ...................................................................................................
      exit when ¶next_transition is null;
      end loop;
    -- .....................................................................................................
    return ¶ac;
    -- .....................................................................................................
    exception
      when others then
        raise notice 'something went wrong';
        raise notice 'this: % %', SQLERRM, SQLSTATE;
        raise notice 'sqlstate: %', sqlstate;
        raise;
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.push( ¶act text, ¶data text ) returns integer volatile language sql as $$
  select FM.push( ¶act, jb( ¶data ) ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.push( ¶act text, ¶data anyelement ) returns integer volatile language sql as $$
  select FM.push( ¶act, jb( ¶data ) ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.push( ¶act text ) returns integer volatile language sql as $$
  select FM.push( ¶act, jb( null ) ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.push( ¶dact text[] ) returns integer volatile language sql as $$
  select FM.push( ¶dact[ 1 ], ¶dact[ 2 ] ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.push_dacts( ¶dacts text[] ) returns integer[] volatile strict language plpgsql as $$
  declare
    ¶ac     integer;
    R       integer[] = '{}';
    ¶dact   text[];
  begin
    ¶ac := FM.push( 'START' );
    if ¶ac is distinct from null then R := R || ¶ac; end if;
    foreach ¶dact slice 1 in array ¶dacts loop
      ¶ac := FM.push( ¶dact );
      if ¶ac is distinct from null then R := R || ¶ac; end if;
      end loop;
    ¶ac := FM.push( 'STOP' );
    if ¶ac is distinct from null then R := R || ¶ac; end if;
    return R;
    -- .....................................................................................................
    exception
      when others then
        perform log( 'FM #11211 push_dacts():', 'something went wrong'     );
        perform log( 'FM #11211 push_dacts():', 'sqlerrm:',   sqlerrm      );
        perform log( 'FM #11211 push_dacts():', 'sqlstate:',  sqlstate     );
        perform log( 'FM #11211 push_dacts():', '¶dacts:',    ¶dacts::text );
        perform FM._log_journal_context( -10 );
        raise;
    end; $$;




/* ====================================================================================================== */
/* #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #  */
/*  #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  #   */
/*   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #    */
/*  #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  #   */
/* #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #  */
/* ====================================================================================================== */
/*



███████╗███╗   ███╗ █████╗ ███████╗
██╔════╝████╗ ████║██╔══██╗██╔════╝
█████╗  ██╔████╔██║███████║███████╗
██╔══╝  ██║╚██╔╝██║██╔══██║╚════██║
██║     ██║ ╚═╝ ██║██║  ██║███████║
╚═╝     ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝ http://www.patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=fmas

FM Assembly Language

NOP       # no operation (may also use SQL `null` value)
NUL *     # set all registers to NULL
NUL Y     # set register Y to NULL
LOD T     # load data to register T
MOV T C   # move contents of register T to register C and set register T to NULL
PSH C     # push data to register C (will become a list if not already a list)
PSH T C   # push contents of register T to register C and set register T to NULL
PSH * R   # push (and then clear) all registers as a JSONb object into R
NBC       # Next Board Count / New Board Line, i.e. new set of registers for next partial result
NCC       # Next Case Count, indicates the next batch, line, set of inputs (with 1 or more board lines)

*/

/* ====================================================================================================== */
/* #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #  */
/*  #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  #   */
/*   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #    */
/*  #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  #   */
/* #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #  */
/* ====================================================================================================== */


-- ---------------------------------------------------------------------------------------------------------
create function FMAS.set( ¶regkey text, ¶data jsonb ) returns void
  volatile language plpgsql as $$
  begin
    if ¶data is not distinct from null then ¶data := 'null'::jsonb; end if;
    update FM.board set value = jsonb_set( value, array[ ¶regkey ], ¶data );
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.set( ¶data jsonb ) returns void
  volatile language sql as $$
  update FM.board values set value = ¶data; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.get( ¶regkey text ) returns jsonb
  stable language plpgsql as $$
  declare
    R jsonb;
  begin
    R := FM.get_board_value();
    if jsonb_typeof( R ) != 'object' then return null::jsonb; end if;
    return R->¶regkey; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.cmd_yes( ¶cmd_parts text[], ¶data jsonb ) returns FMAS.cmd_output
  volatile language plpgsql as $$
  declare
    ¶ac           integer;
    R             FMAS.cmd_output;
  begin
    ¶ac     :=  FM.ac();
    R       :=  FMAS.cmd_nbc( ¶cmd_parts, null );
    if not ( R.error is null ) then return R; end if;
    update FM.journal set ok = true where ac = ¶ac;
    R.ok_ac :=  ¶ac;
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.cmd_nbc( ¶cmd_parts text[], ¶data jsonb ) returns FMAS.cmd_output
  volatile language plpgsql as $$
  declare
    R             FMAS.cmd_output;
  begin
    perform FM.new_boardline();
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.cmd_ncc( ¶cmd_parts text[], ¶data jsonb ) returns FMAS.cmd_output
  volatile language plpgsql as $$
  declare
    R             FMAS.cmd_output;
  begin
    -- R := FMAS.cmd_nbc( ¶cmd_parts, ¶data );
    -- if not ( R.error is null ) then return R; end if;
    R.next_cc := true;
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS._default_value_from_jsonb_type( ¶jsonb_type text ) returns jsonb
  immutable language sql as $$
    select case ¶jsonb_type
      when 'null'     then  'null'::jsonb
      when 'boolean'  then 'false'::jsonb
      when 'number'   then     '0'::jsonb
      when 'string'   then    '""'::jsonb
      when 'array'    then    '[]'::jsonb
      when 'object'   then    '{}'::jsonb
      end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.cmd_clr( ¶cmd_parts text[], ¶data jsonb ) returns FMAS.cmd_output
  volatile language plpgsql as $$
  declare
    R             FMAS.cmd_output;
  begin
    if array_length( ¶cmd_parts, 1 ) != 1 then
      R.error := 'CLR does not take arguments';
      return R;
      end if;
    update FM.board
      set value = FMAS._default_value_from_jsonb_type( jsonb_typeof(
        ( select value from FM.board ) ) );
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.cmd_rst( ¶cmd_parts text[], ¶data jsonb ) returns FMAS.cmd_output
  volatile language plpgsql as $$
  declare
    R             FMAS.cmd_output;
  begin
    if array_length( ¶cmd_parts, 1 ) != 2 then
      R.error := 'RST needs initialization value as argument';
      return R;
      end if;
    truncate table FM.journal cascade;
    truncate table FM.board   cascade;
    truncate table FM.results cascade;
    -- perform log( '33910', ¶cmd_parts::text, ¶cmd_parts[ 2 ]::text, ¶data::text );
    -- ### TAINT rewrite using FMAS._default_value_from_jsonb_type()
    case ¶cmd_parts[ 2 ]
      when '0'      then insert into FM.board ( value ) values ( '0'     );
      when '[]'     then insert into FM.board ( value ) values ( '[]'    );
      when '""'     then insert into FM.board ( value ) values ( '""'    );
      when 'false'  then insert into FM.board ( value ) values ( 'false' );
      when 'true'   then insert into FM.board ( value ) values ( 'true'  );
      when 'null'   then insert into FM.board ( value ) values ( 'null'  );
      when '{}'     then insert into FM.board ( value ) values ( '{}'    );
      end case;
    perform nextval( 'FM.cc_seq' );
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.cmd_nul( ¶cmd_parts text[], ¶data jsonb ) returns FMAS.cmd_output
  volatile language plpgsql as $$
  declare
    R             FMAS.cmd_output;
    ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
    ¶regkey_2     text    :=  ¶cmd_parts[ 3 ];
  begin
    ¶regkey_1 := ¶cmd_parts[ 2 ];
    -- .....................................................................................................
    if ¶regkey_1 = '*' then
      if ¶regkey_2 is null then
        perform FMAS.set( null );
      else
        if ¶regkey_2 = '*' then
          R.error = 'second argument to NUL can not be star';
          return R;
          end if;
        perform FMAS.set_all_except( ¶regkey_2, null );
        return R;
      end if;
    -- .....................................................................................................
    else
      perform FMAS.set( ¶regkey_1, null );
      end if;
    -- .....................................................................................................
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.cmd_lod( ¶cmd_parts text[], ¶data jsonb ) returns FMAS.cmd_output
  volatile language plpgsql as $$
  declare
    R             FMAS.cmd_output;
    ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
  begin
    perform FMAS.set( ¶regkey_1, ¶data );
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.cmd_mov( ¶cmd_parts text[], ¶data jsonb ) returns FMAS.cmd_output
  volatile language plpgsql as $$
  declare
    R             FMAS.cmd_output;
    ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
    ¶regkey_2     text    :=  ¶cmd_parts[ 3 ];
  begin
    perform FMAS.set( ¶regkey_2, FMAS.get( ¶regkey_1 ) );
    perform FMAS.set( ¶regkey_1, null );
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.cmd_psh( ¶cmd_parts text[], ¶data jsonb ) returns FMAS.cmd_output
  volatile language plpgsql as $$
  declare
    R             FMAS.cmd_output;
    ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
    ¶regkey_2     text    :=  ¶cmd_parts[ 3 ];
    ¶target_key   text    :=  null;
  -- .......................................................................................................
  begin
    -- .....................................................................................................
    if ¶regkey_2 is null then
      ¶target_key := ¶regkey_1;
      if ¶target_key = '*' then
        R.error = 'PSH * is invalid without target register key';
        return R;
        end if;
    -- .....................................................................................................
    else
      ¶target_key :=  ¶regkey_2;
      if ¶target_key = '*' then
        R.error = 'unable to push to star register';
        return R;
        end if;
      end if;
    -- .....................................................................................................
    if ¶regkey_1 = '*' then
      perform FMAS.push_data( ¶target_key, FM.get_registers_except( ¶target_key ) );
      R.next_cmd  := format( 'NUL * %s', ¶target_key );
    else
      perform FMAS.push_data( ¶target_key, FMAS.get( ¶regkey_1 ) );
      R.next_cmd  := format( 'NUL %s', ¶regkey_1 );
      end if;
    -- .....................................................................................................
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.push_data( ¶regkey text, ¶data jsonb )
  returns void volatile language plpgsql as $$
  declare
    ¶target       jsonb;
    ¶target_type  text;
  begin
    ¶target       := FMAS.get( ¶regkey );
    ¶target_type  :=  jsonb_typeof( ¶target );
    -- .....................................................................................................
    if ( ¶target_type is null ) or ( ¶target_type = 'null' ) then
      ¶target = '[]'::jsonb;
    -- .....................................................................................................
    elsif ( ¶target_type != 'array' ) then
      ¶target = jsonb_build_array( ¶target );
      end if;
    -- .....................................................................................................
    perform FMAS.set( ¶regkey, ¶target || ¶data );
    -- .....................................................................................................
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.do( ¶cmd text, ¶data jsonb, ¶transition FM.transition ) returns FMAS.cmd_output
  volatile language plpgsql as $$
  declare
    ¶cmd_parts    text[];
    ¶base         text;
    ¶regkey_1     text;
    ¶regkey_2     text;
    S             FMAS.cmd_output;
  -- .......................................................................................................
  begin
    -- .....................................................................................................
    loop
      -- ...................................................................................................
      if not ( S.next_cmd is null ) then
        ¶cmd        :=  S.next_cmd;
        S.next_cmd  :=  null;
        end if;
      -- perform log( '02011', ¶cmd );
      -- ...................................................................................................
      /* ### TAINT should check whether there are extraneous arguments with NOP */
      if ( ¶cmd is null ) or ( ¶cmd = 'NOP' ) or ( ¶cmd = '' ) then return S; end if;
      ¶cmd        :=  trim( both from ¶cmd );
      ¶cmd_parts  :=  regexp_split_to_array( ¶cmd, '\s+' );
      ¶base       :=  ¶cmd_parts[ 1 ];
      -- ...................................................................................................
      case ¶base
        when 'RST' then S := FMAS.cmd_rst( ¶cmd_parts, ¶data );
        when 'NUL' then S := FMAS.cmd_nul( ¶cmd_parts, ¶data );
        when 'CLR' then S := FMAS.cmd_clr( ¶cmd_parts, ¶data );
        when 'NBC' then S := FMAS.cmd_nbc( ¶cmd_parts, ¶data );
        when 'NCC' then S := FMAS.cmd_ncc( ¶cmd_parts, ¶data );
        when 'LOD' then S := FMAS.cmd_lod( ¶cmd_parts, ¶data );
        when 'MOV' then S := FMAS.cmd_mov( ¶cmd_parts, ¶data );
        when 'PSH' then S := FMAS.cmd_psh( ¶cmd_parts, ¶data );
        when 'YES' then S := FMAS.cmd_yes( ¶cmd_parts, ¶data );
        else
          perform FM._log_journal_context( -10 );
          perform log( 'FMAS #19003 do:', 'transition:', ¶transition::text ); perform log();
          raise exception 'unknown command %', ¶cmd;
        end case;
      -- ...................................................................................................
      if not ( S.error is null ) then
        raise exception 'error %  in command %', S.error, ¶cmd;
        end if;
      -- ...................................................................................................
      exit when S.next_cmd is null;
      ¶cmd        :=  null;
      ¶data       :=  null;
      ¶transition :=  null;
      end loop;
    return S; end; $$;



/* ====================================================================================================== */
/* #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #  */
/*  #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  #   */
/*   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #    */
/*  #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  #   */
/* #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #  */
/* ====================================================================================================== */

    -- t0 timestamp with time zone; -- 44301
    -- t1 timestamp with time zone; -- 44301
    -- t0 := clock_timestamp(); -- 44301
    -- t1 := clock_timestamp(); perform log( '44301', '-/1/-', ( t1 - t0 )::text ); t0 := t1;







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

-- ---------------------------------------------------------------------------------------------------------
/* STATES AND ACTS */

-- ---------------------------------------------------------------------------------------------------------
create table FM.states (
  state text unique not null primary key );

-- ---------------------------------------------------------------------------------------------------------
create table FM.acts (
  act text unique not null primary key );

-- ---------------------------------------------------------------------------------------------------------
/* TRANSITIONS */

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

-- ---------------------------------------------------------------------------------------------------------
/* REGISTERS */

-- ---------------------------------------------------------------------------------------------------------
/* `FM.registers` is where registers are defined: */
create table FM.registers (
  id      serial,
  regkey  text unique not null primary key check ( regkey::U.chr = regkey ),
  name    text unique not null,
  comment text );

-- ---------------------------------------------------------------------------------------------------------
/* ...and the 'board' is where register data gets collected. 'BC' is the board counter, which identifies
  rows; referenced by `FM.journal ( bc )`: */
create table FM.board ( bc serial primary key );

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT max( sequence ) is not concurrency-proof */
create function FM.bc()   returns integer stable language sql as $$ select max(  bc ) from FM.board;    $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.new_boardline() returns void volatile language sql as $$
  /* thx to https://stackoverflow.com/a/12336849/7568091 */
  insert into FM.board values ( default ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.copy_boardline_to_journal() returns void volatile language sql as $$
  select null::void; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.get_adaptive_statement_for_copy_function() returns text stable language plpgsql as $outer$
  declare
    R     text;
    ¶q1   text[];
    ¶q2   text;
  begin
    -- .....................................................................................................
    select array_agg( format( '%I', regkey ) order by id ) from FM.registers
      into ¶q1;
    -- .....................................................................................................
    ¶q2 :=  array_to_string( ¶q1, ', ' );
    R   := format( '
      create or replace function FM.copy_boardline_to_journal() returns void volatile language sql as $$
        update FM.journal set
        ( %s ) = ( select %s from FM.board where bc = FM.bc() )
        where ac = FM.ac(); $$;',
      ¶q2, ¶q2 );
    -- .....................................................................................................
    return R; end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.adapt_copy_function() returns void volatile language plpgsql as $$
  begin execute FM.get_adaptive_statement_for_copy_function(); end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.get_create_statement_for_longboard() returns text stable language plpgsql as $outer$
  declare
    R     text;
    ¶q1   text[];
    ¶q2   text;
  begin
    -- .....................................................................................................
    select array_agg(
      format( 'select bc, %L as regkey, %I as data from FM.board union all', regkey, regkey ) order by id
      ) from FM.registers
      into ¶q1;
    -- .....................................................................................................
    ¶q2 :=  array_to_string( ¶q1, E'\n' );
    R   := format( '
      drop view if exists FM.longboard cascade;
      create view FM.longboard as (
        %s
        select null, null, null where false );',
      ¶q2, ¶q2 );
    -- .....................................................................................................
    return R; end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.create_longboard() returns void volatile language plpgsql as $$
  begin execute FM.get_create_statement_for_longboard(); end; $$;

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT we use `NAMEOF.relation` (a.k.a. `regclass`) to ensure integrity and then go and insert the
  name using `%s` formatting; not clear whether that is Bobby-Tables-proof. */
create function FM.get_adaptive_statement_for_table( ¶tablename NAMEOF.relation ) returns text volatile
  language plpgsql as $$
  declare
    R         text;
    ¶q        text[];
    ¶row      record;
  begin
    -- .....................................................................................................
    select
        array_agg(
          format( E'alter table %s add column %I jsonb default null;\n', ¶tablename, regkey )
          order by id )
      from FM.registers
      into ¶q;
    -- .....................................................................................................
    R := array_to_string( ¶q, '' );
    return R;
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.adapt_board() returns void volatile language plpgsql as $$
  begin execute FM.get_adaptive_statement_for_table( 'FM.board'::NAMEOF.relation ); end; $$;

-- ---------------------------------------------------------------------------------------------------------
/* JOURNAL */

-- ---------------------------------------------------------------------------------------------------------
create table FM.journal (
  ac            serial    unique  not null  primary key,
  bc            integer                     references FM.board       ( bc      ) default FM.bc(),
  cc            integer           not null,
  tc            integer           not null  references FM.transitions ( tc      ),
  tail          text                        references FM.states      ( state   ),
  act           text              not null  references FM.acts        ( act     ),
  cmd           text,
  point         text                        references FM.states      ( state   ),
  data          jsonb,
  ok            boolean                                                           default false );

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
create function FM.adapt_journal() returns void volatile language plpgsql as $outer$
  begin
    execute FM.get_adaptive_statement_for_table( 'FM.journal'::NAMEOF.relation );
    end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function FM._journal_as_tabular() returns text
  immutable strict language sql as $outer$
    select U.tabulate_query( $$ select * from FM.journal order by ac; $$ );
    $outer$;

-- ---------------------------------------------------------------------------------------------------------
/* PUSH */

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
      /* Reflect state of registers table into `journal ( registers )`: */
      perform FM.copy_boardline_to_journal();
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
create function FM.push_dacts( ¶dacts text[] ) returns integer[] volatile language plpgsql as $$
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
    return R; end; $$;




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
create function FMAS.get( ¶regkey text ) returns jsonb stable language sql as $$
  select null::jsonb; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.set( ¶regkey text, ¶data jsonb ) returns void volatile language sql as $$
  select null::void; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.yes( ¶cmd_parts text[], ¶data jsonb )
  returns FMAS.cmd_output volatile language plpgsql as $$
  declare
    ¶ac           integer;
    R             FMAS.cmd_output;
  begin
    ¶ac     :=  FM.ac();
    update FM.journal set ok = true where ac = ¶ac;
    R.ok_ac :=  ¶ac;
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.nbc( ¶cmd_parts text[], ¶data jsonb )
  returns FMAS.cmd_output volatile language plpgsql as $$
  declare
    R             FMAS.cmd_output;
  begin
    perform FM.new_boardline();
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.ncc( ¶cmd_parts text[], ¶data jsonb )
  returns FMAS.cmd_output volatile language plpgsql as $$
  declare
    R             FMAS.cmd_output;
  begin
    R := FMAS.nbc( ¶cmd_parts, ¶data );
    if not ( R.error is null ) then return R; end if;
    R.next_cc := true;
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.rst( ¶cmd_parts text[], ¶data jsonb )
  returns FMAS.cmd_output volatile language plpgsql as $$
  declare
    R             FMAS.cmd_output;
  begin
    if array_length( ¶cmd_parts, 1 ) != 1 then
      R.error := 'RST does not accept arguments';
      return R;
      end if;
    truncate table FM.journal cascade;
    truncate table FM.board   cascade;
    perform nextval( 'FM.cc_seq' );
    R.next_cmd := 'NUL *';
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.nul( ¶cmd_parts text[], ¶data jsonb )
  returns FMAS.cmd_output volatile language plpgsql as $$
  declare
    R             FMAS.cmd_output;
    ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
    ¶regkey_2     text    :=  ¶cmd_parts[ 3 ];
  begin
    ¶regkey_1 := ¶cmd_parts[ 2 ];
    -- .....................................................................................................
    if ¶regkey_1 = '*' then
      if ¶regkey_2 is null then
        perform FMAS.set_all( null );
      else
        if ¶regkey_2 = '*' then
          R.error = 'second argument to NUL can not be star';
          return R;
          end if;
        perform FMAS.set_all_except( ¶regkey_2, ¶data );
        return R;
      end if;
    -- .....................................................................................................
    else
      perform FMAS.set( ¶regkey_1, null );
      end if;
    -- .....................................................................................................
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.lod( ¶cmd_parts text[], ¶data jsonb )
  returns FMAS.cmd_output volatile language plpgsql as $$
  declare
    R             FMAS.cmd_output;
    ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
  begin
    perform FMAS.set( ¶regkey_1, ¶data );
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.mov( ¶cmd_parts text[], ¶data jsonb )
  returns FMAS.cmd_output volatile language plpgsql as $$
  declare
    R             FMAS.cmd_output;
    ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
    ¶regkey_2     text    :=  ¶cmd_parts[ 3 ];
  begin
    perform FMAS.set( ¶regkey_2, FMAS.get( ¶regkey_1 ) );
    perform FMAS.set( ¶regkey_1, null );
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.psh( ¶cmd_parts text[], ¶data jsonb )
  returns FMAS.cmd_output volatile language plpgsql as $$
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
      if ¶regkey_1 = '*' then
        perform FMAS.psh_data( ¶target_key, FM.get_registers_except( ¶target_key ) );
        R.next_cmd  := format( 'NUL * %s', ¶target_key );
      else
        perform FMAS.psh_data( ¶target_key, FMAS.get( ¶regkey_1 ) );
        R.next_cmd  := format( 'NUL %s', ¶regkey_1 );
        end if;
      end if;
    -- .....................................................................................................
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.psh_data( ¶regkey text, ¶data jsonb )
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
    ¶target := ¶target || ¶data;
    perform FMAS.set( ¶regkey, ¶target );
    -- .....................................................................................................
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.do( ¶cmd text, ¶data jsonb, ¶transition FM.transition )
  returns FMAS.cmd_output volatile language plpgsql as $$
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
      -- ...................................................................................................
      /* ### TAINT should check whether there are extraneous arguments with NOP */
      if ( ¶cmd is null ) or ( ¶cmd = 'NOP' ) or ( ¶cmd = '' ) then return S; end if;
      ¶cmd        :=  trim( both from ¶cmd );
      ¶cmd_parts  :=  regexp_split_to_array( ¶cmd, '\s+' );
      ¶base       :=  ¶cmd_parts[ 1 ];
      -- ...................................................................................................
      case ¶base
        when 'RST' then S := FMAS.rst( ¶cmd_parts, ¶data );
        when 'NUL' then S := FMAS.nul( ¶cmd_parts, ¶data );
        when 'NBC' then S := FMAS.nbc( ¶cmd_parts, ¶data );
        when 'NCC' then S := FMAS.ncc( ¶cmd_parts, ¶data );
        when 'LOD' then S := FMAS.lod( ¶cmd_parts, ¶data );
        when 'MOV' then S := FMAS.mov( ¶cmd_parts, ¶data );
        when 'PSH' then S := FMAS.psh( ¶cmd_parts, ¶data );
        when 'YES' then S := FMAS.yes( ¶cmd_parts, ¶data );
        else
          perform log();
          perform log( 'FM #19002', 'Journal up to problematic act:' );     perform log();
          perform log( FM._journal_as_tabular() );                          perform log();
          perform log( 'FM #19003', 'transition: %', ¶transition::text );   perform log();
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

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.get_create_statement_for_set() returns text stable language plpgsql as $outer$
  declare
    R     text;
    ¶q1   text[];
    ¶q2   text;
  begin
    -- .....................................................................................................
    select array_agg(
      format( 'when %L then update FM.board set %I = ¶data where bc = FM.bc();', regkey, regkey ) order by id
      ) from FM.registers
      into ¶q1;
    -- .....................................................................................................
    ¶q2 :=  array_to_string( ¶q1, E'\n' );
    R   := format( '
      create or replace function FMAS.set( ¶regkey text, ¶data jsonb )
        returns void volatile language plpgsql as $$
        begin
          case ¶regkey
            %s
            end case;
        end; $$;',
      ¶q2 );
    -- .....................................................................................................
    return R; end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.create_set() returns void volatile language plpgsql as $$
  begin execute FMAS.get_create_statement_for_set(); end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.get_create_statement_for_set_all() returns text stable language plpgsql as $outer$
  declare
    R     text;
    ¶q1   text[];
    ¶q2   text;
  begin
    -- .....................................................................................................
    select array_agg(
      format( 'update FM.board set %I = ¶data where bc = ¶bc;', regkey ) order by id
      ) from FM.registers
      into ¶q1;
    -- .....................................................................................................
    ¶q2 :=  array_to_string( ¶q1, E'\n' );
    R   := format( '
      create or replace function FMAS.set_all( ¶data jsonb )
        returns void volatile language plpgsql as $$
        declare
          ¶bc integer := FM.bc();
        begin
          %s
        end; $$;',
      ¶q2 );
    -- .....................................................................................................
    return R; end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.create_set_all() returns void volatile language plpgsql as $$
  begin execute FMAS.get_create_statement_for_set_all(); end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.get_create_statement_for_set_all_except() returns text stable language plpgsql as $outer$
  declare
    R     text;
    ¶q1   text[];
    ¶q2   text;
  begin
    -- .....................................................................................................
    select array_agg(
      format( 'if ¶regkey != %L then
        update FM.board set %I = ¶data where bc = ¶bc;
        ¶count = 1; end if;', regkey, regkey ) order by id
      ) from FM.registers
      into ¶q1;
    -- .....................................................................................................
    ¶q2 :=  array_to_string( ¶q1, E'\n' );
    R   := format( '
      create or replace function FMAS.set_all_except( ¶regkey text, ¶data jsonb )
        returns void volatile language plpgsql as $$
        declare
          ¶bc     integer := FM.bc();
          ¶count  integer := 0;
        begin
          %s
        -- ### TAINT here we raise an exception; in other places, we return an error value
        if ¶count = 0 then
          raise exception ''unknown regkey %%'', ¶regkey;
          end if;
        end; $$;',
      ¶q2 );
    -- .....................................................................................................
    return R; end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.create_set_all_except() returns void volatile language plpgsql as $$
  begin execute FMAS.get_create_statement_for_set_all_except(); end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.get_create_statement_for_get() returns text stable language plpgsql as $outer$
  declare
    R     text;
    ¶q1   text[];
    ¶q2   text;
  begin
    -- .....................................................................................................
    select array_agg(
      format( 'when %L then select %I from FM.board where bc = FM.bc() into R;', regkey, regkey ) order by id
      ) from FM.registers
      into ¶q1;
    -- .....................................................................................................
    ¶q2 :=  array_to_string( ¶q1, E'\n' );
    R   := format( '
      create or replace function FMAS.get( ¶regkey text )
        returns jsonb volatile language plpgsql as $$
        declare
          R jsonb;
        begin
          case ¶regkey
            %s
            end case;
        return R; end; $$;',
      ¶q2 );
    -- .....................................................................................................
    return R; end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function FMAS.create_get() returns void volatile language plpgsql as $$
  begin execute FMAS.get_create_statement_for_get(); end; $$;



/* ====================================================================================================== */
/* #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #  */
/*  #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  #   */
/*   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #    */
/*  #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  #   */
/* #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #  */
/* ====================================================================================================== */


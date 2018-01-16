





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
  tail          text,
  act           text,
  precmd        text,
  point         text,
  postcmd       text );

-- -- ---------------------------------------------------------------------------------------------------------
-- create table FM.transitions of FM.transition (
--   tail          references FM.states    ( state   ),
--   act           references FM.acts      ( act     ),
--   point         references FM.states    ( state   ),
--   primary key ( tail, act ) );

-- -- ---------------------------------------------------------------------------------------------------------
create table FM.transitions (
  tail          text                    references FM.states    ( state   ),
  act           text                    references FM.acts      ( act     ),
  precmd        text,
  point         text                    references FM.states    ( state   ),
  postcmd       text,
  primary key ( tail, act ) );

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
create function FM.proceed( ¶tail text, ¶act text ) returns FM.transitions stable language sql as $$
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
create function FM.bc() returns integer stable language sql as $$
  select max( bc ) from FM.board; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.new_boardline() returns void stable language sql as $$
  /* thx to https://stackoverflow.com/a/12336849/7568091 */
  insert into fa.board values ( default ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.registers_as_jsonb_object() returns jsonb stable language sql as $$
  select U.facets_as_jsonb_object( 'select regkey, data from FM.registers' ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.registers_as_jsonb_object( ¶except_regkey text ) returns jsonb stable language sql as $$
  select U.facets_as_jsonb_object(
    format( 'select regkey, data from FM.registers where regkey != %L', ¶except_regkey ) ); $$;

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT we use `NAMEOF.relation` (a.k.a. `regclass`) to ensure integrity and then go and insert the
  name using `%s` formatting; not clear whether that is Bobby-Tables-proof. */
create function FM.get_adaptive_statement_for_registers( ¶tablename NAMEOF.relation ) returns text volatile
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
create function FM.adapt_board() returns void volatile language plpgsql as $outer$
  begin
    execute FM.get_adaptive_statement_for_registers( 'FM.board'::NAMEOF.relation );
    end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
/* JOURNAL */

-- ---------------------------------------------------------------------------------------------------------
create table FM.journal (
  aid           serial    primary key,
  bc            integer                 references FM.board     ( bc      ),
  tail          text                    references FM.states    ( state   ),
  act           text      not null      references FM.acts      ( act     ),
  point         text                    references FM.states    ( state   ),
  precmd        text,
  postcmd       text,
  data          jsonb );

-- ---------------------------------------------------------------------------------------------------------
create view FM.journal_results as ( select * from FM.journal where point = 'LAST' );

-- ---------------------------------------------------------------------------------------------------------
create function FM.adapt_journal() returns void volatile language plpgsql as $outer$
  begin
    execute FM.get_adaptive_statement_for_registers( 'FM.journal'::NAMEOF.relation );
    end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function FM._journal_as_tabular() returns text
  immutable strict language sql as $outer$
    select U.tabulate_query( $$ select * from FM.journal order by aid; $$ );
    $outer$;

-- ---------------------------------------------------------------------------------------------------------
/* PUSH */

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT should probably use `lock for update` */
create function FM.push( ¶act text, ¶data jsonb ) returns void volatile language plpgsql as $$
  declare
    ¶new_state  text;
    ¶tail       text;
    ¶aid        integer;
    ¶transition FM.transition;
  -- .......................................................................................................
  begin
    /* ### TAINT rewrite this as
      ¶transition :=  FM.proceed( '*', ¶act );
      if ¶transition is null then ...
    */
    if FM._act_is_starred( ¶act ) then
      /* Starred acts always succeed, even on an empty journal where there is no previous act and, thus, no
      tail; when can therefore always set the tail to '*'. */
      ¶tail := '*';
    -- .....................................................................................................
    else
      /* ### TAINT consider to use lag() instead */
      select into ¶tail point from FM.journal order by aid desc limit 1;
      end if;
    -- .....................................................................................................
    /* Obtain transition from tail and act: */
    ¶transition :=  FM.proceed( ¶tail, ¶act );
    -- .....................................................................................................
    /* Error out in case no matching transition was found: */
    if ¶transition is null then
      perform log( 'FM #19001', 'Journal up to problematic act:' );
      perform log( FM._journal_as_tabular() );
      raise exception
        'invalid act: { state: %, act: %, data: %, } -> null',
          ¶tail, ¶act, ¶data;
      end if;
    -- .....................................................................................................
    /* Perform associated SMAL pre-update commands: */
    -- X := json_agg( t )::text from ( select ¶transition ) as t; perform log( '00902', 'transition', X );
    perform FM.smal( ¶transition.precmd, ¶data, ¶transition );
    -- .....................................................................................................
    /* Insert new line into journal and update register copy: */
    insert into FM.journal ( tail, act, point, precmd, postcmd, data ) values
      ( ¶tail,
        ¶act,
        ¶transition.point,
        regexp_replace( ¶transition.precmd,   '^NOP$', '' ),
        regexp_replace( ¶transition.postcmd,  '^NOP$', '' ),
        ¶data )
      returning aid into ¶aid;
    -- .....................................................................................................
    /* Perform associated SMAL post-update commands: */
    perform FM.smal( ¶transition.postcmd, ¶data, ¶transition );
    -- .....................................................................................................
    /* Reflect state of registers table into `journal ( registers )`: */
    update FM.journal set registers = FM.registers_as_jsonb_object() where aid = ¶aid;
    -- .....................................................................................................
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.push( ¶act text, ¶data text ) returns void volatile language sql as $$
  select FM.push( ¶act, jb( ¶data ) ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.push( ¶act text, ¶data anyelement ) returns void volatile language sql as $$
  select FM.push( ¶act, jb( ¶data ) ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.push( ¶act text ) returns void volatile language sql as $$
  select FM.push( ¶act, jb( null ) ); $$;




/* ====================================================================================================== */
/* #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #  */
/*  #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  #   */
/*   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #    */
/*  #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  #   */
/* #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #  */
/* ====================================================================================================== */
/*

███████╗███╗   ███╗ █████╗ ██╗
██╔════╝████╗ ████║██╔══██╗██║
███████╗██╔████╔██║███████║██║
╚════██║██║╚██╔╝██║██╔══██║██║
███████║██║ ╚═╝ ██║██║  ██║███████╗
╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝ http://www.patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=SMAL

FM Assembly Language

NOP       # no operation (may also use SQL `null` value)
NUL *     # set all registers to NULL
NUL Y     # set register Y to NULL
LOD T     # load data to register T
MOV T C   # move contents of register T to register C and set register T to NULL
PSH C     # push data to register C (will become a list if not already a list)
PSH T C   # push contents of register T to register C and set register T to NULL
PSH * R   # push (and then clear) all registers as a JSONb object into R

*/

/* ====================================================================================================== */
/* #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #  */
/*  #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  #   */
/*   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #    */
/*  #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  #   */
/* #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #  */
/* ====================================================================================================== */

-- -- ---------------------------------------------------------------------------------------------------------
-- create type FM._smal_cmd_output as ( count integer, next_cmd text, error text );

-- -- ---------------------------------------------------------------------------------------------------------
-- create function FM._smal_clr( ¶cmd_parts text[], ¶data jsonb )
--   returns FM._smal_cmd_output volatile language plpgsql as $$
--   declare
--     R             FM._smal_cmd_output;
--   begin
--     R := ( 0, null );
--     if array_length( ¶cmd_parts, 1 ) = 1 then
--       truncate table FM.journal;
--       R.next_cmd := 'NUL *';
--     else
--       R.error := 'CLR does not accept arguments';
--       end if;
--     return R; end; $$;

-- -- ---------------------------------------------------------------------------------------------------------
-- create function FM._smal_nul( ¶cmd_parts text[], ¶data jsonb )
--   returns FM._smal_cmd_output volatile language plpgsql as $$
--   declare
--     R             FM._smal_cmd_output;
--     ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
--     ¶regkey_2     text    :=  ¶cmd_parts[ 3 ];
--   begin
--     R         := ( 0, null );
--     ¶regkey_1 := ¶cmd_parts[ 2 ];
--     -- .....................................................................................................
--     if ¶regkey_1 = '*' then
--       if ¶regkey_2 is null then
--         update FM.registers set data = null;
--       else
--         if ¶regkey_2 = '*' then
--           R.error = 'second argument to PSH can not be star';
--           return R;
--           end if;
--         update FM.registers set data = null where regkey != ¶regkey_2;
--       end if;
--     -- .....................................................................................................
--     else
--       update FM.registers set data = null where regkey = ¶regkey_1 returning 1 into R.count;
--       end if;
--     -- .....................................................................................................
--     return R; end; $$;

-- -- ---------------------------------------------------------------------------------------------------------
-- create function FM._smal_lod( ¶cmd_parts text[], ¶data jsonb )
--   returns FM._smal_cmd_output volatile language plpgsql as $$
--   declare
--     R             FM._smal_cmd_output;
--     ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
--   begin
--     R := ( 0, null );
--     update FM.registers
--       set data = to_jsonb( ¶data )
--       where regkey = ¶regkey_1 returning 1 into R.count;
--     return R; end; $$;

-- -- ---------------------------------------------------------------------------------------------------------
-- create function FM._smal_mov( ¶cmd_parts text[], ¶data jsonb )
--   returns FM._smal_cmd_output volatile language plpgsql as $$
--   declare
--     R             FM._smal_cmd_output;
--     ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
--     ¶regkey_2     text    :=  ¶cmd_parts[ 3 ];
--   begin
--     R := ( 0, null );
--     update FM.registers
--       set data = r1.data from ( select data from FM.registers where regkey = ¶regkey_1 ) as r1
--       where regkey = ¶regkey_2 returning 1 into R.count;
--     if R.count is null then return R; end if;
--     update FM.registers set data = null where regkey = ¶regkey_1 returning 1 into R.count;
--     return R; end; $$;

-- -- ---------------------------------------------------------------------------------------------------------
-- create function FM._smal_get( ¶regkey text ) returns jsonb stable language sql as $$
--   select data from FM.registers where regkey = ¶regkey; $$;

-- -- ---------------------------------------------------------------------------------------------------------
-- create function FM._smal_set( ¶regkey text, ¶data jsonb ) returns void volatile language sql as $$
--   update FM.registers set data = ¶data where regkey = ¶regkey; $$;

-- -- ---------------------------------------------------------------------------------------------------------
-- create function FM._smal_psh( ¶cmd_parts text[], ¶data jsonb )
--   returns FM._smal_cmd_output volatile language plpgsql as $$
--   declare
--     R             FM._smal_cmd_output;
--     ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
--     ¶regkey_2     text    :=  ¶cmd_parts[ 3 ];
--     ¶target_key   text    :=  null;
--   -- .......................................................................................................
--   begin
--     R := ( 0, null );
--     -- .....................................................................................................
--     if ¶regkey_2 is null then
--       ¶target_key :=  ¶regkey_1;
--       if ¶target_key = '*' then
--         R.error = 'PSH * is invalid without target register key';
--         return R;
--         end if;
--     -- .....................................................................................................
--     else
--       ¶target_key :=  ¶regkey_2;
--       if ¶target_key = '*' then
--         R.error = 'unable to push to star register';
--         return R;
--         end if;
--       if ¶regkey_1 = '*' then
--         perform FM._smal_psh_data( ¶target_key, FM.registers_as_jsonb_object( ¶target_key ) );
--         R.next_cmd  := format( 'NUL * %s', ¶target_key );
--       else
--         ¶data       :=  FM._smal_get( ¶regkey_1 );
--         R.next_cmd  := format( 'NUL %s', ¶regkey_1 );
--         end if;
--       end if;
--     -- .....................................................................................................
--     return R; end; $$;


-- -- ---------------------------------------------------------------------------------------------------------
-- create function FM._smal_psh_data( ¶regkey text, ¶data jsonb )
--   returns void volatile language plpgsql as $$
--   declare
--     ¶target       jsonb;
--     ¶target_type  text;
--   begin
--     ¶target       := FM._smal_get( ¶regkey );
--     ¶target_type  :=  jsonb_typeof( ¶target );
--     -- .....................................................................................................
--     if ( ¶target_type is null ) or ( ¶target_type = 'null' ) then
--       ¶target = '[]'::jsonb;
--     -- .....................................................................................................
--     elsif ( ¶target_type != 'array' ) then
--       ¶target = jsonb_build_array( ¶target );
--       end if;
--     -- .....................................................................................................
--     ¶target := ¶target || ¶data;
--     perform FM._smal_set( ¶regkey, ¶target );
--     -- .....................................................................................................
--     end; $$;

-- -- ---------------------------------------------------------------------------------------------------------
-- create function FM.smal( ¶cmd text, ¶data jsonb, ¶transition FM.transition )
--   returns void volatile language plpgsql as $outer$
--   declare
--     ¶cmd_parts    text[];
--     ¶base         text;
--     ¶regkey_1     text;
--     ¶regkey_2     text;
--     S             FM._smal_cmd_output;
--   -- .......................................................................................................
--   begin
--     S := ( 0, null );
--     -- .....................................................................................................
--     loop
--       -- ...................................................................................................
--       if S.next_cmd is not null then
--         ¶cmd        :=  S.next_cmd;
--         S.next_cmd  :=  null;
--         end if;
--       -- ...................................................................................................
--       /* ### TAINT should check whether there are extraneous arguments with NOP */
--       if ( ¶cmd is null ) or ( ¶cmd = 'NOP' ) or ( ¶cmd = '' ) then return; end if;
--       ¶cmd        :=  trim( both from ¶cmd );
--       ¶cmd_parts  :=  regexp_split_to_array( ¶cmd, '\s+' );
--       ¶base       :=  ¶cmd_parts[ 1 ];
--       -- ...................................................................................................
--       case ¶base
--         when 'CLR' then S := FM._smal_clr( ¶cmd_parts, ¶data );
--         when 'NUL' then S := FM._smal_nul( ¶cmd_parts, ¶data );
--         when 'LOD' then S := FM._smal_lod( ¶cmd_parts, ¶data );
--         when 'MOV' then S := FM._smal_mov( ¶cmd_parts, ¶data );
--         when 'PSH' then S := FM._smal_psh( ¶cmd_parts, ¶data );
--         else
--           perform log();
--           perform log( 'FM #19002', 'Journal up to problematic act:' );     perform log();
--           perform log( FM._journal_as_tabular() );                          perform log();
--           perform log( 'FM #19003', 'transition: %', ¶transition::text );   perform log();
--           raise exception 'unknown command %', ¶cmd;
--         end case;
--       -- ...................................................................................................
--       if    S.error is not  null  then raise exception 'error %  in command %', S.error, ¶cmd;
--       elsif S.count is      null  then raise exception 'invalid regkey in %', ¶cmd; end if;
--       -- ...................................................................................................
--       exit when S.next_cmd is null;
--       end loop;
--     end; $outer$;



/* ====================================================================================================== */
/* #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #  */
/*  #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  #   */
/*   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #   # . . #    */
/*  #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  # #  . .  #   */
/* #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #    .    #  */
/* ====================================================================================================== */


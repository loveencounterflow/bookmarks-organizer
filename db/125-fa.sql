





/* thx to http://felixge.de/2017/07/27/implementing-state-machines-in-postgresql.html */


/* http://www.patorjk.com/software/taag/#p=display&f=Fraktur&t=Fa

    .....
 .H#######x.  '`+
:############x.  !
#~    `"*########"       u
!      .  `f""""      us###u.
 ~:...-` :#L <)##: .@## "####"
    .   :###:>X##! 9###  9###
 :~"##x 4####X ^`  9###  9###
<  :###k'#####X    9###  9###
  d####f '#####X   9###  9###
 :####!    ?####>  "###*""###"
 X###!      ####~   ^Y"   ^Y'
 '###       X##f
  '%#:     .#*"
     ^----~"`
       Finite Automaton
*/


-- ---------------------------------------------------------------------------------------------------------
drop schema if exists FA cascade;
create schema FA;

-- ---------------------------------------------------------------------------------------------------------
/* STATES AND ACTS */

-- ---------------------------------------------------------------------------------------------------------
create table FA.states (
  state text unique not null primary key );

-- ---------------------------------------------------------------------------------------------------------
create table FA.acts (
  act text unique not null primary key );

-- ---------------------------------------------------------------------------------------------------------
/* TRANSITIONS */

-- ---------------------------------------------------------------------------------------------------------
create type FA._transition as (
  tail          text,
  act           text,
  precmd        text,
  point         text,
  postcmd       text );

-- -- ---------------------------------------------------------------------------------------------------------
create table FA.transitions (
  tail          text                    references FA.states    ( state   ),
  act           text                    references FA.acts      ( act     ),
  precmd        text,
  point         text                    references FA.states    ( state   ),
  postcmd       text,
  primary key ( tail, act ) );

-- -- ---------------------------------------------------------------------------------------------------------
create function FA._act_is_starred( ¶act text ) returns boolean stable language sql as $$
  select exists ( select 1 from FA.transitions where act = ¶act and tail = '*' ); $$;

-- -- ---------------------------------------------------------------------------------------------------------
create function FA._star_count_ok( ¶tail text, ¶act text ) returns boolean volatile language sql as $$
  select case when ¶tail = '*' or FA._act_is_starred( ¶act ) then
    ( select count(*) = 0 from FA.transitions where act = ¶act )
    else true end; $$;

-- ---------------------------------------------------------------------------------------------------------
alter table FA.transitions
  add constraint "starred acts must have no more than one transition"
  check ( FA._star_count_ok( tail, act ) );

-- ---------------------------------------------------------------------------------------------------------
create function FA.proceed( ¶tail text, ¶act text ) returns FA.transitions stable language sql as $$
  select * from FA.transitions where ( tail = ¶tail ) and ( act = ¶act ); $$;

-- ---------------------------------------------------------------------------------------------------------
/* REGISTERS */

-- ---------------------------------------------------------------------------------------------------------
/* `FA.registers` is where registers are defined: */
create table FA.registers (
  id      serial,
  regkey  text unique not null primary key check ( regkey::U.chr = regkey ),
  name    text unique not null,
  comment text );

-- ---------------------------------------------------------------------------------------------------------
/* ...and the 'board' is where register data gets collected. 'BC' is the board counter, which identifies
  rows; referenced by `FA.journal ( bc )`: */
create table FA.board ( bc serial primary key );

-- ---------------------------------------------------------------------------------------------------------
create function FA.bc() returns integer stable language sql as $$
  select max( bc ) from FA.board; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FA.new_boardline() returns void stable language sql as $$
  /* thx to https://stackoverflow.com/a/12336849/7568091 */
  insert into fa.board values ( default ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FA.registers_as_jsonb_object() returns jsonb stable language sql as $$
  select U.facets_as_jsonb_object( 'select regkey, data from FA.registers' ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FA.registers_as_jsonb_object( ¶except_regkey text ) returns jsonb stable language sql as $$
  select U.facets_as_jsonb_object(
    format( 'select regkey, data from FA.registers where regkey != %L', ¶except_regkey ) ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FA._get_adapt_board_statement() returns text volatile language plpgsql as $outer$
  declare
    R         text;
    ¶q        text[];
    ¶row      record;
  begin
    -- .....................................................................................................
    select
        array_agg(
          format( E'alter table FA.board add column %I jsonb default null;\n', regkey )
          order by id )
      from FA.registers
      into ¶q;
    -- .....................................................................................................
    R := array_to_string( ¶q, '' );
    return R;
    end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function FA.adapt_board() returns void volatile language plpgsql as $outer$
  begin
    execute FA._get_adapt_board_statement();
    end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
/* JOURNAL */

-- ---------------------------------------------------------------------------------------------------------
create table FA.raw_journal (
  aid           serial    primary key,
  bc            integer                 references FA.board     ( bc      ),
  tail          text                    references FA.states    ( state   ),
  act           text      not null      references FA.acts      ( act     ),
  point         text                    references FA.states    ( state   ),
  precmd        text,
  postcmd       text,
  data          jsonb,
  registers     jsonb );

-- ---------------------------------------------------------------------------------------------------------
create view FA.raw_result as ( select * from FA.raw_journal where point = 'LAST' );

-- ---------------------------------------------------------------------------------------------------------
create function FA._get_create_journal_statement() returns text volatile language plpgsql as $outer$
  declare
    R         text;
    ¶regkeys  text[];
    ¶row      record;
  begin
    -- .....................................................................................................
    R := '
      create view FA.journal as ( select
          j1.aid      as aid,
          j1.tail     as tail,
          j1.act      as act,
          j1.point    as point,
          j1.precmd   as precmd,
          j1.postcmd  as postcmd,
          j1.data     as data,
          ';
    -- .....................................................................................................
    select
        array_agg( format( 'j2.%I', regkey ) order by id )
      from FA.registers
      into ¶regkeys;
    -- .....................................................................................................
    R := R || array_to_string( ¶regkeys, ', ' );
    R := R || E'\n        from FA.raw_journal as j1
      left join ( select
        aid,
        ';
    -- .....................................................................................................
    select
        array_agg( format( 'registers->>%L as %I', regkey, regkey ) order by id )
      from FA.registers
      into ¶regkeys;
    -- .....................................................................................................
    R := R || array_to_string( ¶regkeys, ', ' );
    R := R || E'\n        from FA.raw_journal ) as j2 using ( aid ) );';
    -- .....................................................................................................
    return R; end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function FA.create_journal() returns void volatile language plpgsql as $outer$
  begin
    drop view if exists FA.journal; -- cascade???
    drop view if exists FA.result; -- cascade???
    execute FA._get_create_journal_statement();
    create view FA.result as ( select * from FA.journal where point = 'LAST' );
    end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function FA._journal_as_tabular() returns text
  immutable strict language sql as $outer$
    select U.tabulate_query( $$ select * from FA.journal order by aid; $$ );
    $outer$;

-- ---------------------------------------------------------------------------------------------------------
/* PUSH */

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT should probably use `lock for update` */
create function FA.push( ¶act text, ¶data jsonb ) returns void volatile language plpgsql as $$
  declare
    ¶new_state  text;
    ¶tail       text;
    ¶aid        integer;
    ¶transition FA._transition;
  -- .......................................................................................................
  begin
    /* ### TAINT rewrite this as
      ¶transition :=  FA.proceed( '*', ¶act );
      if ¶transition is null then ...
    */
    if FA._act_is_starred( ¶act ) then
      /* Starred acts always succeed, even on an empty raw_journal where there is no previous act and, thus, no
      tail; when can therefore always set the tail to '*'. */
      ¶tail := '*';
    -- .....................................................................................................
    else
      /* ### TAINT consider to use lag() instead */
      select into ¶tail point from FA.raw_journal order by aid desc limit 1;
      end if;
    -- .....................................................................................................
    /* Obtain transition from tail and act: */
    ¶transition :=  FA.proceed( ¶tail, ¶act );
    -- .....................................................................................................
    /* Error out in case no matching transition was found: */
    if ¶transition is null then
      perform log( 'FA #19001', 'Journal up to problematic act:' );
      perform log( FA._journal_as_tabular() );
      raise exception
        'invalid act: { state: %, act: %, data: %, } -> null',
          ¶tail, ¶act, ¶data;
      end if;
    -- .....................................................................................................
    /* Perform associated SMAL pre-update commands: */
    -- X := json_agg( t )::text from ( select ¶transition ) as t; perform log( '00902', 'transition', X );
    perform FA.smal( ¶transition.precmd, ¶data, ¶transition );
    -- .....................................................................................................
    /* Insert new line into raw_journal and update register copy: */
    insert into FA.raw_journal ( tail, act, point, precmd, postcmd, data ) values
      ( ¶tail,
        ¶act,
        ¶transition.point,
        regexp_replace( ¶transition.precmd,   '^NOP$', '' ),
        regexp_replace( ¶transition.postcmd,  '^NOP$', '' ),
        ¶data )
      returning aid into ¶aid;
    -- .....................................................................................................
    /* Perform associated SMAL post-update commands: */
    perform FA.smal( ¶transition.postcmd, ¶data, ¶transition );
    -- .....................................................................................................
    /* Reflect state of registers table into `raw_journal ( registers )`: */
    update FA.raw_journal set registers = FA.registers_as_jsonb_object() where aid = ¶aid;
    -- .....................................................................................................
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FA.push( ¶act text, ¶data text ) returns void volatile language sql as $$
  select FA.push( ¶act, jb( ¶data ) ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FA.push( ¶act text, ¶data anyelement ) returns void volatile language sql as $$
  select FA.push( ¶act, jb( ¶data ) ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FA.push( ¶act text ) returns void volatile language sql as $$
  select FA.push( ¶act, jb( null ) ); $$;



/*

███████╗███╗   ███╗ █████╗ ██╗
██╔════╝████╗ ████║██╔══██╗██║
███████╗██╔████╔██║███████║██║
╚════██║██║╚██╔╝██║██╔══██║██║
███████║██║ ╚═╝ ██║██║  ██║███████╗
╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝ http://www.patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=SMAL

FA Assembly Language

NOP       # no operation (may also use SQL `null` value)
NUL *     # set all registers to NULL
NUL Y     # set register Y to NULL
LOD T     # load data to register T
MOV T C   # move contents of register T to register C and set register T to NULL
PSH C     # push data to register C (will become a list if not already a list)
PSH T C   # push contents of register T to register C and set register T to NULL
PSH * R   # push (and then clear) all registers as a JSONb object into R

*/

-- ---------------------------------------------------------------------------------------------------------
create type FA._smal_cmd_output as ( count integer, next_cmd text, error text );

-- ---------------------------------------------------------------------------------------------------------
create function FA._smal_clr( ¶cmd_parts text[], ¶data jsonb )
  returns FA._smal_cmd_output volatile language plpgsql as $$
  declare
    R             FA._smal_cmd_output;
  begin
    R := ( 0, null );
    if array_length( ¶cmd_parts, 1 ) = 1 then
      truncate table FA.raw_journal;
      R.next_cmd := 'NUL *';
    else
      R.error := 'CLR does not accept arguments';
      end if;
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FA._smal_nul( ¶cmd_parts text[], ¶data jsonb )
  returns FA._smal_cmd_output volatile language plpgsql as $$
  declare
    R             FA._smal_cmd_output;
    ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
    ¶regkey_2     text    :=  ¶cmd_parts[ 3 ];
  begin
    R         := ( 0, null );
    ¶regkey_1 := ¶cmd_parts[ 2 ];
    -- .....................................................................................................
    if ¶regkey_1 = '*' then
      if ¶regkey_2 is null then
        update FA.registers set data = null;
      else
        if ¶regkey_2 = '*' then
          R.error = 'second argument to PSH can not be star';
          return R;
          end if;
        update FA.registers set data = null where regkey != ¶regkey_2;
      end if;
    -- .....................................................................................................
    else
      update FA.registers set data = null where regkey = ¶regkey_1 returning 1 into R.count;
      end if;
    -- .....................................................................................................
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FA._smal_lod( ¶cmd_parts text[], ¶data jsonb )
  returns FA._smal_cmd_output volatile language plpgsql as $$
  declare
    R             FA._smal_cmd_output;
    ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
  begin
    R := ( 0, null );
    update FA.registers
      set data = to_jsonb( ¶data )
      where regkey = ¶regkey_1 returning 1 into R.count;
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FA._smal_mov( ¶cmd_parts text[], ¶data jsonb )
  returns FA._smal_cmd_output volatile language plpgsql as $$
  declare
    R             FA._smal_cmd_output;
    ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
    ¶regkey_2     text    :=  ¶cmd_parts[ 3 ];
  begin
    R := ( 0, null );
    update FA.registers
      set data = r1.data from ( select data from FA.registers where regkey = ¶regkey_1 ) as r1
      where regkey = ¶regkey_2 returning 1 into R.count;
    if R.count is null then return R; end if;
    update FA.registers set data = null where regkey = ¶regkey_1 returning 1 into R.count;
    return R; end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FA._smal_get( ¶regkey text ) returns jsonb stable language sql as $$
  select data from FA.registers where regkey = ¶regkey; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FA._smal_set( ¶regkey text, ¶data jsonb ) returns void volatile language sql as $$
  update FA.registers set data = ¶data where regkey = ¶regkey; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FA._smal_psh( ¶cmd_parts text[], ¶data jsonb )
  returns FA._smal_cmd_output volatile language plpgsql as $$
  declare
    R             FA._smal_cmd_output;
    ¶regkey_1     text    :=  ¶cmd_parts[ 2 ];
    ¶regkey_2     text    :=  ¶cmd_parts[ 3 ];
    ¶target_key   text    :=  null;
  -- .......................................................................................................
  begin
    R := ( 0, null );
    -- .....................................................................................................
    if ¶regkey_2 is null then
      ¶target_key :=  ¶regkey_1;
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
        perform FA._smal_psh_data( ¶target_key, FA.registers_as_jsonb_object( ¶target_key ) );
        R.next_cmd  := format( 'NUL * %s', ¶target_key );
      else
        ¶data       :=  FA._smal_get( ¶regkey_1 );
        R.next_cmd  := format( 'NUL %s', ¶regkey_1 );
        end if;
      end if;
    -- .....................................................................................................
    return R; end; $$;


-- ---------------------------------------------------------------------------------------------------------
create function FA._smal_psh_data( ¶regkey text, ¶data jsonb )
  returns void volatile language plpgsql as $$
  declare
    ¶target       jsonb;
    ¶target_type  text;
  begin
    ¶target       := FA._smal_get( ¶regkey );
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
    perform FA._smal_set( ¶regkey, ¶target );
    -- .....................................................................................................
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FA.smal( ¶cmd text, ¶data jsonb, ¶transition FA._transition )
  returns void volatile language plpgsql as $outer$
  declare
    ¶cmd_parts    text[];
    ¶base         text;
    ¶regkey_1     text;
    ¶regkey_2     text;
    S             FA._smal_cmd_output;
  -- .......................................................................................................
  begin
    S := ( 0, null );
    -- .....................................................................................................
    loop
      -- ...................................................................................................
      if S.next_cmd is not null then
        ¶cmd        :=  S.next_cmd;
        S.next_cmd  :=  null;
        end if;
      -- ...................................................................................................
      /* ### TAINT should check whether there are extraneous arguments with NOP */
      if ( ¶cmd is null ) or ( ¶cmd = 'NOP' ) or ( ¶cmd = '' ) then return; end if;
      ¶cmd        :=  trim( both from ¶cmd );
      ¶cmd_parts  :=  regexp_split_to_array( ¶cmd, '\s+' );
      ¶base       :=  ¶cmd_parts[ 1 ];
      -- ...................................................................................................
      case ¶base
        when 'CLR' then S := FA._smal_clr( ¶cmd_parts, ¶data );
        when 'NUL' then S := FA._smal_nul( ¶cmd_parts, ¶data );
        when 'LOD' then S := FA._smal_lod( ¶cmd_parts, ¶data );
        when 'MOV' then S := FA._smal_mov( ¶cmd_parts, ¶data );
        when 'PSH' then S := FA._smal_psh( ¶cmd_parts, ¶data );
        else
          perform log();
          perform log( 'FA #19002', 'Journal up to problematic act:' );     perform log();
          perform log( FA._journal_as_tabular() );                          perform log();
          perform log( 'FA #19003', 'transition: %', ¶transition::text );   perform log();
          raise exception 'unknown command %', ¶cmd;
        end case;
      -- ...................................................................................................
      if    S.error is not  null  then raise exception 'error %  in command %', S.error, ¶cmd;
      elsif S.count is      null  then raise exception 'invalid regkey in %', ¶cmd; end if;
      -- ...................................................................................................
      exit when S.next_cmd is null;
      end loop;
    end; $outer$;



/* ====================================================================================================== */

-- ---------------------------------------------------------------------------------------------------------
insert into FA.registers ( regkey, name, comment ) values
  ( 'C', 'context',   'a list of strings when the tag is written as path with slashes' ),
  ( 'T', 'tag',       'the tag itself; in the case of path notation, the last part of the path' ),
  ( 'V', 'value',     'written after an equals sign, the value of a valued tag, as in `color=red`' ),
  ( 'Y', 'type',      'the type of a tag, written with a double colon, as in `Mickey::name`' ),
  ( 'R', 'result',    'list of results' );

-- ---------------------------------------------------------------------------------------------------------
insert into FA.states values
   ( '*'          ),
   ( 'FIRST'      ),
   ( 's1'         ),
   ( 's2'         ),
   ( 's3'         ),
   ( 's4'         ),
   ( 's5'         ),
   ( 's6'         ),
   ( 'LAST'       );

-- ---------------------------------------------------------------------------------------------------------
insert into FA.acts values
  ( 'CLEAR'           ),
  ( 'START'           ),
  ( 'identifier'      ),
  ( 'slash'           ),
  ( 'equals'          ),
  ( 'dcolon'          ),
  ( 'blank'           ),
  ( 'RESET'           ),
  ( 'STOP'            );

-- ---------------------------------------------------------------------------------------------------------
insert into FA.transitions
  ( tail,                 act,                precmd,       point,          postcmd           ) values
  -- .......................................................................................................
  /* reset: */
  ( '*',                  'RESET',            'CLR',        'FIRST',        'NOP'             ),
  -- .......................................................................................................
  /* inceptive states: */
  ( 'LAST',               'CLEAR',            'CLR',        'FIRST',        'NOP'             ),
  ( 'FIRST',              'CLEAR',            'CLR',        'FIRST',        'NOP'             ),
  ( 'FIRST',              'START',            'NUL *',      's1',           'NOP'             ),
  -- .......................................................................................................
  /* intermediate states: */
  ( 's1',                 'identifier',       'LOD T',      's2',           'NOP'             ),
  ( 's2',                 'equals',           'NOP',        's3',           'NOP'             ),
  ( 's2',                 'slash',            'PSH T C',    's1',           'NOP'             ),
  ( 's3',                 'identifier',       'LOD V',      's4',           'NOP'             ),
  ( 's4',                 'dcolon',           'NOP',        's5',           'NOP'             ),
  ( 's5',                 'identifier',       'LOD Y',      's6',           'NOP'             ),
  -- .......................................................................................................
  /* states that indicate completion and lead to next item: */
  ( 's1',                 'blank',            'PSH * R',    's1',           'NOP'             ),
  ( 's2',                 'blank',            'PSH * R',    's1',           'NOP'             ),
  ( 's6',                 'blank',            'PSH * R',    's1',           'NOP'             ),
  ( 's4',                 'blank',            'PSH * R',    's1',           'NOP'             ),
  -- .......................................................................................................
  /* states that indicate completion and lead to STOP: */
  ( 's1',                 'STOP',             'PSH * R',    'LAST',         'NOP'             ),
  ( 's2',                 'STOP',             'PSH * R',    'LAST',         'NOP'             ),
  ( 's6',                 'STOP',             'PSH * R',    'LAST',         'NOP'             ),
  ( 's4',                 'STOP',             'PSH * R',    'LAST',         'NOP'             );



-- ---------------------------------------------------------------------------------------------------------
do $$ begin
  perform FA.create_journal();
  perform FA.adapt_board();
  perform FA.push( 'RESET' );
  end; $$;


/* ###################################################################################################### */

-- select array_agg( tail ) as "start" from FA.transitions where act = 'START';
-- select array_agg( tail ) as "stop"  from FA.transitions where act = 'STOP';
-- select array_agg( tail ) as "reset" from FA.transitions where act = 'RESET';
-- select array_agg( tail ) as "clear" from FA.transitions where act = 'CLEAR';
-- select exists ( select 1 from FA.transitions where act = 'RESET' and tail = '*' );
-- select exists ( select 1 from FA.transitions where act = 'CLEAR' and tail = '*' );


create function FA.feed_pairs( ¶acts_and_data text[] ) returns jsonb volatile strict language plpgsql as $$
  declare
    R jsonb;
  begin
    perform FA.push( 'CLEAR'  );
    perform FA.push( 'START'  );
    perform FA.push( pair[ 1 ], pair[ 2 ] ) from U.unnest_2d_1d( ¶acts_and_data ) as pair;
    perform FA.push( 'STOP'   );
    R := FA.registers_as_jsonb_object();
    return R;
    end; $$;


select FA.feed_pairs( array[
    array[ 'identifier',  'foo'  ],
    array[ 'equals',      '::'   ],
    array[ 'identifier',  'q'    ]
    ] );





-- ---------------------------------------------------------------------------------------------------------
/* spaceships */
do $$ begin
  perform FA.push( 'RESET'                      );
  perform FA.push( 'START'                      );
  perform FA.push( 'identifier',  'spaceships'       );
  perform FA.push( 'STOP'                       );
  end; $$;
-- perform FA.push( 'CLEAR'                      );
select * from FA.raw_journal;
select * from FA.journal;

-- ---------------------------------------------------------------------------------------------------------
/* color=red */
do $$ begin
  perform FA.push( 'RESET'                      );
  perform FA.push( 'START'                      );
  perform FA.push( 'identifier',  'color'       );
  perform FA.push( 'equals',      '='           );
  -- perform FA.push( 'equals',      '='          );
  -- perform FA.push( 'START',      null           );
  perform FA.push( 'identifier',  'red'         );
  perform FA.push( 'STOP'                       );
  end; $$;
-- perform FA.push( 'CLEAR'                      );
select * from FA.raw_journal;
select * from FA.journal;


/* foo::q */
do $$ begin
  perform FA.push( 'RESET'                      );
  perform FA.push( 'START'                      );
  -- perform FA.push( 'STOP'                      );
  perform FA.push( 'identifier',  'foo'         );
  perform FA.push( 'equals',      '::'          );
  -- perform FA.push( 'equals',      '='          );
  perform FA.push( 'identifier',  'q'           );
  perform FA.push( 'STOP'                       );
  end; $$;
select * from FA.raw_journal;
select * from FA.journal;

/* author=Faulkner::name */
do $$ begin
  perform FA.push( 'CLEAR'                      );
  perform FA.push( 'START'                      );
  perform FA.push( 'identifier',  'author'      );
  perform FA.push( 'equals',      '='           );
  perform FA.push( 'identifier',  'Faulkner'    );
  perform FA.push( 'dcolon',      '::'          );
  perform FA.push( 'identifier',  'name'        );
  perform FA.push( 'STOP'                       );
  -- perform FA.push( 'equals',      '='          );
  end; $$;
select * from FA.raw_journal;
select * from FA.journal;
select * from FA.registers;

/* IT/programming/language=SQL::name */
/* '{IT,/,programming,/,language,=,SQL,::,name}' */
do $$ begin
  perform FA.push( 'CLEAR'                        );
  perform FA.push( 'START'                        );
  perform FA.push( 'identifier',  'IT'            );
  perform FA.push( 'slash',       '/'             );
  perform FA.push( 'identifier',  'programming'   );
  perform FA.push( 'slash',       '/'             );
  perform FA.push( 'identifier',  'language'      );
  perform FA.push( 'equals',      '='             );
  perform FA.push( 'identifier',  'SQL'           );
  perform FA.push( 'dcolon',      '::'            );
  perform FA.push( 'identifier',  'name'          );
  perform FA.push( 'blank',       ' '             );
  perform FA.push( 'identifier',  'mytag'         );
  perform FA.push( 'STOP'                         );
  end; $$;
select * from FA.raw_journal;
select * from FA.journal;
select * from FA.result;
select * from FA.raw_result;


-- ---------------------------------------------------------------------------------------------------------
-- \echo 'journal'
-- select * from FA.journal;
-- \echo 'journal (completed)'
-- select * from FA.journal where point = 'LAST';
-- select * from FA.receiver;
-- \echo 'transitions'
-- select * from FA.transitions;
-- \echo '_batches_events_and_next_states'
-- select * from FA._batches_events_and_next_states;
-- \echo 'job_transitions'
-- select * from FA.job_transitions;

\quit

select * from FA.registers order by regkey;
do $$ begin perform FA.LOD( 3, 'C' ); end; $$;
select * from FA.registers order by regkey;



-- ---------------------------------------------------------------------------------------------------------



\quit




------------------------------------+------------------------------------------------------------------------
notation                            |  context          tag         value       type
------------------------------------+------------------------------------------------------------------------
color=red                           |  ∎                color       red         ∎
IT/programming/language=SQL::name   |  IT/programming   language    SQL         name
foo::q                              |  ∎                foo         ∎           q




\quit



create table FA.journal (
  aid serial primary key,
  foo text
  );
create table FA.registers (
  aid integer references FA.journal ( aid ),
  facets jsonb
  );

insert into FA.journal ( foo ) values ( 42 ), ( 'helo' ), ( array[ 1, '2' ] );
insert into FA.registers values ( 1, '{"a":1,"b":2}' );
insert into FA.registers values ( 2, '{"a":42,"b":12}' );
select * from FA.journal;
select * from FA.registers;

select from FA.journal;

-- select aid, ( select * from jsonb_each( facets ) ) as v1 from FA.registers;
-- select
--     j.aid,
--     j.foo,

--   from FA.journal as j
--   left join FA.registers as r using ( aid );

\quit


/* aggregate function */

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT probably better to use domains or other means to ensure integrity */
create function FA.proceed( ¶tail text, ¶act text ) returns text stable language plpgsql as $$
  declare
    R text;
  begin
    select into R
        point
      from FA.transitions
      where ( tail = ¶tail ) and ( act = ¶act );
    return R;
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create aggregate FA.proceed_agg( text ) (
  sfunc     = FA.proceed,
  stype     = text,
  initcond  = 'FIRST' );


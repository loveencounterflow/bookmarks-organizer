
-- /* ################################################################### */
-- /* ################################################################### */
-- /* ################################################################### */
-- -- ---------------------------------------------------------------------------------------------------------
-- insert into FM.registers ( regkey, name, comment ) values
--   ( 'C', 'context',   'a list of strings when the tag is written as path with slashes' ),
--   ( 'T', 'tag',       'the tag itself; in the case of path notation, the last part of the path' ),
--   ( 'V', 'value',     'written after an equals sign, the value of a valued tag, as in `color=red`' ),
--   ( 'Y', 'type',      'the type of a tag, written with a double colon, as in `Mickey::name`' ),
--   ( 'R', 'result',    'list of results' );
-- -- ---------------------------------------------------------------------------------------------------------
-- insert into FM.states values
--    ( '*'          ),
--    ( 'FIRST'      ),
--    ( 's1'         ),
--    ( 's2'         ),
--    ( 's3'         ),
--    ( 's4'         ),
--    ( 's5'         ),
--    ( 's6'         ),
--    ( 'LAST'       );

-- -- ---------------------------------------------------------------------------------------------------------
-- insert into FM.acts values
--   ( 'CLEAR'           ),
--   ( 'START'           ),
--   ( 'identifier'      ),
--   ( 'slash'           ),
--   ( 'equals'          ),
--   ( 'dcolon'          ),
--   ( 'blank'           ),
--   ( 'RESET'           ),
--   ( 'STOP'            );

-- -- ---------------------------------------------------------------------------------------------------------
-- do $$ begin
--   perform FM.adapt_journal();
--   perform FM.adapt_board();
--   perform FM.adapt_copy_function();
--   perform FM.create_longboard();
--   perform FM.create_FMAS_set();
--   perform FM.create_FMAS_get();
--   -- perform FM.push( 'RESET' );
--   end; $$;

-- do $$ begin perform FM.new_boardline(); end; $$;
-- update FM.board set "C" = '11' where bc = FM.bc();
-- update FM.board set "T" = '12' where bc = FM.bc();
-- update FM.board set "V" = '13' where bc = FM.bc();
-- update FM.board set "Y" = '14' where bc = FM.bc();
-- update FM.board set "R" = '15' where bc = FM.bc();
-- do $$ begin perform FM.new_boardline(); end; $$;
-- update FM.board set "C" = '21' where bc = FM.bc();
-- update FM.board set "T" = '22' where bc = FM.bc();
-- update FM.board set "V" = '23' where bc = FM.bc();
-- update FM.board set "Y" = '24' where bc = FM.bc();
-- update FM.board set "R" = '25' where bc = FM.bc();
-- do $$ begin perform FM.new_boardline(); end; $$;
-- update FM.board set "C" = '31' where bc = FM.bc();
-- update FM.board set "T" = '32' where bc = FM.bc();
-- update FM.board set "V" = '33' where bc = FM.bc();
-- update FM.board set "Y" = '34' where bc = FM.bc();
-- update FM.board set "R" = '35' where bc = FM.bc();
-- insert into FM.journal ( aid, bc, act ) values ( 22, 1, 'START' );
-- select FM.copy_boardline_to_journal();
-- -- update FM.journal set
-- --   ( "C" ) = ( select "C" from FM.board where bc = FM.bc() )
-- --   where aid = FM.aid();

-- \echo FM.registers
-- select * from FM.registers;
-- \echo FM.transitions
-- select * from FM.transitions;
-- \echo FM.board
-- select * from FM.board;
-- \echo FM.journal
-- select * from FM.journal;
-- select FM.bc();
-- select FM.aid();

-- -- create view FM.longboard as (
-- --   select bc, 'C' as regkey, "C" from FM.board union all
-- --   select bc, 'T' as regkey, "T" from FM.board union all
-- --   select bc, 'V' as regkey, "V" from FM.board union all
-- --   select bc, 'Y' as regkey, "Y" from FM.board union all
-- --   select bc, 'R' as regkey, "R" from FM.board union all
-- --   select null, null, null where false
-- --   );
-- select * from FM.longboard where bc = FM.bc();
-- -- select FM.get_create_statement_for_longboard();
-- -- update FM.longboard set data = '"yay"' where bc = FM.bc() and regkey = 'Y';

-- -- -- ---------------------------------------------------------------------------------------------------------
-- -- create function FMAS.set( ¶regkey text, ¶data jsonb ) returns void volatile language plpgsql as $$
-- --   begin
-- --     case ¶regkey
-- --       when 'C' then update FM.board set "C" = ¶data where bc = FM.bc();
-- --       when 'Y' then update FM.board set "Y" = ¶data where bc = FM.bc();
-- --       else null; end case;
-- --   end; $$;


-- select FMAS.set( 'C', '[1,2,3]' );
-- select FMAS.set( 'Y', '"yay"' );
-- select * from FM.board;

-- xxx;

-- /* ################################################################### */
-- /* ################################################################### */
-- /* ################################################################### */






-- ---------------------------------------------------------------------------------------------------------
insert into FM.registers ( regkey, name, comment ) values
  ( 'C', 'context',   'a list of strings when the tag is written as path with slashes' ),
  ( 'T', 'tag',       'the tag itself; in the case of path notation, the last part of the path' ),
  ( 'V', 'value',     'written after an equals sign, the value of a valued tag, as in `color=red`' ),
  ( 'Y', 'type',      'the type of a tag, written with a double colon, as in `Mickey::name`' ),
  ( 'R', 'result',    'list of results' );

-- ---------------------------------------------------------------------------------------------------------
insert into FM.states values
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
insert into FM.acts values
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
insert into FM.transitions
  ( tail,                 act,                precmd,       point,          postcmd           ) values
  -- .......................................................................................................
  /* reset: */
  ( '*',                  'RESET',            'RST',        'FIRST',        'NOP'             ),
  -- .......................................................................................................
  /* inceptive states: */
  ( 'LAST',               'CLEAR',            'NOP',        'FIRST',        'NOP'             ),
  ( 'FIRST',              'CLEAR',            'NOP',        'FIRST',        'NOP'             ),
  -- ( 'LAST',               'CLEAR',            'CLR',        'FIRST',        'NOP'             ),
  -- ( 'FIRST',              'CLEAR',            'CLR',        'FIRST',        'NOP'             ),
  ( 'FIRST',              'START',            'ADV',        's1',           'NOP'             ),
  -- .......................................................................................................
  /* intermediate states: */
  -- ( 's0',                 '->',               'ADV',        's1',           'NOP'             ),
  ( 's1',                 'identifier',       'LOD T',      's2',           'NOP'             ),
  ( 's2',                 'equals',           'NOP',        's3',           'NOP'             ),
  ( 's2',                 'slash',            'PSH T C',    's1',           'NOP'             ),
  ( 's3',                 'identifier',       'LOD V',      's4',           'NOP'             ),
  ( 's4',                 'dcolon',           'NOP',        's5',           'NOP'             ),
  ( 's5',                 'identifier',       'LOD Y',      's6',           'NOP'             ),
  -- .......................................................................................................
  /* states that indicate completion and lead to next item: */
  ( 's1',                 'blank',            'ADV',        's1',           'NOP'             ), /* ### TAIN consider to abolish postcmd, multiple cmds in favor of 'walkthrough' actions with '->' */
  ( 's2',                 'blank',            'ADV',        's1',           'NOP'             ), /* ### TAIN consider to abolish postcmd, multiple cmds in favor of 'walkthrough' actions with '->' */
  ( 's6',                 'blank',            'ADV',        's1',           'NOP'             ), /* ### TAIN consider to abolish postcmd, multiple cmds in favor of 'walkthrough' actions with '->' */
  ( 's4',                 'blank',            'ADV',        's1',           'NOP'             ), /* ### TAIN consider to abolish postcmd, multiple cmds in favor of 'walkthrough' actions with '->' */
  -- .......................................................................................................
  /* states that indicate completion and lead to STOP: */
  ( 's1',                 'STOP',             'NOP',        'LAST',         'NOP'             ),
  ( 's2',                 'STOP',             'NOP',        'LAST',         'NOP'             ),
  ( 's6',                 'STOP',             'NOP',        'LAST',         'NOP'             ),
  ( 's4',                 'STOP',             'NOP',        'LAST',         'NOP'             );



-- ---------------------------------------------------------------------------------------------------------
do $$ begin
  perform FM.adapt_journal();
  perform FM.adapt_board();
  perform FM.adapt_copy_function();
  perform FM.create_longboard();
  perform FMAS.create_set();
  perform FMAS.create_get();
  perform FMAS.create_set_all();
  perform FMAS.create_set_all_except();
  perform FM.push( 'RESET' );
  end; $$;

select * from FM.registers;
select * from FM.transitions;
select * from FM.board;
select * from FM.journal;

/* ###################################################################################################### */

-- select array_agg( tail ) as "start" from FM.transitions where act = 'START';
-- select array_agg( tail ) as "stop"  from FM.transitions where act = 'STOP';
-- select array_agg( tail ) as "reset" from FM.transitions where act = 'RESET';
-- select array_agg( tail ) as "clear" from FM.transitions where act = 'CLEAR';
-- select exists ( select 1 from FM.transitions where act = 'RESET' and tail = '*' );
-- select exists ( select 1 from FM.transitions where act = 'CLEAR' and tail = '*' );

create function FM.get_registers() returns jsonb stable language plpgsql as $$
  declare
    R jsonb;
  begin
    select jsonb_build_object(
        'C', "C", 'T', "T", 'V', "V", 'Y', "Y", 'R', "R" ) from FM.board
      where bc = FM.bc()
      into R;
      return R; end; $$;

create function FM.get_registers_except( ¶regkey text ) returns jsonb stable language sql as $$
  select FM.get_registers() - ¶regkey; $$;

create function FM.feed_pairs( ¶acts_and_data text[] ) returns jsonb volatile strict language plpgsql as $$
  declare
    R jsonb;
  begin
    perform FM.push( 'CLEAR'  );
    perform FM.push( 'START'  );
    perform FM.push( pair[ 1 ], pair[ 2 ] ) from U.unnest_2d_1d( ¶acts_and_data ) as pair;
    perform FM.push( 'STOP'   );
    R := FM.get_registers();
    return R; end; $$;


-- select FM.feed_pairs( array[
--     array[ 'identifier',  'foo'  ],
--     array[ 'equals',      '::'   ],
--     array[ 'identifier',  'q'    ]
--     ] );





-- ---------------------------------------------------------------------------------------------------------
/* spaceships */
do $$ begin
  perform FM.push( 'CLEAR'                      );
  perform FM.push( 'START'                      );
  perform FM.push( 'identifier',  'spaceships'       );
  perform FM.push( 'blank',       ' '       );
  perform FM.push( 'identifier',  'planets'       );
  perform FM.push( 'STOP'                       );
  end; $$;
-- perform FM.push( 'CLEAR'                      );
select * from FM.journal;
select * from FM.board;

-- ---------------------------------------------------------------------------------------------------------
/* color=red */
do $$ begin
  perform FM.push( 'CLEAR'                      );
  perform FM.push( 'START'                      );
  perform FM.push( 'identifier',  'color'       );
  perform FM.push( 'equals',      '='           );
  -- perform FM.push( 'equals',      '='          );
  -- perform FM.push( 'START',      null           );
  perform FM.push( 'identifier',  'red'         );
  perform FM.push( 'STOP'                       );
  end; $$;
-- perform FM.push( 'CLEAR'                      );
select * from FM.journal;
select * from FM.board;
\quit


/* foo::q */
do $$ begin
  perform FM.push( 'RESET'                      );
  perform FM.push( 'START'                      );
  -- perform FM.push( 'STOP'                      );
  perform FM.push( 'identifier',  'foo'         );
  perform FM.push( 'equals',      '::'          );
  -- perform FM.push( 'equals',      '='          );
  perform FM.push( 'identifier',  'q'           );
  perform FM.push( 'STOP'                       );
  end; $$;
select * from FM.journal;
select * from FM.journal;

/* author=Faulkner::name */
do $$ begin
  perform FM.push( 'CLEAR'                      );
  perform FM.push( 'START'                      );
  perform FM.push( 'identifier',  'author'      );
  perform FM.push( 'equals',      '='           );
  perform FM.push( 'identifier',  'Faulkner'    );
  perform FM.push( 'dcolon',      '::'          );
  perform FM.push( 'identifier',  'name'        );
  perform FM.push( 'STOP'                       );
  -- perform FM.push( 'equals',      '='          );
  end; $$;
select * from FM.journal;
select * from FM.journal;
select * from FM.registers;

/* IT/programming/language=SQL::name */
/* '{IT,/,programming,/,language,=,SQL,::,name}' */
do $$ begin
  perform FM.push( 'CLEAR'                        );
  perform FM.push( 'START'                        );
  perform FM.push( 'identifier',  'IT'            );
  perform FM.push( 'slash',       '/'             );
  perform FM.push( 'identifier',  'programming'   );
  perform FM.push( 'slash',       '/'             );
  perform FM.push( 'identifier',  'language'      );
  perform FM.push( 'equals',      '='             );
  perform FM.push( 'identifier',  'SQL'           );
  perform FM.push( 'dcolon',      '::'            );
  perform FM.push( 'identifier',  'name'          );
  perform FM.push( 'blank',       ' '             );
  perform FM.push( 'identifier',  'mytag'         );
  perform FM.push( 'STOP'                         );
  end; $$;
select * from FM.journal;
-- select * from FM.result;
-- select * from FM.raw_result;


-- ---------------------------------------------------------------------------------------------------------
-- \echo 'journal'
-- select * from FM.journal;
-- \echo 'journal (completed)'
-- select * from FM.journal where point = 'LAST';
-- select * from FM.receiver;
-- \echo 'transitions'
-- select * from FM.transitions;
-- \echo '_batches_events_and_next_states'
-- select * from FM._batches_events_and_next_states;
-- \echo 'job_transitions'
-- select * from FM.job_transitions;

\quit

select * from FM.registers order by regkey;
do $$ begin perform FM.LOD( 3, 'C' ); end; $$;
select * from FM.registers order by regkey;



-- ---------------------------------------------------------------------------------------------------------



\quit




------------------------------------+------------------------------------------------------------------------
notation                            |  context          tag         value       type
------------------------------------+------------------------------------------------------------------------
color=red                           |  ∎                color       red         ∎
IT/programming/language=SQL::name   |  IT/programming   language    SQL         name
foo::q                              |  ∎                foo         ∎           q




\quit



create table FM.journal (
  aid serial primary key,
  foo text
  );
create table FM.registers (
  aid integer references FM.journal ( aid ),
  facets jsonb
  );

insert into FM.journal ( foo ) values ( 42 ), ( 'helo' ), ( array[ 1, '2' ] );
insert into FM.registers values ( 1, '{"a":1,"b":2}' );
insert into FM.registers values ( 2, '{"a":42,"b":12}' );
select * from FM.journal;
select * from FM.registers;

select from FM.journal;

-- select aid, ( select * from jsonb_each( facets ) ) as v1 from FM.registers;
-- select
--     j.aid,
--     j.foo,

--   from FM.journal as j
--   left join FM.registers as r using ( aid );

\quit


/* aggregate function */

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT probably better to use domains or other means to ensure integrity */
create function FM.proceed( ¶tail text, ¶act text ) returns text stable language plpgsql as $$
  declare
    R text;
  begin
    select into R
        point
      from FM.transitions
      where ( tail = ¶tail ) and ( act = ¶act );
    return R;
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create aggregate FM.proceed_agg( text ) (
  sfunc     = FM.proceed,
  stype     = text,
  initcond  = 'FIRST' );


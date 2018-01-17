

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
  ( 'START'           ),
  ( 'identifier'      ),
  ( 'slash'           ),
  ( 'equals'          ),
  ( 'dcolon'          ),
  ( 'blank'           ),
  ( 'RESET'           ),
  ( 'STOP'            );

/* ### TAIN consider to abolish multiple cmds in favor of 'walkthrough' actions with '->' */
-- ---------------------------------------------------------------------------------------------------------
insert into FM.transitions
  ( tail,                 act,                cmd,          point           ) values
  -- .......................................................................................................
  /* reset: */
  ( '*',                  'RESET',            'RST',        'FIRST'         ),
  -- .......................................................................................................
  /* inceptive states: */
  ( 'FIRST',              'START',            'ADV',        's1'            ),
  ( 'LAST',               'START',            'ADV',        's1'            ),
  -- .......................................................................................................
  /* intermediate states: */
  -- ( 's0',                 '->',               'ADV',        's1'             ),
  ( 's1',                 'identifier',       'LOD T',      's2'            ),
  ( 's2',                 'equals',           'NOP',        's3'            ),
  ( 's2',                 'slash',            'PSH T C',    's1'            ),
  ( 's3',                 'identifier',       'LOD V',      's4'            ),
  ( 's4',                 'dcolon',           'NOP',        's5'            ),
  ( 's5',                 'identifier',       'LOD Y',      's6'            ),
  -- .......................................................................................................
  /* states that indicate completion and lead to next item: */
  ( 's1',                 'blank',            'ADV',        's1'            ),
  ( 's2',                 'blank',            'ADV',        's1'            ),
  ( 's6',                 'blank',            'ADV',        's1'            ),
  ( 's4',                 'blank',            'ADV',        's1'            ),
  -- .......................................................................................................
  /* states that indicate completion and lead to STOP: */
  ( 's1',                 'STOP',             'NOP',        'LAST'          ),
  ( 's2',                 'STOP',             'NOP',        'LAST'          ),
  ( 's6',                 'STOP',             'NOP',        'LAST'          ),
  ( 's4',                 'STOP',             'NOP',        'LAST'          );



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

\echo FM.registers
select * from FM.registers;
\echo FM.transitions
select * from FM.transitions;
\echo FM.board
select * from FM.board;
\echo FM.journal
select * from FM.journal;

/* ###################################################################################################### */

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
  perform FM.push( 'RESET'                           );
  perform FM.push( 'START'                           );
  perform FM.push( 'identifier',  'spaceships'       );
  perform FM.push( 'blank',       ' '                );
  perform FM.push( 'identifier',  'planets'          );
  perform FM.push( 'STOP'                            );
  end; $$;
select * from FM.journal;
select * from FM.board;

-- ---------------------------------------------------------------------------------------------------------
/* spaceships */
do $$ begin
  perform FM.push( 'RESET'                           );
  perform FM.push( 'START'                           );
  perform FM.push( 'identifier',  'spaceships'       );
  perform FM.push( 'STOP'                            );
  perform FM.push( 'START'                           );
  perform FM.push( 'identifier',  'planets'          );
  perform FM.push( 'STOP'                            );
  end; $$;
select * from FM.journal;
select * from FM.board;
\quit

-- ---------------------------------------------------------------------------------------------------------
/* color=red */
do $$ begin
  perform FM.push( 'START'                      );
  perform FM.push( 'identifier',  'color'       );
  perform FM.push( 'equals',      '='           );
  -- perform FM.push( 'equals',      '='          );
  -- perform FM.push( 'START',      null           );
  perform FM.push( 'identifier',  'red'         );
  perform FM.push( 'STOP'                       );
  end; $$;
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
  ac serial primary key,
  foo text
  );
create table FM.registers (
  ac integer references FM.journal ( ac ),
  facets jsonb
  );

insert into FM.journal ( foo ) values ( 42 ), ( 'helo' ), ( array[ 1, '2' ] );
insert into FM.registers values ( 1, '{"a":1,"b":2}' );
insert into FM.registers values ( 2, '{"a":42,"b":12}' );
select * from FM.journal;
select * from FM.registers;

select from FM.journal;

-- select ac, ( select * from jsonb_each( facets ) ) as v1 from FM.registers;
-- select
--     j.ac,
--     j.foo,

--   from FM.journal as j
--   left join FM.registers as r using ( ac );

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


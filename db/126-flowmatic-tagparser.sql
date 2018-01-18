

-- ---------------------------------------------------------------------------------------------------------
insert into FM.registers ( regkey, name, comment ) values
  ( 'C', 'context',   'a list of strings when the tag is written as path with slashes' ),
  ( 'T', 'tag',       'the tag itself; in the case of path notation, the last part of the path' ),
  ( 'V', 'value',     'written after an equals sign, the value of a valued tag, as in `color=red`' ),
  ( 'Y', 'type',      'the type of a tag, written with a double colon, as in `Mickey::name`' );

-- ---------------------------------------------------------------------------------------------------------
insert into FM.states values
   ( '*'          ),
   ( '...'        ),
   ( 'FIRST'      ),
   ( 's1'         ),
   ( 's2'         ),
   ( 's3'         ),
   ( 's4'         ),
   ( 's5'         ),
   ( 's6'         ),
   ( 'next-tag'   ),
   ( 'LAST'       );

-- ---------------------------------------------------------------------------------------------------------
insert into FM.acts values
  ( 'START'           ),
  ( '->'              ),
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
  ( 'FIRST',              'START',            'NCC',        's1'            ),
  ( 'LAST',               'START',            'NCC',        's1'            ),
  -- .......................................................................................................
  /* intermediate states: */
  ( 's1',                 'identifier',       'LOD T',      's2'            ),
  ( 's2',                 'dcolon',           'NOP',        's5'            ),
  ( 's2',                 'equals',           'NOP',        's3'            ),
  ( 's2',                 'slash',            'PSH T C',    's1'            ),
  ( 's3',                 'identifier',       'LOD V',      's4'            ),
  ( 's4',                 'dcolon',           'NOP',        's5'            ),
  ( 's5',                 'identifier',       'LOD Y',      's6'            ),
  -- .......................................................................................................
  /* states that indicate completion and lead to next item: */
  ( 's1',                 'blank',            'NBC',        'next-tag'      ),
  ( 's2',                 'blank',            'YES',        'next-tag'      ),
  ( 's6',                 'blank',            'YES',        'next-tag'      ),
  ( 's4',                 'blank',            'YES',        'next-tag'      ),
  -- ( 's2',                 'blank',            'YES',        's9'            ),
  -- ( 's9',                 '->',               'FOO',        '...'           ),
  -- ( '...',                '->',               'BAR',        '...'           ),
  -- ( '...',                '->',               'BAZ',        's1'            ),
  -- .......................................................................................................
  ( 'next-tag',           '->',               'NBC',        's1'            ),
  -- .......................................................................................................
  /* states that indicate completion and lead to STOP: */
  ( 's1',                 'STOP',             'NOP',        'LAST'          ),
  ( 's2',                 'STOP',             'YES',        'LAST'          ),
  ( 's6',                 'STOP',             'YES',        'LAST'          ),
  ( 's4',                 'STOP',             'YES',        'LAST'          );

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
        'C', "C", 'T', "T", 'V', "V", 'Y', "Y" ) from FM.board
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
--     array[ 'dcolon',      '::'   ],
--     array[ 'identifier',  'q'    ]
--     ] );

/*   —————————————————————————————=============######|######=============—————————————————————————————    */

/* IT/programming/language=SQL::name */
/* '{IT,/,programming,/,language,=,SQL,::,name}' */
do $$ begin
  perform FM.push( 'RESET'                           );
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
select * from FM.journal where ok;
select * from FM.board;
\quit

/* foo::q */
do $$ begin
  perform FM.push( 'START'                      );
  perform FM.push( 'identifier',  'foo'         );
  perform FM.push( 'dcolon',      '::'          );
  perform FM.push( 'identifier',  'q'           );
  perform FM.push( 'STOP'                       );
  end; $$;
select * from FM.journal;
select * from FM.journal where ok;
select * from FM.board;

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
select * from FM.journal where ok;
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
select * from FM.journal where ok;
select * from FM.board;

-- ---------------------------------------------------------------------------------------------------------
/* color=red */
do $$ begin
  perform FM.push( 'RESET'                           );
  perform FM.push( 'START'                      );
  perform FM.push( 'identifier',  'color'       );
  perform FM.push( 'equals',      '='           );
  -- perform FM.push( 'equals',      '='          );
  -- perform FM.push( 'START',      null           );
  perform FM.push( 'identifier',  'red'         );
  perform FM.push( 'STOP'                       );
  end; $$;
select * from FM.journal;
select * from FM.journal where ok;
select * from FM.board;


/* author=Faulkner::name */
do $$ begin
  perform FM.push( 'RESET'                           );
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
select * from FM.journal where ok;
select * from FM.board;




-- ---------------------------------------------------------------------------------------------------------



\quit




------------------------------------+------------------------------------------------------------------------
notation                            |  context          tag         value       type
------------------------------------+------------------------------------------------------------------------
color=red                           |  ∎                color       red         ∎
IT/programming/language=SQL::name   |  IT/programming   language    SQL         name
foo::q                              |  ∎                foo         ∎           q





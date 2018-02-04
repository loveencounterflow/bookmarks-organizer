

  -- ( 'tag/context', 'a list of strings when the tag is written as path with slashes'             ),
  -- ( 'tag/key',     'the tag itself; in the case of path notation, the last part of the path'    ),
  -- ( 'tag/value',   'written after an equals sign, the value of a valued tag, as in `color=red`' ),
  -- ( 'tag/type',    'the type of a tag, written with a double colon, as in `Mickey::name`'       );

-- ---------------------------------------------------------------------------------------------------------
insert into FM.states values
   ( '*'          ),
   ( '...'        ),
   ( 'FIRST'      ),
   ( 'pre-s1'     ),
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
  -- ( '*',                  'RESET',            'RST 0',                   'FIRST'         ),
  -- ( '*',                  'RESET',            'RST []',                  'FIRST'         ),
  -- ( '*',                  'RESET',            'RST ""',                  'FIRST'         ),
  -- ( '*',                  'RESET',            'RST false',               'FIRST'         ),
  -- ( '*',                  'RESET',            'RST true',                'FIRST'         ),
  -- ( '*',                  'RESET',            'RST null',                'FIRST'         ),
  ( '*',                  'RESET',            'RST {}',                   'FIRST'         ),
  -- ( '*',                  'RESET',            'RST',                     'FIRST'         ),
  -- .......................................................................................................
  /* inceptive states: */
  ( 'FIRST',              'START',            'NCC',                      's1'            ),
  ( 'LAST',               'START',            'NOP',                      'next-tag'      ),
  -- .......................................................................................................
  /* intermediate states: */
  ( 's1',                 'identifier',       'LOD tag/key',              's2'            ),
  ( 's2',                 'dcolon',           'NOP',                      's5'            ),
  ( 's2',                 'equals',           'NOP',                      's3'            ),
  ( 's2',                 'slash',            'PSH tag/key tag/context',  's1'            ),
  ( 's3',                 'identifier',       'LOD tag/value',            's4'            ),
  ( 's4',                 'dcolon',           'NOP',                      's5'            ),
  ( 's5',                 'identifier',       'LOD tag/type',             's6'            ),
  -- .......................................................................................................
  /* states that indicate completion and lead to next item: */
  ( 's1',                 'blank',            'NBC',                      'next-tag'      ),
  ( 's2',                 'blank',            'YES',                      'next-tag'      ),
  ( 's6',                 'blank',            'YES',                      'next-tag'      ),
  ( 's4',                 'blank',            'YES',                      'next-tag'      ),
  -- ( 's2',                 'blank',            'YES',        's9'            ),
  -- ( 's9',                 '->',               'FOO',        '...'           ),
  -- ( '...',                '->',               'BAR',        '...'           ),
  -- ( '...',                '->',               'BAZ',        's1'            ),
  -- .......................................................................................................
  -- ( 'next-tag',           '->',               'NCC',        'pre-s1'            ),
  -- ( 'pre-s1',             '->',               'CLR',        's1'            ),
  -- .......................................................................................................
  ( 'next-tag',           '->',               'NCC',                      '...'           ),
  ( '...',                '->',               'CLR',                      's1'            ),
  -- .......................................................................................................
  /* states that indicate completion and lead to STOP: */
  ( 's1',                 'STOP',             'NOP',                      'LAST'          ),
  ( 's2',                 'STOP',             'YES',                      'LAST'          ),
  ( 's6',                 'STOP',             'YES',                      'LAST'          ),
  ( 's4',                 'STOP',             'YES',                      'LAST'          );

-- ---------------------------------------------------------------------------------------------------------
do $$ begin
  perform FM.push( 'RESET' );
  end; $$;

\set ECHO queries
select * from FM.transitions;
select * from FM.board;
select * from FM.journal;
\set ECHO none

/* ###################################################################################################### */


-- ---------------------------------------------------------------------------------------------------------
/* spaceships */

-- select * from FM.journal_and_board;
-- do $$ begin  perform FM.push( 'START'                           ); end; $$; select * from FM.journal_and_board;
-- do $$ begin  perform FM.push( 'identifier',  'spaceships'       ); end; $$; select * from FM.journal_and_board;
-- do $$ begin  perform FM.push( 'dcolon',      '::'               ); end; $$; select * from FM.journal_and_board;
-- do $$ begin  perform FM.push( 'identifier',  'noun'             ); end; $$; select * from FM.journal_and_board;
-- -- do $$ begin  perform FM.push( 'blank',       ' '                ); end; $$; select * from FM.journal_and_board;
-- -- do $$ begin  perform FM.push( 'identifier',  'planets'          ); end; $$; select * from FM.journal_and_board;
-- do $$ begin  perform FM.push( 'STOP'                            ); end; $$; select * from FM.journal_and_board;
-- -- \quit

-- -- do $$ begin perform FM.push( 'RESET'                        ); end; $$;
-- do $$ begin perform FM.push( array[ 'START'                       ] ); end; $$; select * from FM.journal_and_board;
-- do $$ begin perform FM.push( array[ 'identifier',  'IT'           ] ); end; $$; select * from FM.journal_and_board;
-- do $$ begin perform FM.push( array[ 'slash',       '/'            ] ); end; $$; select * from FM.journal_and_board;
-- do $$ begin perform FM.push( array[ 'identifier',  'programming'  ] ); end; $$; select * from FM.journal_and_board;
-- do $$ begin perform FM.push( array[ 'slash',       '/'            ] ); end; $$; select * from FM.journal_and_board;
-- do $$ begin perform FM.push( array[ 'identifier',  'language'     ] ); end; $$; select * from FM.journal_and_board;
-- do $$ begin perform FM.push( array[ 'equals',      '='            ] ); end; $$; select * from FM.journal_and_board;
-- do $$ begin perform FM.push( array[ 'identifier',  'SQL'          ] ); end; $$; select * from FM.journal_and_board;
-- do $$ begin perform FM.push( array[ 'dcolon',      '::'           ] ); end; $$; select * from FM.journal_and_board;
-- do $$ begin perform FM.push( array[ 'identifier',  'name'         ] ); end; $$; select * from FM.journal_and_board;
-- do $$ begin perform FM.push( array[ 'blank',       ' '            ] ); end; $$; select * from FM.journal_and_board;
-- do $$ begin perform FM.push( array[ 'identifier',  'mytag'        ] ); end; $$; select * from FM.journal_and_board;
-- do $$ begin perform FM.push( array[ 'STOP'                        ] ); end; $$; select * from FM.journal_and_board;

do $$ begin
  perform FM.push_dacts( array[
    array[ 'identifier',  'IT'           ],
    array[ 'slash',       '/'            ],
    array[ 'identifier',  'programming'  ],
    array[ 'slash',       '/'            ],
    array[ 'identifier',  'language'     ],
    array[ 'equals',      '='            ],
    array[ 'identifier',  'SQL'          ],
    array[ 'dcolon',      '::'           ],
    array[ 'identifier',  'name'         ],
    array[ 'blank',       ' '            ],
    array[ 'identifier',  'mytag'        ] ] );
  end; $$;

\set ECHO queries
-- select * from FM.journal_and_board;
select * from FM.board;
select * from FM.results order by ac;
\set ECHO none
\quit

-- \set ECHO queries
-- select * from FM.journal where ok;
-- select * from FM.journal;
-- \quit
/* ###################################################################################################### */



/*   —————————————————————————————=============######|######=============—————————————————————————————    */


create table FM.input (
  ic    serial,
  act   text not null references FM.acts ( act ),
  data  text,
  ac    integer
  );

-- do $$ begin perform FM.push( 'RESET' ); end; $$;
insert into FM.input ( act, data ) values ( 'START',        null              );
insert into FM.input ( act, data ) values ( 'identifier',   'author'          );
insert into FM.input ( act, data ) values ( 'equals',       '='               );
insert into FM.input ( act, data ) values ( 'identifier',   'Faulkner'        );
insert into FM.input ( act, data ) values ( 'dcolon',       '::'              );
insert into FM.input ( act, data ) values ( 'identifier',   'name'            );
insert into FM.input ( act, data ) values ( 'STOP',         null              );
insert into FM.input ( act, data ) values ( 'START',        null              );
insert into FM.input ( act, data ) values ( 'identifier',   'spaceships'      );
insert into FM.input ( act, data ) values ( 'blank',        ' '               );
insert into FM.input ( act, data ) values ( 'identifier',   'planets'         );
insert into FM.input ( act, data ) values ( 'STOP',         null              );


/* thx to https://stackoverflow.com/a/29747770/7568091
  for the 'ordered update implemented by way of sub-subselect' */
update FM.input as i1
  set ac = i2.ac
  from ( select
      ic                    as ic,
      FM.push( act, data )  as ac
    from FM.input
    order by ic ) as i2
  where i1.ic = i2.ic;


\set ECHO queries
select * from FM.input;
select * from FM.journal_and_board;
\set ECHO none
-- \quit

/*   —————————————————————————————=============######|######=============—————————————————————————————    */
/* Function to turn `select` statement into JSONb object */

/*
\echo FM.board
select * from FM.board where bc = FM.bc();
select
    bc,
    U.row_as_jsonb_object( format( 'select * from FM.board where bc = %L;', bc ) ) as dacts
  from FM.board;
\quit
*/
/*   —————————————————————————————=============######|######=============—————————————————————————————    */


/* IT/programming/language=SQL::name */
/* '{IT,/,programming,/,language,=,SQL,::,name}' */
do $$ begin
  -- perform FM.push( 'RESET'                        );
  perform FM.push( 'START'                        );
  perform FM.push( 'identifier',  'yahoo'         );
  perform FM.push( 'STOP'                         );
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
\set ECHO queries
select * from FM.input;
select * from FM.journal_and_board;
select * from FM.board;
\set ECHO none

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
select * from FM.journal_and_board where ok;


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
select * from FM.journal_and_board where ok;




-- ---------------------------------------------------------------------------------------------------------



\quit




------------------------------------+------------------------------------------------------------------------
notation                            |  context          tag         value       type
------------------------------------+------------------------------------------------------------------------
color=red                           |  ∎                color       red         ∎
IT/programming/language=SQL::name   |  IT/programming   language    SQL         name
foo::q                              |  ∎                foo         ∎           q





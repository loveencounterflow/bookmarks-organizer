

  -- ( 'C', 'context',   'a list of strings when the tag is written as path with slashes' ),
  -- ( 'T', 'tag',       'the tag itself; in the case of path notation, the last part of the path' ),
  -- ( 'V', 'value',     'written after an equals sign, the value of a valued tag, as in `color=red`' ),
  -- ( 'Y', 'type',      'the type of a tag, written with a double colon, as in `Mickey::name`' );

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
  perform FM.push( 'RESET' );
  end; $$;

-- \echo FM.registers
-- select * from FM.registers;
-- \echo FM.transitions
-- select * from FM.transitions;
-- \echo FM.board
-- select * from FM.board;
-- \echo FM.journal
-- select * from FM.journal;

/* ###################################################################################################### */



/*   —————————————————————————————=============######|######=============—————————————————————————————    */


create table FM.input (
  ic    serial,
  act   text not null references FM.acts ( act ),
  data  text,
  ac    integer
  );

do $$ begin perform FM.push( 'RESET' ); end; $$;
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

select * from FM.input;
select * from FM.journal;

/*   —————————————————————————————=============######|######=============—————————————————————————————    */
/* Function to turn `select` statement into JSONb object */

-- select distinct on ( typelem ) typname, typelem from pg_type;
-- select typelem, array_agg( typname ) from pg_type group by typelem;
-- \quit




\echo FM.board
select * from FM.board where bc = FM.bc();
select
    bc,
    U.row_as_jsonb_object( format( 'select * from FM.board where bc = %L;', bc ) ) as dacts
  from FM.board;
\quit
/*   —————————————————————————————=============######|######=============—————————————————————————————    */



select
    i.ic,                          -- as ic_,
    i.act,                         -- as act_,
    i.data,                        -- as data_,
    i.ac,                          -- as ac_
    j.ac as j_ac,
    j.bc,
    j.cc,
    j.tc,
    j.tail,
    j.cmd,
    j.point,
    j.ok,
    j."C",
    j."T",
    j."V",
    j."Y"
  from FM.input    as i
  right join FM.journal  as j on ( i.ac = j.ac )
  order by j.ac
  ;

-- select pg_typeof( ac ) from FM.input;
-- select pg_typeof( ac ) from FM.journal;

\quit

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

-- ---------------------------------------------------------------------------------------------------------
/* spaceships */
do $$ begin
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
select * from FM.journal where ok;
select * from FM.board;


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





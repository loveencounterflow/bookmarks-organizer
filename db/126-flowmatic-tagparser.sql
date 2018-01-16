


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
  perform FM.adapt_journal();
  perform FM.adapt_board();
  -- perform FM.push( 'RESET' );
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


create function FM.feed_pairs( ¶acts_and_data text[] ) returns jsonb volatile strict language plpgsql as $$
  declare
    R jsonb;
  begin
    perform FM.push( 'CLEAR'  );
    perform FM.push( 'START'  );
    perform FM.push( pair[ 1 ], pair[ 2 ] ) from U.unnest_2d_1d( ¶acts_and_data ) as pair;
    perform FM.push( 'STOP'   );
    R := FM.registers_as_jsonb_object();
    return R;
    end; $$;


select FM.feed_pairs( array[
    array[ 'identifier',  'foo'  ],
    array[ 'equals',      '::'   ],
    array[ 'identifier',  'q'    ]
    ] );





-- ---------------------------------------------------------------------------------------------------------
/* spaceships */
do $$ begin
  perform FM.push( 'RESET'                      );
  perform FM.push( 'START'                      );
  perform FM.push( 'identifier',  'spaceships'       );
  perform FM.push( 'STOP'                       );
  end; $$;
-- perform FM.push( 'CLEAR'                      );
select * from FM.journal;
select * from FM.journal;

-- ---------------------------------------------------------------------------------------------------------
/* color=red */
do $$ begin
  perform FM.push( 'RESET'                      );
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
select * from FM.journal;


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
select * from FM.result;
select * from FM.raw_result;


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


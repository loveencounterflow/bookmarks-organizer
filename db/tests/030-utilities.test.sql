insert into FA.registers ( regkey, name ) values
  ( 'S', 'string' ),
  ( 'B', 'boolean' ),
  ( 'A', 'array' ),
  ( 'N', 'number' ),
  ( 'O', 'null' ),
  ( 'P', 'pgnull' );
update FA.registers set data = '"something"'        where regkey = 'S';
update FA.registers set data = 'false'              where regkey = 'B';
update FA.registers set data = '[ "x", false, 1 ]'  where regkey = 'A';
update FA.registers set data = '42'                 where regkey = 'N';
update FA.registers set data = 'null'               where regkey = 'O';
update FA.registers set data = null                 where regkey = 'P';
-- update FA.registers set data = '{"foo":"bar"}' where regkey = 'X';
select * from FA.registers;
select array_agg( regkey order by id ) as k from FA.registers;
select jsonb_agg( data   order by id ) as v from FA.registers;
select pg_typeof( array_agg( data::text   order by id )) as v from FA.registers;
select ( '"oops"'::jsonb )::text;
select jsonb_build_object( 'X', null, 'Y', 'foo' );



\ir '../010-trm.sql'
\set X :yellow


-- ---------------------------------------------------------------------------------------------------------
\echo :X'-=(1)=-':O
drop schema if exists _TDC_ cascade;
create schema _TDC_;

-- ---------------------------------------------------------------------------------------------------------
\echo :X'-=(2)=-':O
create domain _TDC_.null_text             as text     check ( value is null   );
create domain _TDC_.null_integer          as integer  check ( value is null   );
create domain _TDC_.nonnegative_integer   as integer  check ( value >= 0      );
create domain _TDC_.positive_integer      as integer  check ( value >= 1      );
create domain _TDC_.nonempty_text         as text     check ( value != ''     );

create function _TDC_.f( _TDC_.nonempty_text ) returns text language sql as $$ select $1::text; $$;

-- ---------------------------------------------------------------------------------------------------------
\echo :X'-=(3)=-':O
set role dba;
create cast ( _TDC_.nonempty_text as text )
  with function _TDC_.f( _TDC_.nonempty_text )
  -- as assignment
  as implicit
  ;
reset role;

-- ---------------------------------------------------------------------------------------------------------
\echo :X'-=(3)=-':O
create table _TDC_.names_txt ( name text );
create table _TDC_.names ( name _TDC_.nonempty_text );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'-=(4)=-':O
insert into _TDC_.names_txt values
  ( 'foo' ),
  ( 'bar' ),
  ( 'baz' );

-- ---------------------------------------------------------------------------------------------------------
\echo :X'-=(4)=-':O
insert into _TDC_.names values
  ( 'foo' ),
  ( 'bar' ),
  ( 'baz' );

/* ###################################################################################################### */

-- ---------------------------------------------------------------------------------------------------------
\echo :X'-=(5)=-':O
select * from _TDC_.names_txt;
select * from _TDC_.names;


-- ---------------------------------------------------------------------------------------------------------
\echo :X'-=(5)=-':O
select array_agg( name ) from _TDC_.names_txt where name ~ '^b';
select array_agg( name::text ) from _TDC_.names where name ~ '^b';

/* doesn't work despite the cast: */
select array_agg( name ) from _TDC_.names where name ~ '^b';


\quit


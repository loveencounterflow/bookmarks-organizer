

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

-- ---------------------------------------------------------------------------------------------------------
\echo :X'-=(3)=-':O
create table _TDC_.names_txt ( name text );
create table _TDC_.names (
  name text,
  check ( name::_TDC_.nonempty_text = name )
  );

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

-- ---------------------------------------------------------------------------------------------------------
\echo :X'-=(4)=-':O
insert into _TDC_.names_txt values ( null );
insert into _TDC_.names     values ( null );
insert into _TDC_.names_txt values ( '' );
/* this is not allowed: */
-- insert into _TDC_.names     values ( '' );


/* ###################################################################################################### */

-- ---------------------------------------------------------------------------------------------------------
\echo :X'-=(5)=-':O
select * from _TDC_.names_txt;
select * from _TDC_.names;


-- ---------------------------------------------------------------------------------------------------------
\echo :X'-=(5)=-':O
select array_agg( name ) from _TDC_.names_txt where name ~ '^b';
select array_agg( name::text ) from _TDC_.names where name ~ '^b';

/* works! */
select array_agg( name ) from _TDC_.names where name ~ '^b';


\quit


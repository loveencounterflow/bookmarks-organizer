


/*

 .d8888b.  8888888b.   .d8888b.
d88P  Y88b 888   Y88b d88P  Y88b
Y88b.      888    888 888    888
 "Y888b.   888   d88P 888
    "Y88b. 8888888P"  888
      "888 888 T88b   888    888
Y88b  d88P 888  T88b  Y88b  d88P
 "Y8888P"  888   T88b  "Y8888P"

*/

\ir '../010-trm.sql'
\timing on


-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _旅人_ cascade;
create schema _旅人_;

-- ---------------------------------------------------------------------------------------------------------
create view _旅人_.sample_data as (
  select null::integer as nr where false union all
  select  1 union all
  select  2 union all
  select  3 union all
  select  6 union all
  select  7 union all
  select 11 union all
  select 18 union all
  select 19 union all
  select 20 union all
  select 21 union all
  select 22 union all
  select 25 );

-- ---------------------------------------------------------------------------------------------------------
create view _旅人_.organized as ( select
    nr                                      as nr,
         row_number() over ( order by nr )  as row_nr,
    nr - row_number() over ( order by nr )  as group_nr
  from _旅人_.sample_data );

-- ---------------------------------------------------------------------------------------------------------
create view _旅人_.ranked as ( select
  t.nr                                      as nr,
  t.row_nr                                  as row_nr,
  t.group_nr                                as group_nr,
  dense_rank() over ( order by group_nr )   as regular_group_nr
  from _旅人_.organized as t );


/*                     --------------==========######O######==========--------------                      */


-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _SRC_ cascade;
create schema _SRC_;

-- ---------------------------------------------------------------------------------------------------------
create table _SRC_.source (
  linenr    integer unique not null,
  key       text not null,
  value     text );

-- ---------------------------------------------------------------------------------------------------------
insert into _SRC_.source values
  (  2, 'tags',  'a'          ),
  (  3, '...',   'b'          ),
  (  4, 'title', 'The Title'  ),
  (  5, 'note',  'this is'    ),
  (  6, '...',   'an EXAMPLE' ),
  (  8, 'title', 'over'       ),
  (  9, '...',   'three'      ),
  ( 10, '...',   'lines'      ),
  ( 11, 'about', 'grouping'   );

    -- ╔════════╤═══════╤═══════╤════════════╗
    -- ║ linenr │ group │  key  │   value    ║
    -- ╠════════╪═══════╪═══════╪════════════╣
    -- ║      2 │     1 │ tags  │ a          ║
    -- ║      3 │     1 │ ...   │ b          ║
    -- ║      4 │     2 │ title │ The Title  ║
    -- ║      5 │     3 │ note  │ this is    ║
    -- ║      6 │     3 │ ...   │ an EXAMPLE ║
    -- ║      8 │     4 │ title │ over       ║
    -- ║      9 │     4 │ ...   │ three      ║
    -- ║     10 │     4 │ ...   │ lines      ║
    -- ║     11 │     5 │ about │ grouping   ║
    -- ╚════════╧═══════╧═══════╧════════════╝

select
    linenr                              as linenr,
    key                                 as key,
    value                               as value,
    sum( rst ) over ( order by linenr ) as group_nr
  from ( select
    linenr,
    key,
    value,
    case when key != '...' then 1 end   as rst
  from source ) as x;

\quit

/* ###################################################################################################### */



\set ECHO queries
-- select * from _旅人_.ranked;
\set ECHO none

\quit




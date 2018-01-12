
/* thx to https://stackoverflow.com/a/39456483/7568091 */

/*
  declare
    excerpt json;
  begin
    select into excerpt
           '[["aid","bid","tail","act","point","data","registers"]]'::jsonb ||
        jsonb_agg( info ) from (
          select jsonb_build_array(
            aid, bid, tail, act, point, data, registers
            ) as info from (
              select aid, bid, tail, act, point, data, registers                            -- q3
                from _FSM2_.journal where bid = ¶bid order by aid ) as x1 ) as x2;
    return U.tabulate( excerpt );
*/

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _RA_ cascade;
create schema _RA_;

-- ---------------------------------------------------------------------------------------------------------
create table _RA_.solar_system (
  anr     integer,
  snr     integer,
  name    text,
  radius  real,
  mass    real );

-- ---------------------------------------------------------------------------------------------------------
insert into _RA_.solar_system values
  ( 0, 0, 'Sun',    696000,   1989100000  ),
  ( 3, 0, 'Earth',  6371,     5973.6      ),
  ( 3, 1, 'Moon',   1737,     73.5        ),
  ( 4, 0, 'Mars',   3390,     641.85      );

-- ---------------------------------------------------------------------------------------------------------
select * from _RA_.solar_system order by anr, snr;

-- anr, snr, name, radius, mass

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function _RA_.query_as_jsonb( q_ text ) returns jsonb strict immutable language plpython3u as $$
  import json as JSON
  plpy.execute( 'select INIT.py_init()' )
  ctx   = GD[ 'ctx' ]
  rows  = plpy.execute( q_ )
  names = rows.colnames()
  R     = [ names, ]
  for row in rows:
    R.append( [ row[ name ] for name in names ] )
  return JSON.dumps( R )
  $$;
reset role;

/*
-- ---------------------------------------------------------------------------------------------------------
create function U.tabulate_query( ¶q text ) returns text strict immutable language sql as $$
  select U.tabulate( U.query_as_jsonb( ¶q ) ); $$;
*/


-- ---------------------------------------------------------------------------------------------------------
create view _RA_.q3 as (
  select anr, snr, name, radius, mass
    from _RA_.solar_system
  );

select * from _RA_.q3;
-- select jsonb_build_array( anr, name ) from _RA_.q3;

select U.tabulate( U.query_as_jsonb( $$ select * from _RA_.q3 where anr = 3; $$ ) );
select U.tabulate( U.query_as_jsonb( format(
  $$ select * from _RA_.q3 where anr = %L; $$, 3 ) ) );
select U.tabulate_query( $$ select * from _RA_.q3 where anr = 3; $$ );

  -- ["body","radius / km", "mass / 10^29 kg"], ["Sun",696000,1989100000],["Earth",6371,5973.6], ["Moon",1737,73.5],["Mars",3390,641.85]]





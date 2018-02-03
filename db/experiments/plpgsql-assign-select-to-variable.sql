

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _XXX_ cascade;
create schema _XXX_;

-- ---------------------------------------------------------------------------------------------------------
create function _XXX_.f( out x integer, out y text )
  immutable strict language plpgsql as $$
    begin
      /* thx to https://stackoverflow.com/a/19051658/7568091 */
      x := v1.d from ( select 42 as d ) as v1;
      select into x, y v1.d, v1.e from ( select 42 as d, 'world' as e ) as v1;
      -- x, y := v1.d, v1.e from ( select 42 as d, 'world' as e ) as v1;
      -- R := count(*) from IMGFILES.available_imgfile_locations_with_preferences;
      -- R := _preference from IMGFILES.available_imgfile_locations_with_preferences limit 1;
      return;
      end; $$;

select * from _XXX_.f();

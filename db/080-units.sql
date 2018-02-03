

/* https://github.com/ChristophBerg/postgresql-unit */
/* see https://github.com/sharkdp/insect
   for a PureScript / JavaScript equivalent */

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists UNITS cascade;
create schema UNITS;

-- \pset numericlocale on
set unit.byte_output_iec    = on;
set unit.output_base_units  = on;
set unit.output_superscript = on;

-- ---------------------------------------------------------------------------------------------------------
create function UNITS.set_prefix( ¶prefix text, ¶factor double precision ) returns void language plpgsql as $$
  begin
    insert into unit_prefixes as u ( prefix, factor ) values ( ¶prefix, ¶factor )
      on conflict ( prefix ) do
      update set    factor  = ¶factor
      where       u.prefix  = ¶prefix;
    perform unit_reset();
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function UNITS.set_unit( ¶name text, ¶unit unit ) returns void language plpgsql as $$
  begin
    insert into unit_units as u ( name, unit ) values ( ¶name, ¶unit )
      on conflict ( name ) do
      update set    unit  = ¶unit
      where       u.name  = ¶name;
    perform unit_reset();
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function UNITS.demo() returns void language plpgsql as $$
  begin
    perform log();
    perform log( 'bottles_of_beer:    ', ( '1 hl'::unit @ '0.5 l'                      )::text );
    perform log( 'bottles_of_beer:    ', ( '1 hl'::unit @ '0.5 l'                      )::text );
    perform log( 'speed:              ', ( '120 km/h'::unit                            )::text );
    perform log( 'speed:              ', ( '120 km/h'::unit        @ 'mi/h'            )::text );
    perform log( 'traffic:            ', ( '2 MB/min'::unit        @ 'GB/d'            )::text );
    perform log( 'disk_sold_as_4tb:   ', ( '4 TB'::unit                                )::text );
    perform log( 'disk_sold_as_4tb:   ', ( '4 TB'::unit            @ 'bytes'           )::text );
    perform log( 'disk_sold_as_4tb:   ', ( '4 TB'::unit            @ 'TiB'             )::text );
    perform log( 'disk_sold_as_4tb:   ', ( '4 TB'::unit            @ 'GiB'             )::text );
    perform log( 'disk_sold_as_4tb:   ', ( '4 TB'::unit            @ 'MiB'             )::text );
    perform log( 'disk_sold_as_4tb:   ', ( '4 TB'::unit            @ 'KiB'             )::text );
    perform log( 'walk_500_miles:     ', ( '500 mi'::unit                              )::text );
    perform log( 'length:             ', ( '800 m'::unit + '500 m'                     )::text );
    perform log( 'length:             ', ( '800 m'::unit + '500 m' @ 'm'               )::text );
    perform log( 'length:             ', ( '800 m'::unit + '500 m' @ 'in'              )::text );
    perform log( 'length:             ', ( '800 m'::unit + '500 m' @ 'yd'              )::text );
    perform log( 'gravity:            ', ( '9.81 N'::unit / 'kg'                       )::text );
    perform log( 'volume:             ', ( '1 L'::unit                                 )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'quart'           )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'usquart'         )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'dryquart'        )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'metricquart'     )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'brquarter'       )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'imperialquarter' )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'quartaria'       )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'quartarius'      )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'reputedquart'    )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'brquart'         )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'imperialquart'   )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'irishquarter'    )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'winequart'       )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'beerquart'       )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'alequart'        )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'scotsquart'      )::text );
    perform log( 'volume:             ', ( '1 L'::unit             @ 'irishquart'      )::text );
    perform UNITS.set_prefix( 'foo',        108       );
    perform UNITS.set_unit(   'legobrick',  '9.6 mm'  );
    perform UNITS.set_unit(   'Spanne',     '1|12 m'  );
    perform log( ( '1 foobar'::unit                         )::text );
    perform log( ( '1 m'::unit @ 'legobricks'               )::text );
    perform log( ( '1|3 m'::unit @ 'Spanne'                 )::text );
    perform log( ( sqrt( '47m²'::unit )                     )::text );
    end; $$;

-- do $$ begin perform UNITS.demo(); end; $$;


\quit

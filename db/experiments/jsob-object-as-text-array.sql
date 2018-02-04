-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _X_ cascade;
create schema _X_;

-- ---------------------------------------------------------------------------------------------------------
create function _X_.jsonb_object_as_text_facets( ¶x jsonb ) returns text[]
  immutable strict language plpgsql as $$
  declare
    ¶key    text;
    ¶value  jsonb;
    R       text[];
  begin
    for ¶key, ¶value in select key, value from jsonb_each( ¶x ) loop
    -- for ¶key, ¶value in select key, value from jsonb_each_text( ¶x ) loop
      raise notice '90901 %', ¶key;
      raise notice '90901 %', ¶value;
      raise notice '90901 %', text( ¶value );
      R := R || array[ array[ ¶key, ¶value::text ] ];
      end loop;
    return R;
    end; $$;

/*   —————————————————————————————=============######|######=============—————————————————————————————    */

select _X_.jsonb_object_as_text_facets( '{"a":"yes","b":42,"c":["foo","bar","baz"]}'::jsonb );

\quit


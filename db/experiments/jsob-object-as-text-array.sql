-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _X_ cascade;
create schema _X_;

-- ---------------------------------------------------------------------------------------------------------
create function _X_.jsonb_object_as_text_facets( ¶x jsonb ) returns text[]
  immutable strict language plpgsql as $$
  declare
    ¶key      text;
    ¶value    jsonb;
    ¶element  text;
    R         text[];
  begin
    for ¶key, ¶value in select key, value from jsonb_each( ¶x ) loop
      if jsonb_typeof( ¶value ) = 'array' then
        for ¶element in select value from jsonb_array_elements_text( ¶value ) loop
          R := R || ¶element;
          end loop;
        else
          R := R || ( ¶x->>¶key );
          end if;
      end loop;
    return R; end; $$;

/*   —————————————————————————————=============######|######=============—————————————————————————————    */

select _X_.jsonb_object_as_text_facets( '{"a":"yes","b":42,"c":["foo","bar","baz"]}'::jsonb );

\quit


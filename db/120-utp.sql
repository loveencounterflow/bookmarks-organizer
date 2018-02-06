
\ir './010-trm.sql'
\pset tuples_only off
-- \timing on
\set X :yellow

/*

Fields with multiple URLs:
  * split into fields with one URL each using urls_url_splitter (not implemented)

field `url`:
  * each URL gets split into phrases using url_phrase_splitter
  * each phrase gets split into words with camelcase_splitter

field `tags`:
  * split into 'tag lexemes' using tag_splitter

*/

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists UTP cascade;
create schema UTP;

-- ---------------------------------------------------------------------------------------------------------
create table UTP.patterns (
  key     text not null unique primary key,
  pattern text not null );

-- ---------------------------------------------------------------------------------------------------------
insert into UTP.patterns values
  ( 'lex_camel',            '(?<!(^|[A-Z]))(?=[A-Z])|(?<!^)(?=[A-Z][a-z])'        ),
  ( 'split_url_phrase',     '[-_/,.;:~+*''"&%$^°=?´`@{[()\]}]+'                   );

-- ---------------------------------------------------------------------------------------------------------
create function UTP.lex_camel( ¶text text ) returns text[] stable strict language sql as $$
  select regexp_split_to_array(
    ¶text,
    ( select pattern from UTP.patterns where key = 'lex_camel' ) ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function UTP.split_url_phrase( ¶text text ) returns text[] stable strict language sql as $$
  select array_remove( regexp_split_to_array(
    ¶text,
    ( select pattern from UTP.patterns where key = 'split_url_phrase' ) ),
    '' ); $$;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function UTP.lex_tags( text_ text ) returns text[] immutable strict language plpython3u as $$
  plpy.execute( 'select INIT.py_init()' ); ctx = GD[ 'ctx' ]
  return ctx.utp_tag_parser.lex_tags( ctx, text_ )
  $$;
reset role;

-- ---------------------------------------------------------------------------------------------------------
set role dba;
create function UTP.lex_tags( texts_ text[] ) returns text[] immutable strict language plpython3u as $$
  plpy.execute( 'select INIT.py_init()' ); ctx = GD[ 'ctx' ]
  R = []
  for text in texts_:
    R.extend( ctx.utp_tag_parser.lex_tags( ctx, text ) )
  return R
  $$;
reset role;

-- ---------------------------------------------------------------------------------------------------------
create function UTP.taglex_as_table( taglex text[] ) returns table ( act_and_data text[] )
  immutable strict language sql as $$
  select
      act_and_data
    from U.unnest_2d_1d( taglex ) as act_and_data; $$;


\quit


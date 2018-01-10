
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
  plpy.execute( 'select INIT.py_init()' )
  ctx = GD[ 'ctx' ]
  return ctx.utp_tag_parser.lex_tags( text_ )
  $$;
reset role;

\quit


/* ###################################################################################################### */
\quit




/* # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #  */
/*  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # */
/* # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #  */
-- taglexer.py

import re
# thx to https://stackoverflow.com/a/16710842/7568091
# thx to https://stackoverflow.com/a/13240255/7568091
rex = re.compile( r"""
  ( [^'"\s=/:]+ )   # anything except quotes and whitespace
  |                 # or
  ( ['"] )          # an opening quote
  (                 # followed by
    (?:             #   the following:
      \\.           #     an escaped character
      |             #     or
      (?! \2 )      #     (as long as we're not right at the matching quote)
      .             #     any other character,
      )*            #     repeated.
    )               #
  \2                # corresponding closing quote
  |                 # or
  ( \s+ )           # whitespace
  |                 # or
  ( [=/:]+ )        # special characters
  |                 # or
  ( ['"]* )         # lone quotes
  """, re.DOTALL | re.VERBOSE )

# #-----------------------------------------------------------------------------------------------------------
# forbidden_pattern = re.compile( r'^[:=]|[:=]$' )


#-----------------------------------------------------------------------------------------------------------
def lex_tags( tags_txt ):
  R     = []
  parts = rex.findall( tags_txt )
  for part in parts:
    for idx, group in enumerate( part ):
      if idx == 1: continue
      if len( group ) > 0:
        if group in ( '"', "'", ):
          """### TAINT use interpolation"""
          raise SyntaxError( "lone quote in " + rpr( tags_txt ) )
        # if len( forbidden_pattern.findall( 'name' ) ) > 0:
        #   raise SyntaxError( "illegal tag characters in " + rpr( tags_txt ) )
        R.append( group )
        break
  return R

/* # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #  */
/*  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # */
/* # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #  */






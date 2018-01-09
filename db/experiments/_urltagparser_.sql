
\ir '../010-trm.sql'
\pset tuples_only off
\timing on
\set X :yellow

/*

Fields with multiple URLs:
  * split into fields with one URL each using urls_url_splitter (not implemented)

URLs:
  * each URL gets split into phrases using url_phrase_splitter
  * each phrase gets split into words with camelcase_splitter

tags:
  * split into 'tag lexemes' using tag_splitter

*/


-- ---------------------------------------------------------------------------------------------------------
drop schema if exists _LEX_ cascade;
create schema _LEX_;

-- ---------------------------------------------------------------------------------------------------------
create table _LEX_.word_probes ( probe text not null );
insert into _LEX_.word_probes values
  ( 'LearnWCFInSixEasyMonths' ),
  ( 'résumé' ),
  ( 'réSumé' ),
  ( 'lower' ),
  ( 'INITIAL' ),
  ( 'Initial' ),
  ( 'ABCWordDEF' ),
  ( 'dromedaryCase' ),
  ( 'CamelCaseXYZ' );

-- ---------------------------------------------------------------------------------------------------------
create table _LEX_.patterns (
  key     text not null unique primary key,
  pattern text not null );

-- ---------------------------------------------------------------------------------------------------------
insert into _LEX_.patterns values
  ( 'lex_camel', '(?<!(^|[A-Z]))(?=[A-Z])|(?<!^)(?=[A-Z][a-z])' );

-- ---------------------------------------------------------------------------------------------------------
create function _LEX_.lex_camel( ¶text text ) returns text[] stable strict language sql as $$
  select regexp_split_to_array(
    ¶text,
    ( select pattern from _LEX_.patterns where key = 'lex_camel' ) ); $$;

-- ---------------------------------------------------------------------------------------------------------
select
    p.probe,
    _LEX_.lex_camel( p.probe ) as result
  from
    _LEX_.word_probes    as p
  order by
    p.probe;

-- ---------------------------------------------------------------------------------------------------------
create table _LEX_.phrase_probes ( probe text not null );
insert into _LEX_.phrase_probes values
  ( 'foo/bar' ),
  ( 'this_that' ),
  ( '...yeah' ),
  ( 'this_(that)' ),
  ( '(bracketed)' ),
  ( 'foo(bracketed)bar' ),
  ( 'http://foo.com/a-new-way/of-thinking' ),
  ( 'http://foo.com/汉字编码的理论与实践/学林出版社1986年8月' ),
  ( 'this-that' );

-- ---------------------------------------------------------------------------------------------------------
create table _LEX_.phrase_splitters ( id integer, splitter text not null );
insert into _LEX_.phrase_splitters ( id, splitter ) values
  -- ( 1, '(?<!^)([A-Z][a-z]|(?<=[a-z])[A-Z])'                            ),
  ( 1, '[-_/,.;:~+*''"&%$^°=?´`@{[()\]}]+'                  );
  -- ( 2, '(\w+)|[^\w\s]'                  );
  -- ( 3, '(?<=[a-z])(?=[A-Z])'                                           ),
  -- ( 4, '((?<=[a-z]))((?=[A-Z]))|((?<=[A-Z]))((?=[A-Z][a-z]))'          );

-- ---------------------------------------------------------------------------------------------------------
select
    s.splitter,
    p.probe,
    regexp_split_to_array( p.probe, s.splitter ) as result,
    s.id
  from
    _LEX_.phrase_probes    as p,
    _LEX_.phrase_splitters as s
  order by
    s.id,
    p.probe,
    s.splitter;


/* ###################################################################################################### */


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






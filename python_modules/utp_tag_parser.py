
# -*- coding: utf-8 -*-

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
  R = [ r.replace( '\\', '' ) for r in R ]
  return R




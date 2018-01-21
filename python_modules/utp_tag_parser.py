
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

#-----------------------------------------------------------------------------------------------------------
whitespace_re = re.compile( r'^\s+$' )

#-----------------------------------------------------------------------------------------------------------
def lex_tags( ctx, tags_txt ):
  R     = []
  parts = rex.findall( tags_txt )
  for part in parts:
    is_quoted = False
    for idx, group in enumerate( part ):
      if idx == 1:
        if group in ( '"', "'", ):
          is_quoted = True
        continue
      if len( group ) > 0:
        if group in ( '"', "'", ):
          """### TAINT use interpolation"""
          raise SyntaxError( "lone quote in " + rpr( tags_txt ) )
        # if len( forbidden_pattern.findall( 'name' ) ) > 0:
        #   raise SyntaxError( "illegal tag characters in " + rpr( tags_txt ) )
        if is_quoted:
          type = 'identifier'
        else:
          if    whitespace_re.match( group ) is not None: type = 'blank'
          elif  group == '/':                             type = 'slash'
          elif  group == '=':                             type = 'equals'
          elif  group == '::':                            type = 'dcolon'
          else:                                           type = 'identifier'
        R.append( ( type, group, ) )
        break
  R = [ [ type, group.replace( '\\', '' ), ] for ( type, group ) in R ]
  return R







from unittest import TestCase
from .. cnd import debug, rpr, jr
def jrl( *P ): return jr( P )

# class Taglexer( TestCase ):

#   def test_identity( me ):
#     debug( """Test numeric equality as an example.""" )
#     me.assertTrue( 1 == 1 )

#   def test_foobar( me ):
#     debug( """Test numeric equality as an example.""" )
#     me.assertTrue( 1 == 1 )

def inc(x):
    return x + 1


import re
# thx to https://stackoverflow.com/a/16710842/7568091
# thx to https://stackoverflow.com/a/13240255/7568091
rex = re.compile( r"""
  ( [^'"\s=/]+ )      # anything except quotes and whitespace
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
  ( [=/]+ )         # special characters
  |                 # or
  ( ['"]* )         # lone quotes
  """, re.DOTALL | re.VERBOSE )

#-----------------------------------------------------------------------------------------------------------
forbidden_pattern = re.compile( r'^[:=]|[:=]$' )


#-----------------------------------------------------------------------------------------------------------
def lex( tags_txt ):
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

#-----------------------------------------------------------------------------------------------------------
def test_quotes():
  probes_and_matchers = [
    [ '''tag''', None, ],
    [ '''tag foo 'bar' "baz" 'gnu x' "moo y"''', None, ],
    [ '''q=tag q=foo q='bar' q="baz" q='gnu x' q="moo y"''', None, ],
    [ '''tag::q foo::q 'bar'::q "baz"::q 'gnu x'::q "moo y"::q''', None, ],
    [ """'tag with spaces'""", None, ],
    [ '''ctx/tag''', None, ],
    [ '''tag=value''', None, ],
    [ """tag='value with spaces 1'""", None, ],
    [ '''tag="value with spaces 2"''', None, ],
    [ '''tag="value with spaces and \\"quotes\\" 2"''', None, ],
    [ """ctx/tag='value with spaces 1'""", None, ],
    [ '''ctx/tag="value with spaces 2"''', None, ],
    [ '''"Gun, Son of A." ::name''', None, ],
    [ '''"Gun, Son of A."::name''', None, ],
    [ '''"Gun, Son of A.::name"''', None, ],
    [ """name="Gun, Son of A." 'another tag'""", None, ],
    [ """tag foo 'bar baz'""", None, ],
    [ '''tag foo "bar baz"''', None, ],
    [ '''tag 'foo "bar baz" gnu\'''', None, ],
    ]
    # raise Exception( 'x')
  debug()
  for ( probe, matcher ) in probes_and_matchers:
    result  = lex( probe )
    # display = ' ∎ ' + ' ∎ '.join( result )
    display = result
    # debug( jrl( probe, display ) )
    debug( rpr([ probe, display ]) )
    # assert inc(3) == 4

#-----------------------------------------------------------------------------------------------------------
def test_syntax_errors():
  probes_and_matchers = [
    [ '''tag foo 'bar baz"''', None, ],
    ]
    # raise Exception( 'x')
  return

  debug()
  for ( probe, matcher ) in probes_and_matchers:
    result  = lex( probe )
    # display = ' ∎ ' + ' ∎ '.join( result )
    display = result
    # debug( jrl( probe, display ) )
    debug( rpr([ probe, display ]) )
    # assert inc(3) == 4


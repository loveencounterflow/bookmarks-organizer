
# -*- coding: utf-8 -*-

import re
texts = [
  r'''tag''',
  r'''tag foo 'bar' "baz" 'gnu x' "moo y"''',
  r'''q=tag q=foo q='bar' q="baz" q='gnu x' q="moo y"''',
  r'''tag::q foo::q 'bar'::q "baz"::q 'gnu x'::q "moo y"::q''',
  r"""'tag with spaces'""",
  r'''ctx:tag''',
  r'''tag=value''',
  r"""tag='value with spaces 1'""",
  r'''tag="value with spaces 2"''',
  r'''tag="value with spaces and \"quotes\" 2"''',
  r"""ctx:tag='value with spaces 1'""",
  r'''ctx:tag="value with spaces 2"''',
  r'''"Gun, Son of A."::name''',
  r'''"Gun, Son of A.::name"''',
  r'''name="Gun, Son of A." 'another tag\''''
  ]

def demo( ctx ):
  R = []
  for text in texts:
    # thx to https://stackoverflow.com/a/16710842/7568091
    pattern = r'''(?:[^\s,"']|["'](?:\\.|[^"'])*["'])+'''
    parts   = re.findall( pattern, text )
    R.append( ' ∎ ' + ' ∎ '.join( parts ) )
    ctx.log( ' ∎ ' + ' ∎ '.join( parts ) )
  return R


# print( '\u4e00'.encode( 'utf-8' ) )
# print( 'helo' )





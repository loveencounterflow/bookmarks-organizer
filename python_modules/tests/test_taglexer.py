


from unittest import TestCase
from .. cnd import debug, rpr, jr
from .. taglexer import lex_tags
def jrl( *P ): return jr( P )
assertion_count = 0
def eq( a, b ):
  global assertion_count
  assert a == b
  assertion_count += +1

#-----------------------------------------------------------------------------------------------------------
def test_unquoted_and_quoted():
  probes_and_matchers = [
    ['tag', ['tag']],
    ['tag foo \'bar\' "baz" \'gnu x\' "moo y"', ['tag', ' ', 'foo', ' ', 'bar', ' ', 'baz', ' ', 'gnu x', ' ', 'moo y']],
    ["tag='value with spaces 1'", ['tag', '=', 'value with spaces 1']],
    ['tag="value with spaces 2"', ['tag', '=', 'value with spaces 2']],
    ['tag="value with spaces and \\"quotes\\" 2"', ['tag', '=', 'value with spaces and \\"quotes\\" 2']],
    ]
  debug()
  for ( probe, matcher ) in probes_and_matchers:
    result  = lex_tags( probe )
    debug( '1', rpr([ probe, result ]) + ',' )
    eq( matcher, result )

#-----------------------------------------------------------------------------------------------------------
def test_contexts_named_values_and_refinements():
  probes_and_matchers = [
    ['q=tag q=foo q=\'bar\' q="baz" q=\'gnu x\' q="moo y"', ['q', '=', 'tag', ' ', 'q', '=', 'foo', ' ', 'q', '=', 'bar', ' ', 'q', '=', 'baz', ' ', 'q', '=', 'gnu x', ' ', 'q', '=', 'moo y']],
    ['tag::q foo::q \'bar\'::q "baz"::q \'gnu x\'::q "moo y"::q', ['tag::q', ' ', 'foo::q', ' ', 'bar', '::q', ' ', 'baz', '::q', ' ', 'gnu x', '::q', ' ', 'moo y', '::q']],
    ['programming/languages/sql', ['programming', '/', 'languages', '/', 'sql']],
    ['ctx/tag', ['ctx', '/', 'tag']],
    ['tag=value', ['tag', '=', 'value']],
    ["ctx/tag='value with spaces 1'", ['ctx', '/', 'tag', '=', 'value with spaces 1']],
    ['ctx/tag="value with spaces 2"', ['ctx', '/', 'tag', '=', 'value with spaces 2']],
    ['"Gun, Son of A." ::name', ['Gun, Son of A.', ' ', '::name']],
    ['"Gun, Son of A."::name', ['Gun, Son of A.', '::name']],
    ['"Gun, Son of A.::name"', ['Gun, Son of A.::name']],
    ['name="Gun, Son of A." \'another tag\'', ['name', '=', 'Gun, Son of A.', ' ', 'another tag']],
    ]
  debug()
  for ( probe, matcher ) in probes_and_matchers:
    result  = lex_tags( probe )
    debug( '2', rpr([ probe, result ]) + ',' )
    eq( matcher, result )

#-----------------------------------------------------------------------------------------------------------
def test_quotes():
  probes_and_matchers = [
    ["'tag with spaces'", ['tag with spaces']],
    ["tag foo 'bar baz'", ['tag', ' ', 'foo', ' ', 'bar baz']],
    ['tag foo "bar baz"', ['tag', ' ', 'foo', ' ', 'bar baz']],
    ['tag \'foo "bar baz" gnu\'', ['tag', ' ', 'foo "bar baz" gnu']],
    ]
    # raise Exception( 'x')
  debug()
  for ( probe, matcher ) in probes_and_matchers:
    result  = lex_tags( probe )
    debug( '3', rpr([ probe, result ]) + ',' )
    eq( matcher, result )

#-----------------------------------------------------------------------------------------------------------
def test_syntax_errors():
  probes_and_matchers = [
    [ '''tag foo 'bar baz"''', None, ],
    ]
    # raise Exception( 'x')
  return

  debug()
  for ( probe, matcher ) in probes_and_matchers:
    result  = lex_tags( probe )
    # display = ' ∎ ' + ' ∎ '.join( result )
    display = result
    # debug( jrl( probe, display ) )
    debug( '4', rpr([ probe, display ]) + ',' )
    # assert inc(3) == 4

#-----------------------------------------------------------------------------------------------------------
def test_last():
  debug( 'assertion_count', assertion_count )

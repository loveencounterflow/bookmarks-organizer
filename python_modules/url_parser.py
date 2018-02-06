

#-----------------------------------------------------------------------------------------------------------
from urllib.parse import urlparse as _parse_url
import re as _re


#-----------------------------------------------------------------------------------------------------------
def parse( url_ ):
  """Return all parts of `url_` ) as a list to match fields of the `U.url` type:

  ```
  create type U.url as (
    scheme    text,
    netloc    text,
    username  text,
    password  text,
    hostname  text,
    port      text,
    path      text,
    params    text,
    query     text,
    fragment  text );
  ```
  """
  R = _parse_url( url_ )
  return [
    R.scheme,
    R.netloc,
    R.username, R.password, R.hostname, R.port,
    R.path,     R.params,   R.query,    R.fragment, ]

#-----------------------------------------------------------------------------------------------------------
_word_splitters = _re.compile( r'[/._]' )

#-----------------------------------------------------------------------------------------------------------
def split_words( text ):
  R = _word_splitters.split( text )
  return [ r for r in R if r ]

#-----------------------------------------------------------------------------------------------------------
def split_hostname( hostname ):
  *subdomains, sld, tld = hostname.split( '.' )
  domain                = sld + '.' + tld
  return [
       [ 'url/tld',       tld,        ],
       [ 'url/sld',       sld,        ],
       [ 'url/domain',    domain,     ],
    *[ [ 'url/subdomain', subdomain,  ] for subdomain in subdomains ], ]

#-----------------------------------------------------------------------------------------------------------
def parse_words( url_ ):
  R = []
  scheme, netloc, username, password, hostname, port, path, params, query, fragment = parse( url_ )
  if username:  R.extend( [ [ 'url/username',   w, ] for w in split_words(    username ) ] )
  if password:  R.extend( [ [ 'url/password',   w, ] for w in split_words(    password ) ] )
  if path:      R.extend( [ [ 'url/path',       w, ] for w in split_words(    path     ) ] )
  if fragment:  R.extend( [ [ 'url/fragment',   w, ] for w in split_words(    fragment ) ] )
  if hostname:  R.extend( split_hostname( hostname ) )
  return R







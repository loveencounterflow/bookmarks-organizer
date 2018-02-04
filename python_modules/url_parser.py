

from urllib.parse import urlparse as _parse_url



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
def parse_words( url_ ):
  R = []
  scheme, netloc, username, password, hostname, port, path, params, query, fragment = parse( url_ )
  # if scheme:    R.append( scheme      )
  # if netloc:    R.append( netloc      )
  if username:  R.append( username    )
  if password:  R.append( password    )
  if hostname:  R.append( hostname    )
  # if port:      R.append( port        )
  if path:      R.append( path        )
  # if params:    R.append( params      )
  # if query:     R.append( query       )
  if fragment:  R.append( fragment    )
  return R



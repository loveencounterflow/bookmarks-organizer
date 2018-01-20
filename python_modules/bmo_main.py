
#-----------------------------------------------------------------------------------------------------------
def setup( ctx ):
  add_type_mappings( ctx )
  find_modules( ctx )

#-----------------------------------------------------------------------------------------------------------
def find_modules( ctx ):
  """Find all files with names ending in `'.py'` and not starting with an underscore, import those modules
  and add them to `ctx`."""
  #.........................................................................................................
  from os         import listdir
  from os.path    import isfile, join, basename, splitext, dirname, realpath
  from importlib  import import_module
  #.........................................................................................................
  my_name = basename( __file__ )
  my_path = dirname( realpath( __file__ ) )
  #.........................................................................................................
  for filename in listdir( my_path ):
    if      filename.startswith( '_'   ):        continue
    if not  filename.endswith(   '.py' ):        continue
    if filename == my_name:                      continue
    if not  isfile( join( my_path, filename ) ): continue
    #.......................................................................................................
    module_name         = splitext( filename )[ 0 ]
    ctx[ module_name ]  = import_module( module_name )

#-----------------------------------------------------------------------------------------------------------
def add_type_mappings( ctx ):
  """Retrieve all type name <-> OID mappings from `SQL.oids_and_types` and publish them as a two-way
  dictionary in `ctx.oids_and_types`."""
  #.........................................................................................................
  rows    = ctx.execute( 'select name, oid from SQL.oids_and_types' );
  target  = ctx.oids_and_types = {}
  for row in rows:
    target[ row[ 'name' ] ] = row[ 'oid'  ]
    target[ row[ 'oid'  ] ] = row[ 'name' ]
  #.........................................................................................................
  def keys_and_typenames_from_result( ctx, result ):
    keys    = result.colnames()
    types   = [ ctx.oids_and_types[ oid ] for oid in result.coltypes() ]
    return list( zip( keys, types ) )
  #.........................................................................................................
  ctx.keys_and_typenames_from_result = keys_and_typenames_from_result


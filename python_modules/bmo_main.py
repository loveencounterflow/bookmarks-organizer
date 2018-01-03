
#-----------------------------------------------------------------------------------------------------------
def setup( ctx ):
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




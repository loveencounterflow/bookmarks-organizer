


#-----------------------------------------------------------------------------------------------------------
from _tabulate.tabulate import tabulate as _tabulate
_tablefmt = 'fancy_grid'
_tablefmt = 'psqlu'
_tablefmt = 'psql'

#-----------------------------------------------------------------------------------------------------------
def tabulate( data ):
  return _tabulate( data, headers = 'firstrow', tablefmt = _tablefmt )







#-----------------------------------------------------------------------------------------------------------
from _tabulate.tabulate import tabulate as _tabulate

#-----------------------------------------------------------------------------------------------------------
def tabulate( data ):
  return _tabulate( data, headers = 'firstrow', tablefmt = 'psql' )




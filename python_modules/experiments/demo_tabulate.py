
import sys

sys.path.insert( 0, '/home/flow/io/bookmarks-organizer/python_modules/tabulate-0.8.2' )

from tabulate import tabulate
# print( dir( tabulate ) )


table = [ ["body","radius / km", "mass / 10^29 kg"], ["Sun",696000,1989100000],["Earth",6371,5973.6], ["Moon",1737,73.5],["Mars",3390,641.85]]

# styles = [
#   'plain',
#   'simple',
#   'grid',
#   'fancy_grid',
#   'pipe',
#   'orgtbl',
#   'jira',
#   'presto',
#   'psql',
#   'rst',
#   'mediawiki',
#   'moinmoin',
#   'youtrack',
#   'html',
#   'latex',
#   'latex_raw',
#   'latex_booktabs',
#   'textile',
#   ]

# for style in styles:
#   print( '----------------------------------------------------------------' )
#   print( style )
#   print( tabulate(table, headers="firstrow", tablefmt = style ) )

print( tabulate(table, headers="firstrow", tablefmt = 'psql' ) )





"""

 .d8888b. 8888888 .d8888b.  888b    888        d8888 888      .d8888b.
d88P  Y88b  888  d88P  Y88b 8888b   888       d88888 888     d88P  Y88b
Y88b.       888  888    888 88888b  888      d88P888 888     Y88b.
 "Y888b.    888  888        888Y88b 888     d88P 888 888      "Y888b.
    "Y88b.  888  888  88888 888 Y88b888    d88P  888 888         "Y88b.
      "888  888  888    888 888  Y88888   d88P   888 888           "888
Y88b  d88P  888  Y88b  d88P 888   Y8888  d8888888888 888     Y88b  d88P
 "Y8888P" 8888888 "Y8888P88 888    Y888 d88P     888 88888888 "Y8888P"

"""

#-----------------------------------------------------------------------------------------------------------
import socket as _SOCKET
import os     as _OS
import json   as _JSON
GD = {}

#-----------------------------------------------------------------------------------------------------------
def _prepare():
  if GD.get( 'SIGNALS.client_socket_rfile', None ) != None: return
  host                                = 'localhost'
  port                                = 21567
  client_socket                       = _SOCKET.socket( _SOCKET.AF_INET, _SOCKET.SOCK_STREAM )
  client_socket.connect( ( host, port, ) )
  client_socket_rfile                 = _OS.fdopen( client_socket.fileno(), 'r', encoding = 'utf-8' )
  GD[ 'SIGNALS.client_socket'       ] = client_socket
  GD[ 'SIGNALS.client_socket_rfile' ] = client_socket_rfile
  # _write_line( '{"data":"helo","role":"q","channel":"all","command":"helo"}' )
  _send( 'all', 'helo', 'q', _JSON.dumps( '++helo++' ) )

#-----------------------------------------------------------------------------------------------------------
def _write_line( line ):
  _prepare()
  line_b = str.encode( line + '\n' )
  GD[ 'SIGNALS.client_socket' ].send( line_b )

#-----------------------------------------------------------------------------------------------------------
def _read_line():
  return GD[ 'SIGNALS.client_socket_rfile' ].readline().strip()

#-----------------------------------------------------------------------------------------------------------
def _send( channel, command, role, data ):
  _prepare()
  event = { 'channel':  channel, 'command':  command, 'role':  role, 'data': data, }
  _write_line( _JSON.dumps( event ) )






'use strict'

### https://ponyfoo.com/articles/understanding-javascript-async-await ###


############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'YAU/DEMO-2'
debug                     = CND.get_logger 'debug',     badge
alert                     = CND.get_logger 'alert',     badge
whisper                   = CND.get_logger 'whisper',   badge
warn                      = CND.get_logger 'warn',      badge
help                      = CND.get_logger 'help',      badge
urge                      = CND.get_logger 'urge',      badge
info                      = CND.get_logger 'info',      badge
crypto                    = require 'crypto'

@_demo = ->
  for cipher in crypto.getCiphers()
    # debug cipher
    continue unless ( cipher.match /aes/ )?
    # continue unless ( cipher.match /aes-128|rc4|rc2/ )?
    # continue unless ( cipher.match /cb|rc4|rc2/ )?
    continue if cipher.endsWith 'wrap'
    continue if cipher.endsWith 'xts'
    continue if cipher in [ 'aes-128-ccm', 'aes-128-ctr', 'aes-128-gcm', 'aes-192-ccm', 'aes-192-ctr', 'aes-192-gcm', 'aes-256-ccm', 'aes-256-ctr', 'aes-256-gcm', 'id-aes128-CCM', 'id-aes128-GCM', 'id-aes192-CCM', 'id-aes192-GCM', 'id-aes256-CCM', 'id-aes256-GCM', ]
    help ( @encrypt 'secret', 'x',        cipher ), "(#{cipher})"
    urge ( @encrypt 'secret', 'xx',       cipher ), "(#{cipher})"
    urge ( @encrypt 'secret', 'xxxx',     cipher ), "(#{cipher})"
    urge ( @encrypt 'secret', 'xxxxxx',   cipher ), "(#{cipher})"
    # help encrypted, "(#{cipher})"


# decrypter   = crypto.createDecipher 'aes192', 'a password'
# encrypted   = 'ca981be48e90867604588e75d04feabb63cc007a8f8ad89b10616ed84d815504';
# decrypted   = decrypter.update encrypted, 'hex', 'utf8'
# decrypted  += decrypter.final 'utf8'
# info decrypted

#-----------------------------------------------------------------------------------------------------------
@_default_cipher  = 'aes128'
@_salt_length     = 5

#-----------------------------------------------------------------------------------------------------------
@_salt = ->
  ### TAINT not a very good salt ###
  R = ( 'x'.repeat @_salt_length ) + Math.random()
  return R[ R.length - @_salt_length .. ]

#-----------------------------------------------------------------------------------------------------------
@encrypt = ( password, text, cipher = null ) ->
  cipher     ?= @_default_cipher
  salt        = @_salt()
  encrypter   = crypto.createCipher cipher, password
  R           = encrypter.update salt, 'utf8', 'hex'
  R           = encrypter.update text, 'utf8', 'hex'
  R          += encrypter.final 'hex'
  # encrypter1  = crypto.createCipher cipher, password
  # R1          = encrypter1.update salt, 'utf8', 'base64'
  # R1          = encrypter1.update text, 'utf8', 'base64'
  # R1         += encrypter1.final 'base64'
  # debug R1
  R           = "#{cipher}:#{R}"
  return R

#-----------------------------------------------------------------------------------------------------------
@decrypt = ( password, text ) ->
  [ cipher, text, ] = text.split ':'
  try
    decrypter         = crypto.createDecipher cipher, password
    R                 = decrypter.update text, 'hex', 'utf8'
    R                += decrypter.final 'utf8'
  catch error
    throw new Error "unable to decrypt (#{error.message})"
  R                 = R[ @_salt_length ... ]
  return R

text      = "abcdef"
password  = 'secret'
help text
help text_c = @encrypt password, text
help text_r = @decrypt 'secret', text_c
help CND.truth text_r is text
# @_demo()
# debug @_salt()
# debug @_salt()
# debug @_salt()




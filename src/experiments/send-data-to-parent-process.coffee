


FS                        =  require 'fs'
{ log, }                  = console

input = FS.createReadStream null, { fd: 3, }
input.pipe process.stdout
output = FS.createWriteStream null, { fd: 4, }
for _ in [ 0 .. 10 ]
  output.write 'Sending a message back.\n'
# output.close()
# input.close()

setTimeout ( -> log 'ok' ), 10 * 1000


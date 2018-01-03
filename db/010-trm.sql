
-- ---------------------------------------------------------------------------------------------------------
drop schema if exists TRM cascade;
create schema TRM;

-- ---------------------------------------------------------------------------------------------------------
\set blink        '\x1b[5m'
\set bold         '\x1b[1m'
\set reverse      '\x1b[7m'
\set underline    '\x1b[4m'
\set reset        '\x1b[0m'
\set black        '\x1b[38;05;16m'
\set blue         '\x1b[38;05;27m'
\set green        '\x1b[38;05;34m'
\set cyan         '\x1b[38;05;51m'
\set sepia        '\x1b[38;05;52m'
\set indigo       '\x1b[38;05;54m'
\set steel        '\x1b[38;05;67m'
\set brown        '\x1b[38;05;94m'
\set olive        '\x1b[38;05;100m'
\set lime         '\x1b[38;05;118m'
\set red          '\x1b[38;05;124m'
\set crimson      '\x1b[38;05;161m'
\set plum         '\x1b[38;05;176m'
\set pink         '\x1b[38;05;199m'
\set orange       '\x1b[38;05;208m'
\set gold         '\x1b[38;05;214m'
\set tan          '\x1b[38;05;215m'
\set yellow       '\x1b[38;05;226m'
\set grey         '\x1b[38;05;240m'
\set darkgrey     '\x1b[38;05;234m'
\set white        '\x1b[38;05;255m'


\set O            :reset
\set TITLE        :yellow
\set Xcolor       :orange
\set OUT          :yellow'output written to ':lime
\set X            :plum
\set out          '/tmp/psql-output'
\set devnull      '/dev/null'

-- \echo :F'trm.meta.sql':O
-- \echo :X'experiments-echo-message.sql':O
-- \echo ok

-- -- ---------------------------------------------------------------------------------------------------------
-- create table TRM.colors (
--   key   text unique not null primary key,
--   value text        not null );

-- -- ---------------------------------------------------------------------------------------------------------
-- insert into TRM.colors values
--   ( 'blink',          :'blink'        ),
--   ( 'bold',           :'bold'         ),
--   ( 'reverse',        :'reverse'      ),
--   ( 'underline',      :'underline'    ),
--   ( 'reset',          :'reset'        ),
--   ( 'black',          :'black'        ),
--   ( 'blue',           :'blue'         ),
--   ( 'green',          :'green'        ),
--   ( 'cyan',           :'cyan'         ),
--   ( 'sepia',          :'sepia'        ),
--   ( 'indigo',         :'indigo'       ),
--   ( 'steel',          :'steel'        ),
--   ( 'brown',          :'brown'        ),
--   ( 'olive',          :'olive'        ),
--   ( 'lime',           :'lime'         ),
--   ( 'red',            :'red'          ),
--   ( 'crimson',        :'crimson'      ),
--   ( 'plum',           :'plum'         ),
--   ( 'pink',           :'pink'         ),
--   ( 'orange',         :'orange'       ),
--   ( 'gold',           :'gold'         ),
--   ( 'tan',            :'tan'          ),
--   ( 'yellow',         :'yellow'       ),
--   ( 'grey',           :'grey'         ),
--   ( 'darkgrey',       :'darkgrey'     ),
--   ( 'white',          :'white'        );




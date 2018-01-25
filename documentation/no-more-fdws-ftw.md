

# No More FDWs FTW!

In my ongoing search on how to best feed data from the outside world into an
RDBMS, I started by using a client library
([`node-postgres`](https://github.com/brianc/node-postgres) in this case) which
iterates over the lines of a data source file, somewhat preprocesses the data
and then sends those objects (one by one or in batches) to the receiving DB.
This turned out to be rather slow and cumbersome; also, it necessitates to write
preprocessing code and, worse, makes the workflow and the accuracy of the data
in the DB dependent on running data feeding jobs at the appropriate points in
time.

All that changed when I became aware of PostGreSQL's Foreign Data Wrapper (FDW)
for files, `file_fdw`. All of a sudden, those data feeding sessions were gone,
and I could see current data in all the views. Moreover, I realized that
transforming line-oriented data to table data was much better done in the DB
than outside of it, not because PostGreSQL has the nicer languages or the nicer
user interface, but simply because I was then able to build intermediate views
that show very clearly the success (or the failure) of each transformational
step. To the contrary, building such a processing pipeline is considerably
*more* cumbersome in PostGreSQL than in, say, CoffeeScript using the
[PipeStreams](https://github.com/loveencounterflow/pipestreams) library, but the
step-by-step observability of the process make the extra work totally
worthwhile.

The file FDW was also a perfect fit for the [JSON Lines format](http://jsonlines.org/), a
natural specialization of JSON where each line in a file has to contain exactly
one JSON value, no more, no less. JSON Lines are great for log files where
you have different fields for each type of message, which can be nicely modeled by
JSON objects.

Turns out the file FDW *was* a perfect fit until it turned out that PostGreSQL's
`COPY` mechanism which `file_fdw` uses will interpret backslash-escaped
characters *before* it hands them over to the user; this turned any symbolic
newline and all escaped double quotes into its literal counterpart, meaning that
a one-liner `"a string\nwith \"quotes\" here"` becomes a two-lines consisting of
`"a string` and `with "quotes" here"`, neither of which is legal JSON. Ouch.
Repairing that damage after the fact is a nuisance and a can only be done in a
speculative fashion. It's really bad that PostGreSQL doesn't have an option for
`COPY` that mandates raw input lines, but I can't fix that.

My first impulse in repairing these shortcomings was to look for a FDW that does
the right thing out of the box; alas, the only candidate I could find was
[pgsql-fio](https://github.com/csimsek/pgsql-fio/). Now I've become a bit wary
about solutions that require custom C compilation outside of package managers
and bundled distros as you can never know whether you'd be able to rectify a
broken compilation step on some future machine or with some future version of
PostGreSQL, so I looked on.

I then remebered Multicorn—a framework to implement PG FDWs in Python—and
realized, again, that while it comes nicely bundled and is readily available as
`sudo apt install postgresql-10-python3-multicorn`, the website does look sort
of unfinished and when you look at what has been implemented using that tool,
it's relatively little. Overall. the project makes a somewhat abandoned project.
I for one became soon tired when reading up on how to write an extension within
that framework.

Lastly, and this is where the story ends for the time being, I sat down and
implemented my own solution in Python (`plpgpython3u`, that is). I had beaten
around this particular bush because I was afraid that a Python solution was to
mean that each file had to be swallowed in one gulp no matter what size. Turns
out I was wrong. Turns out the solution is so simple you could just jot it down
each time you wanted to access a particular file from within the DB. It goes
like this:

```
set role dba;
create function FLR.read_file_lines( path_ text )
  returns table ( linenr integer, line text )
  volatile language plpython3u as $$
    with open( path_, 'rb' ) as input:
      for linenr, line in enumerate( input ):
        yield [ linenr, line.decode( 'utf-8' ).rstrip(), ]
    $$;
reset role;
```

And that's it! A simple `create view x as ( select linenr, line from read_file_lines( 'path' );`
and all ready you are already.

The best of this is what the above straight-forward 9 LOC, 0.3k chrs
replace—it's these rather convoluted and annoyingly complex ~60 lines, > 2k
chrs:

```
drop function if exists _create_file_fdw( text ) cascade;
create function _create_file_fdw( text ) returns void language plpgsql as $outer$
  declare
    q text;
  begin
    q := $$ set role dba;
      drop extension if exists file_fdw cascade;
      create extension if not exists file_fdw;
      grant all privileges on foreign data wrapper file_fdw to $$ || $1 || $$;
      drop server if exists file_as_lines cascade;
      create server file_as_lines foreign data wrapper file_fdw;
      grant all privileges on foreign server file_as_lines to $$ || $1 || $$;
      reset role;$$;
    execute q;
    end; $outer$;

do $$ begin perform _create_file_fdw( current_user ); end; $$;

create function FLR._create_file_lines_table( ¶table_name text, ¶path text ) returns void
  volatile language plpgsql as $outer$
  declare
    ¶q text;
    ¶username text := current_user;
  begin
    ¶q := $$ set role dba;
      create foreign table $$||¶table_name||$$
        ( line text )
        server file_as_lines options (
          filename $$||quote_literal( ¶path )||$$,
          -- format 'binary' );
          format 'text', delimiter E'\x01' );
      grant all privileges on table $$||¶table_name||$$ to $$||¶username||$$;
      reset role;$$;
    execute ¶q;
    end; $outer$;

create function FLR.create_file_lines_view( ¶view_name text, ¶path text ) returns void
  volatile language plpgsql as $outer$
  declare
    ¶q              text;
    ¶table_name_q   text;
    ¶view_name_q    text;
    ¶name_parts     text[];
  begin
    ¶name_parts := parse_ident( ¶view_name );
    case array_length( ¶name_parts, 1 )
      when 1 then
        ¶table_name_q = quote_ident( '_' || ¶name_parts[ 1 ] );
        ¶view_name_q  = quote_ident(        ¶name_parts[ 1 ] );
      when 2 then
        ¶table_name_q = quote_ident( ¶name_parts[ 1 ] ) || '.' || quote_ident( '_' || ¶name_parts[ 2 ] );
        ¶view_name_q  = quote_ident( ¶name_parts[ 1 ] ) || '.' || quote_ident(        ¶name_parts[ 2 ] );
      end case;
    perform FLR._create_file_lines_table( ¶table_name_q, ¶path );
    ¶q := $$
      create view $$||¶view_name_q||$$ as ( select
          row_number() over ()  as linenr,
          line                  as line
        from
          $$||¶table_name_q||$$ ); $$;
    execute ¶q;
    end; $outer$;
```

So with one-sixth of code extension we've managed to implement a solution that
is far more general, far more extensible and far easier to maintain than the
standard solution. Now, Python is not a trivial piece of software but then we
only used the most mundane pieces of it. By way of contrast, I had to throw a
lot of little one-off tricks at the FDW solution to make it work. Well, *almost*
work.

I guess the next time I want to channel external datasources into my DB I won't
give FDWs a second thought. I now think it's a wrong solution because the entire
mechanism has become so unwieldy people have come up with unwieldy wrappers to
keep that unwieldiness from wielding unwieldiness upon your code, except they
don't succeed in that. It's a *much* better idea to give people a decent
programming language / VM (including a decent generic VM/DB interface to be
sure) and let them formulate their solutions than to introduce yet another
highly complex, yet ultimately also highly specific framework-ish interface-y
whatchamaycallit. Nothing keeps you from drawing from a wide range of existing
Python solutions to connect to other databases, web pages, local services,
whatever, and then just `yield` that data into the DB. No more FDWs.



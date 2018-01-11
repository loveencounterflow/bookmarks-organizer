

/*

https://www.postgresql.org/docs/current/static/sql-syntax-lexical.html

*/


select regexp_split_to_array(
  'foo,,bar--baz  gnu''''gnat', E'
    ( , | - | '' | \\s )            # a comma or a dash
    \\1                              # another comma or dash
    ', 'x' );

select regexp_split_to_array( 'foo=bar x::name',
 E'
    ( [^ '' " \\s = / : ]+ )   |      # anything except quotes and whitespace
    ( [ '' " ] )                      # an opening quote
    (                                 # followed by
      (?:                             #   the following:
        \\\\.                  |      #     an escaped character
        # (?! \\2 )                     #     (as long as we are not right at the matching quote)
        .                             #     any other character,
        )*                            #     repeated.
      )                               #
    \\2                        |      # corresponding closing quote
    ( \\s+ )                   |      # whitespace
    ( [ = / : ]+ )             |      # special characters
    ( [ '' " ]* )                     # lone quotes
      ', 'x' );

select '{"foo"}'::text[];
select '{"foo,\"x,bar"}'::text[];
select ( UTP.lex_tags( '"he\"lo"' ) );
select ( UTP.lex_tags( '"he\"lo"' ) )[ 1 ];
select ( UTP.lex_tags( '"he\"lo"' ) )[ 1 ] ~ '\\';
\quit

select 1, '\s';   -- ok
select 2, '\\s';
select 3, '\\\s';
select 4, '\\\\s';
select 5, E'\s';
select 6, E'\\s';  -- ok
select 7, E'\\\s';
select 8, E'\\\\s';
\quit

/*
select regexp_split_to_array(
  'foo,,bar--baz gnu', E'(,|-|\\s)\\1' );
*/

-- select $$ #\s\x56\\x56# $$, ' #\s\x56\\x56# ', E' #\s\x56\\x56# ';

-- select U&'-\4e01-!4e02-';
-- select U&'-\4e01-!4e02-°4e03-' uescape '!';
-- select U&'-\4e01-!4e02-`4e03-' uescape '`';
-- select U&$$-\4e01-!4e02-$$;
-- select U&$$-\4e01-!4e02-°4e03-$$ uescape $$!$$;
-- select U&$$-\4e01-!4e02-`4e03-$$ uescape $$`$$;



/*

888
888
888
88888b.    8888b.   888d888
888 "88b      "88b  888P"
888  888  .d888888  888
888 d88P  888  888  888
88888P"   "Y888888  888

*/

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists BAR cascade;
create schema BAR;

-- ---------------------------------------------------------------------------------------------------------
create or replace function BAR.bar( n integer ) returns text immutable language plpgsql as $$
  declare
    R text;
  begin
    if n is null or n <= 0  then return '';               end if;
    if n > 100              then return '████████████▌';  end if;
    R := repeat( '█', n / 8 );
    case n % 8
      when 0 then    R = R || '';
      when 1 then    R = R || '▏';
      when 2 then    R = R || '▎';
      when 3 then    R = R || '▍';
      when 4 then    R = R || '▌';
      when 5 then    R = R || '▋';
      when 6 then    R = R || '▊';
      when 7 then    R = R || '▉';
      -- when 8 then R = R || '█';
      end case;
    return R;
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create or replace function BAR.bar( n bigint ) returns text immutable language sql as $$
  select BAR.bar( n::integer ); $$;

-- ---------------------------------------------------------------------------------------------------------
create or replace function BAR.bar( n bigint, ref bigint ) returns text immutable language sql as $$
  select BAR.bar( ( n::float / ref::float * 100 )::integer ); $$;

-- ---------------------------------------------------------------------------------------------------------
create or replace function BAR.bar( n float, ref float ) returns text immutable language sql as $$
  select BAR.bar( ( n / ref * 100 )::integer ); $$;

\quit

\echo ' ' -- 0
\echo '▏' -- 1
\echo '▎' -- 2
\echo '▍' -- 3
\echo '▌' -- 4
\echo '▋' -- 5
\echo '▊' -- 6
\echo '▉' -- 7
\echo '█' -- 8
\echo ' ' -- 0
\echo '▁' -- 1
\echo '▂' -- 2
\echo '▃' -- 3
\echo '▄' -- 4
\echo '▅' -- 5
\echo '▆' -- 6
\echo '▇' -- 7
\echo '█' -- 8






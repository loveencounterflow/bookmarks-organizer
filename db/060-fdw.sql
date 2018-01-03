
/*

8888888888 8888888b.   888       888
888        888  "Y88b  888   o   888
888        888    888  888  d8b  888
8888888    888    888  888 d888b 888
888        888    888  888d88888b888
888        888    888  88888P Y88888
888        888  .d88P  8888P   Y8888
888        8888888P"   888P     Y888

*/

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists FDW cascade;
create schema FDW;

-- ---------------------------------------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------------------------------------
create function FDW._create_file_lines_table( ¶table_name text, ¶path text ) returns void
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
          format 'text',
          delimiter E'\x01' );
      grant all privileges on table $$||¶table_name||$$ to $$||¶username||$$;
      reset role;$$;
    execute ¶q;
    end; $outer$;

-- ---------------------------------------------------------------------------------------------------------
create function FDW.create_file_lines_view( ¶view_name text, ¶path text ) returns void
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
    perform FDW._create_file_lines_table( ¶table_name_q, ¶path );
    ¶q := $$
      create view $$||¶view_name_q||$$ as ( select
          row_number() over ()  as linenr,
          line                  as line
        from
          $$||¶table_name_q||$$ ); $$;
    execute ¶q;
    end; $outer$;






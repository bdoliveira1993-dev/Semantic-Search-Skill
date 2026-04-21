-- =============================================================================
-- Semantic Search Skill — Supabase Setup
-- =============================================================================
-- This script creates everything needed to use the semantic-search skill:
--   1. Required extensions (vector, pg_net, supabase_vault)
--   2. The items table with vector column
--   3. Row Level Security policies
--   4. OpenAI API key storage in Vault
--   5. Search functions (textual via RPC, semantic via embeddings)
--   6. Embedding generation function
--
-- Run in order. Replace <YOUR_OPENAI_KEY> before running the Vault insert.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Extensions
-- -----------------------------------------------------------------------------
create extension if not exists vector with schema extensions;
create extension if not exists pg_net with schema extensions;
-- supabase_vault is enabled by default on Supabase projects


-- -----------------------------------------------------------------------------
-- 2. Items table
-- -----------------------------------------------------------------------------
-- Adapt column names to your domain. The required columns for the skill are:
--   id, name, category, subcategory, supplier, unit, unit_price,
--   search_content, embedding.
-- You can add as many domain-specific columns as you want.
-- -----------------------------------------------------------------------------
create table if not exists public.items (
  id              bigserial primary key,
  code            text,
  name            text not null,
  category        text,
  subcategory     text,
  supplier        text,
  unit            text,
  unit_price      numeric,
  specs           text,
  search_content  text,
  embedding       extensions.vector(1536),
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- Index for fast textual search
create index if not exists items_search_content_idx
  on public.items using gin (to_tsvector('simple', coalesce(search_content, '')));

-- Index for fast vector similarity search (HNSW)
create index if not exists items_embedding_idx
  on public.items using hnsw (embedding extensions.vector_cosine_ops);


-- -----------------------------------------------------------------------------
-- 3. Row Level Security (public read, authenticated write)
-- -----------------------------------------------------------------------------
alter table public.items enable row level security;

create policy "items_read_public"
  on public.items for select
  using (true);

create policy "items_write_authenticated"
  on public.items for insert
  to authenticated
  with check (true);

create policy "items_update_authenticated"
  on public.items for update
  to authenticated
  using (true);


-- -----------------------------------------------------------------------------
-- 4. Store OpenAI API key in Vault
-- -----------------------------------------------------------------------------
-- Replace <YOUR_OPENAI_KEY> with your actual key. The key will be encrypted
-- at rest and only accessible via vault.decrypted_secrets inside functions.
-- -----------------------------------------------------------------------------
select vault.create_secret(
  '<YOUR_OPENAI_KEY>',
  'openai_api_key',
  'OpenAI API key used by the semantic-search skill for embedding generation'
);


-- -----------------------------------------------------------------------------
-- 5. Semantic search functions
-- -----------------------------------------------------------------------------

-- 5a. Vector similarity search (advanced — requires pre-generated embedding)
create or replace function public.search_items_vector(
  query_embedding extensions.vector(1536),
  match_limit int default 10,
  category_filter text default null,
  subcategory_filter text default null
)
returns table (
  id bigint,
  name text,
  category text,
  subcategory text,
  supplier text,
  unit text,
  unit_price numeric,
  similarity float
)
language sql
stable
set search_path = public, extensions
as $$
  select
    i.id, i.name, i.category, i.subcategory, i.supplier,
    i.unit, i.unit_price,
    1 - (i.embedding <=> query_embedding) as similarity
  from public.items i
  where i.embedding is not null
    and (category_filter is null or i.category = category_filter)
    and (subcategory_filter is null or i.subcategory = subcategory_filter)
  order by i.embedding <=> query_embedding
  limit match_limit;
$$;


-- 5b. Text-based semantic search (generates embedding internally via Vault)
create or replace function public.search_items_text(
  query_text text,
  match_limit int default 10,
  category_filter text default null,
  subcategory_filter text default null
)
returns table (
  id bigint,
  name text,
  category text,
  subcategory text,
  supplier text,
  unit text,
  unit_price numeric,
  similarity float
)
language plpgsql
set search_path = public, extensions
as $$
declare
  api_key text;
  response_json jsonb;
  query_vector extensions.vector(1536);
begin
  -- Fetch OpenAI key from Vault
  select decrypted_secret into api_key
  from vault.decrypted_secrets
  where name = 'openai_api_key';

  if api_key is null then
    raise exception 'OpenAI API key not found in Vault';
  end if;

  -- Call OpenAI embeddings API via pg_net
  select content::jsonb into response_json
  from extensions.http((
    'POST',
    'https://api.openai.com/v1/embeddings',
    array[
      extensions.http_header('Authorization', 'Bearer ' || api_key),
      extensions.http_header('Content-Type', 'application/json')
    ],
    'application/json',
    jsonb_build_object(
      'model', 'text-embedding-3-small',
      'input', query_text
    )::text
  )::extensions.http_request);

  -- Extract the embedding vector
  query_vector := (response_json->'data'->0->'embedding')::text::extensions.vector(1536);

  -- Return semantic search results
  return query
  select * from public.search_items_vector(
    query_vector,
    match_limit,
    category_filter,
    subcategory_filter
  );
end;
$$;


-- 5c. Batch embedding generation for records without embeddings
create or replace function public.generate_embeddings_batch(
  batch_limit int default 10
)
returns int
language plpgsql
set search_path = public, extensions
as $$
declare
  api_key text;
  item_record record;
  response_json jsonb;
  processed int := 0;
begin
  select decrypted_secret into api_key
  from vault.decrypted_secrets
  where name = 'openai_api_key';

  if api_key is null then
    raise exception 'OpenAI API key not found in Vault';
  end if;

  for item_record in
    select id, coalesce(search_content, name) as content
    from public.items
    where embedding is null
      and (search_content is not null or name is not null)
    limit batch_limit
  loop
    select content::jsonb into response_json
    from extensions.http((
      'POST',
      'https://api.openai.com/v1/embeddings',
      array[
        extensions.http_header('Authorization', 'Bearer ' || api_key),
        extensions.http_header('Content-Type', 'application/json')
      ],
      'application/json',
      jsonb_build_object(
        'model', 'text-embedding-3-small',
        'input', item_record.content
      )::text
    )::extensions.http_request);

    update public.items
    set embedding = (response_json->'data'->0->'embedding')::text::extensions.vector(1536),
        updated_at = now()
    where id = item_record.id;

    processed := processed + 1;
  end loop;

  return processed;
end;
$$;


-- -----------------------------------------------------------------------------
-- 6. Helper trigger to auto-populate search_content
-- -----------------------------------------------------------------------------
create or replace function public.update_search_content()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.search_content := lower(concat_ws(' ',
    new.name,
    new.category,
    new.subcategory,
    new.supplier,
    new.specs,
    new.code
  ));
  new.updated_at := now();
  return new;
end;
$$;

create trigger items_search_content_trigger
  before insert or update on public.items
  for each row
  execute function public.update_search_content();


-- =============================================================================
-- Done. Next steps:
--   1. Insert your OpenAI key in Vault (section 4)
--   2. Load sample data from sql/example_data.sql (optional, for testing)
--   3. Run: SELECT generate_embeddings_batch(50); to populate embeddings
--   4. Configure the skill's SKILL.md with your project_id
-- =============================================================================

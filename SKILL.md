---
name: semantic-search
description: "Use this skill whenever the user wants to query, search, list, compare, or retrieve information from a Supabase catalog with pgvector-based semantic search. Trigger when the user mentions item names, prices, suppliers, categories, or any query that involves a catalog/inventory/materials database. Also triggers on phrases like 'search catalog', 'find item', 'how much does X cost', 'list items', 'what do we have', 'who supplies', or vague requests like 'show me what we have for electrical'. Adapt the domain-specific terms in this skill to your own catalog before using."
---

# Skill: Semantic Search over Supabase Catalog

## Overview

This skill enables querying a catalog of items stored in Supabase using both textual and semantic search. It is a **generic template** — adapt the table schema, column names, and filter terms to your own domain (products, materials, contracts, documents, etc.).

The catalog supports two search modes:
- **Textual search** (ilike) — fast, exact match, no API cost
- **Semantic search** (embeddings) — understands synonyms and context, uses OpenAI embeddings via Supabase Vault

## Configuration

Before using this skill, configure the following placeholders:

- `<PROJECT_ID>` — your Supabase project ID (do not commit publicly)
- `<TABLE_NAME>` — your catalog table (default: `items`)
- `<DOMAIN_TERMS>` — adapt the trigger terms in the description above to your domain

The expected schema is documented in `sql/setup.sql`. See the README for full setup instructions.

## Expected schema

**Table:** `public.<TABLE_NAME>` (default: `items`)

Minimum required columns for this skill to work:

| Column | Type | Description |
|--------|------|-------------|
| id | bigserial | Primary key |
| name | text | Item display name (main search field) |
| category | text | Top-level category for filtering |
| subcategory | text | Secondary grouping |
| supplier | text | Manufacturer or supplier |
| unit | text | Unit of measure (EA, M, KG, etc.) |
| unit_price | numeric | Unit price |
| search_content | text | Concatenated text for full-text search |
| embedding | vector(1536) | OpenAI text-embedding-3-small vector |

Additional columns (price history, specs, metadata) can be added freely without breaking the skill — only the ones above are required for the queries below.

## Security

- Enable RLS: public read, authenticated write
- Store OpenAI API key in Supabase Vault (key name: `openai_api_key`) — never expose it in queries
- Functions should use `search_path = public, extensions` to prevent injection

See `sql/setup.sql` for the full security configuration.

## How to query

Use the `Supabase:execute_sql` tool with `project_id: "<PROJECT_ID>"` to execute SQL queries.

### Choosing the search mode

| Situation | Recommended mode |
|-----------|------------------|
| Exact term search (code, partial name, supplier) | Textual (ilike) |
| Concept, functional description, or synonyms | Semantic |
| Listing by category | Textual (ilike) |
| Price comparison | Textual (ilike) |
| Group summary / counts | Textual (ilike) |
| User describes need without knowing the technical name | Semantic |

### Mode 1: Textual search (ilike) — default for exact queries

Search by item name (most common):
```sql
select name, category, subcategory, supplier, unit, unit_price
from public.items
where search_content ilike '%search_term%'
order by name
limit 20;
```

Search filtered by category:
```sql
select name, supplier, unit, unit_price
from public.items
where category = 'ELECTRICAL'
  and search_content ilike '%cable%'
order by name
limit 20;
```

Price comparison:
```sql
select name, supplier, unit, unit_price
from public.items
where search_content ilike '%transformer%'
  and unit_price is not null
order by unit_price asc
limit 20;
```

Summary by category:
```sql
select category, count(*) as qty, count(unit_price) as with_price
from public.items
group by category
order by qty desc;
```

### Mode 2: Semantic search — for concept/description queries

Use the `search_items_text` function which generates the embedding internally (OpenAI key pulled from Vault):

```sql
SELECT name, category, supplier, unit, unit_price, similarity
FROM public.search_items_text(
  'description of what the user needs',  -- free text
  10,                                    -- result limit
  NULL,                                  -- category_filter (optional)
  NULL                                   -- subcategory_filter (optional)
);
```

Example with filters:
```sql
SELECT name, supplier, unit, unit_price, similarity
FROM public.search_items_text(
  'ESFR pendent sprinkler for logistics warehouse',
  5,
  'FIRE_PROTECTION',
  NULL
);
```

The `similarity` column (0 to 1) indicates relevance. Values above 0.5 are generally good matches.

### Generating embeddings for new records

When new items are inserted without embeddings, run:
```sql
SELECT generate_embeddings_batch(10);  -- processes 10 records per call
```

The function pulls the OpenAI key from Vault automatically. No key needs to be passed as a parameter.

## Recommended search strategy

**Step 1 — Identify what the user wants:**
- Find specific item by name/code? → Textual (ilike)
- Describes need without technical name? → Semantic
- List by category? → Textual with category filter
- Compare prices? → Textual ordered by price
- Search by supplier? → Textual with supplier filter

**Step 2 — Execute the chosen search (textual or semantic)**

**Step 3 — If results are poor:**
- If textual: try shorter/more generic terms, or switch to semantic
- If semantic: reformulate the description, or switch to textual with partial terms
- Use multiple `ilike` with `or` to cover variations
- Try searching without accents (the database may have variations)

### Tips

1. **Always use `ilike`** (case-insensitive) instead of `like`
2. **Limit results** to 20 records by default to avoid overloading context
3. **Select only relevant columns** for the user's question
4. **Values like '-' or 'N/A'** are common — treat them as missing data
5. **The `search_content` column** is best for generic text search (concatenates multiple fields)
6. **Break compound terms** into separate words with multiple `ilike` clauses when needed:
   ```sql
   where search_content ilike '%cable%' and search_content ilike '%copper%'
   ```
7. **Semantic search consumes 1 OpenAI API call** — prefer textual when possible for cost efficiency

## Available functions

| Function | Description |
|----------|-------------|
| `search_items_text(text, limit, category_filter, subcategory_filter)` | Semantic search by free text — generates embedding internally via Vault |
| `search_items_vector(query_embedding, limit, category_filter, subcategory_filter)` | Semantic search by vector (advanced — requires pre-generated embedding) |
| `generate_embeddings_batch(batch_limit)` | Generates embeddings for records missing them — key via Vault |

## Response format

When responding, organize information clearly:
- For item lists: present in organized format with the most relevant fields
- For prices: always include unit and any applicable tax/location info
- For comparisons: highlight differences between options
- If no results: suggest alternative search terms
- Report how many results were found vs. how many exist (if relevant)
- If semantic search was used: mention similarity scores when relevant

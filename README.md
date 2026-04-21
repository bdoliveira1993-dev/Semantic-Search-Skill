# Semantic Search Skill for Supabase + pgvector

A Claude skill that enables natural-language querying of catalogs stored in Supabase, combining textual (ilike) and semantic (vector similarity) search through the Model Context Protocol.

Extracted and generalized from a production system I built for engineering procurement workflows, where the same catalog is queried daily for pricing, supplier information, and cross-discipline material lookups.

## What it does

Users ask questions in natural language — *"show me 500 kVA transformers"*, *"compare prices for ESFR sprinklers"*, *"what do we have for fire protection?"* — and the skill decides whether to run a fast textual search or a semantic search backed by OpenAI embeddings, then returns a structured answer.

The skill orchestrates:

- **Textual search** via `ilike` on a `search_content` column — no API cost, ideal for exact matches and category listings
- **Semantic search** via pgvector with cosine similarity — handles synonyms, functional descriptions, and cross-lingual queries
- **Filter combination** on category and subcategory columns for scoped searches
- **Automatic fallback** between modes when the first attempt returns no useful results

All OpenAI API calls happen inside a Postgres function that pulls the key from Supabase Vault — the key is never exposed to the client or the LLM.

## Architecture

```
User (natural language)
    ↓
Claude (loads this skill)
    ↓
Supabase MCP → execute_sql
    ↓
Postgres function (search_items_text)
    ↓ (pulls key from Vault, calls OpenAI)
OpenAI embeddings API → 1536-dim vector
    ↓
pgvector similarity search (HNSW index)
    ↓
Ranked results → back to Claude → formatted answer
```

## Repository structure

```
.
├── SKILL.md                 # The skill itself (load into Claude)
├── README.md                # You are here
└── sql/
    ├── setup.sql            # Schema, RLS, Vault, functions, indexes
    └── example_data.sql     # 30 synthetic items across 5 categories
```

## Setup (5 minutes)

### Prerequisites

- A Supabase project (free tier is fine)
- An OpenAI API key with access to `text-embedding-3-small`
- Claude with the Supabase MCP connector enabled

### Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/<your-user>/semantic-search-skill.git
   cd semantic-search-skill
   ```

2. **Open the Supabase SQL Editor** for your project.

3. **Run `sql/setup.sql`** — this creates the `items` table, enables RLS, stores your OpenAI key in Vault, and creates all the search functions. Replace `<YOUR_OPENAI_KEY>` in the Vault section before running.

4. **(Optional) Load example data** by running `sql/example_data.sql`, then generate embeddings:
   ```sql
   SELECT generate_embeddings_batch(30);
   ```

5. **Copy `SKILL.md` to your Claude skills directory** and replace `<PROJECT_ID>` with your Supabase project ID.

6. **Test it** — ask Claude something like *"search for 500 kVA transformers"* or *"what's the cheapest fire pump?"*.

## Adapting to your domain

The example data uses engineering materials (electrical, fire protection, HVAC, plumbing, instrumentation) because that's the domain I extracted this from. The skill itself is domain-agnostic.

To adapt:

- **Keep the schema** in `setup.sql` — the required columns (`name`, `category`, `subcategory`, `supplier`, `unit`, `unit_price`, `search_content`, `embedding`) work for most catalog-shaped data
- **Add your own columns** freely — the skill only reads the ones above, extra columns are ignored
- **Update the trigger terms** in the `description` field of `SKILL.md` to match your domain vocabulary
- **Update the example queries** in `SKILL.md` to reflect your category names

Domains this would fit naturally:

- Product catalogs for e-commerce
- Internal knowledge bases (policies, SOPs, contracts)
- Parts inventories for manufacturing or repair
- Document libraries (past proposals, quotes, reports)
- Research paper collections with metadata

## Why this approach

Building this for production taught me a few things I didn't expect:

- **Semantic search is not free.** Every OpenAI call costs real money and adds latency. The skill is deliberately biased toward textual search, escalating to semantic only when the query can't be answered otherwise.
- **Vault matters more than you think.** Keeping the OpenAI key inside Postgres means no client ever sees it, no environment variable leaks it, and the key rotation is a single `UPDATE`.
- **`search_content` as a concatenated column** is dumb but effective. A full-text search setup with `tsvector` is more powerful but also more fragile — for catalogs under ~100k rows, `ilike` on a GIN-indexed text column is fine and easier to debug.
- **HNSW beats IVFFlat for this scale.** At ~3500 rows (original production size), both indexes are fast, but HNSW gave more consistent latency without needing to tune `probes`.

## License

MIT — use, fork, adapt, ship.

## Credits

Built by [Bruna de Oliveira](https://www.linkedin.com/in/bruna-oliveira-658873163). If this is useful to you or you adapt it for an interesting domain, I'd love to hear about it.

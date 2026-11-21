# OmniTrace SRE Copilot

A cost-free, end-to-end **Hybrid RAG (Retrieval-Augmented Generation)** platform that diagnoses production log failures by combining **Snowflake** data warehousing, local open-source **Hugging Face** embeddings, **PyTorch** semantic similarity search, and the **Google Gemini API**.

---

## Overview

When production incidents occur, engineers often waste valuable time scanning noisy log streams to pinpoint root causes. **OmniTrace SRE Copilot** lets you ask natural-language diagnostic questions (such as *"Why did the payment system fail?"*), retrieves the most semantically relevant logs from Snowflake, and uses Gemini to produce grounded root-cause analysis strictly tied to those logs.

Rather than relying on paid cloud AI add-ons or trial-restricted vector endpoints, the system uses a **hybrid architecture** that assigns each workload to the most cost-effective and appropriate environment:

- **Snowflake (`OMNITRACE_DB`):** Acts as the central cloud data warehouse storing parsed logs (`PARSED_LOGS`) and structured embedding records (`LOG_EMBEDDINGS_FREE`).
- **Python / Hugging Face / PyTorch (Local or Google Colab Runtime):** Generates 384-dimensional embeddings locally using `all-MiniLM-L6-v2` and runs cosine similarity search in memory without extra cloud compute or vector DB fees.
- **Google Gemini API (`google-genai` SDK):** Synthesizes retrieved log snippets into clear, grounded SRE incident diagnostics.

---

## Architecture Flow

The pipeline is split into two decoupled stages so log indexing does not have to be repeated every time you ask a question:

### 1. Ingestion & Embedding Pipeline
1. **Extract Logs:** Connects to Snowflake via Snowpark and loads `PARSED_LOGS` into a Pandas DataFrame.
2. **Generate Embeddings:** Encodes log messages locally into 384-dimensional vectors using `sentence-transformers` (`all-MiniLM-L6-v2`).
3. **Stage & Bulk Load:** Serializes embedding vectors as JSON strings, writes them to a temporary staging table (`TEMP_EMBEDDING_STAGE`) via `session.write_pandas()`, bulk-inserts into `LOG_EMBEDDINGS_FREE` using server-side `PARSE_JSON()`, and drops the temporary staging table.

### 2. Retrieval & Root-Cause Analysis Pipeline
1. **Load Indexed Logs:** Pulls log messages and stored embeddings from `LOG_EMBEDDINGS_FREE`.
2. **Encode User Query:** Converts the incoming SRE question into a 384-dimensional tensor locally.
3. **Rank Relevant Logs:** Computes cosine similarity (`util.cos_sim`) and selects the top-$K$ closest matching log messages (`torch.topk`).
4. **Grounded LLM Diagnosis:** Sends a structured prompt containing only the retrieved log context and user query to Gemini via the `google.genai` client.

---

## Key Engineering Trade-Offs & Solutions

- **Hybrid Split vs. All-in-One Cloud AI:** Offloading embedding generation and similarity matching to a local/Colab Python runtime avoids paid warehouse credits and trial feature gates while keeping Snowflake focused on structured storage and SQL operations.
- **Staging Table + `PARSE_JSON` vs. Inline SQL `INSERT`:** Embedding 384-float arrays directly inside inline `PARSE_JSON('[...]')` SQL statements can hit SQL literal/compilation size limits. Staging via `write_pandas` and parsing server-side scales cleanly and avoids oversized query strings.
- **Decoupled Indexing vs. Querying:** Separating embedding generation from query execution lets you query logs repeatedly at low latency and only re-run ingestion when new logs arrive.
- **Modern `google.genai` SDK & Grounded Prompting:** Uses the current `google.genai` client and instructs the model to analyze issues using *only* the retrieved log context to minimize hallucinations.
- **Identifier & Credential Hygiene:** Email-based Snowflake usernames containing `@` are quoted in SQL identifiers when needed, and sensitive credentials/API keys are kept out of source code via environment variables.

---

## Project Structure

omnitrace-sre-copilot/
├── README.md
├── requirements.txt
├── .env.example
├── .gitignore
├── sql/
│   └── 01_create_tables.sql
└── src/
    ├── ingest_embeddings.py
    └── query_copilot.py
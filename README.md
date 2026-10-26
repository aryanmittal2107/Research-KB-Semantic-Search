# Research KB — Research Paper Knowledge Base

Research KB is a PostgreSQL-based knowledge base designed to organize research papers and their related information in one structured database. It stores paper metadata, authors, topic tags, citation relationships, text chunks, and vector embeddings. The database design supports structured querying and provides the foundation for similarity-based retrieval using PostgreSQL and pgvector.

## Technology Stack

- **PostgreSQL 17** — relational database for storing and querying research-paper data.
- **pgvector** — PostgreSQL extension for storing vector embeddings and performing similarity queries.
- **SQL** — schema definition, constraints, joins, views, indexes, functions, procedures, and triggers.
- **psql** — command-line client used to connect to and manage the database.
- **WSL Ubuntu + Windows PostgreSQL** — development environment used to access the local PostgreSQL server.

## Features

### 1. Research Paper Management
The `papers` table stores the main information for each research paper, including its title, abstract, publication year, DOI, file path, uploader reference, and timestamps. This allows paper records to be queried and maintained centrally.

### 2. User and Uploader Records
The `users` table stores user/uploader information. Paper records can reference the user who added them, helping associate uploaded or maintained papers with their source.

### 3. Author Management and Relationships
The `authors` table stores author information. The `paper_authors` junction table connects papers with authors and preserves author order. This supports papers with multiple authors and authors associated with multiple papers.

### 4. Topic Tags
The `tags` table stores topic labels, while `paper_tags` connects tags to papers. This many-to-many relationship allows a paper to have multiple research topics and a topic to be associated with multiple papers.

### 5. Citation Relationships
The `paper_citations` table records relationships between citing and cited papers and can store citation context. The `citation_network` view exposes citation links together with paper information for easier inspection.

### 6. Text Chunk Storage
The `paper_chunks` table stores portions of paper text, with fields for the paper reference and chunk number. Splitting text into chunks provides a data structure that can later support retrieval of relevant passages instead of returning only an entire paper record.

### 7. Vector Embedding Storage and Similarity Queries
The `paper_chunks.embedding` column uses the pgvector type `vector(1536)`. PostgreSQL can compare stored vectors using pgvector operators, including `<=>` for cosine distance. An HNSW vector index is included to support efficient vector similarity retrieval.

The current setup uses demo vectors to test vector storage and similarity-query mechanics. These demo vectors are not meaningful text embeddings, so they do not provide semantic understanding of the paper content.

### 8. Views for Joined Information
- **`paper_details`** — presents paper information together with uploader information, reducing the need to write the same join repeatedly.
- **`citation_network`** — presents citation relationships along with paper titles for inspection.

### 9. Timestamp Maintenance
The `update_paper_timestamp()` function and `trg_update_paper_timestamp` trigger update the paper's `updated_at` value when a paper record is updated. This helps track when paper metadata was last modified.

### 10. Database Functions, Procedures, and Audit Logging
Additional routines and audit objects were tested in the development database, including `count_paper_chunks()`, `count_paper_citations()`, `add_paper`, `delete_paper`, and a `paper_audit` table/trigger for recording paper changes. Their availability can vary by database setup because not all of these objects were included in the committed setup SQL. Check the live database using the inspection commands below before relying on them in a fresh installation.

## Database Schema

| Table / Object | Purpose |
|---|---|
| `users` | Stores user/uploader records. |
| `papers` | Stores paper metadata, abstract, DOI, publication year, file path, uploader reference, and timestamps. |
| `authors` | Stores author details. |
| `paper_authors` | Links papers and authors, including author order. |
| `tags` | Stores research-topic labels. |
| `paper_tags` | Links papers and tags. |
| `paper_citations` | Stores citing/cited paper relationships and citation context. |
| `paper_chunks` | Stores paper text chunks and vector embeddings. |
| `paper_details` | View joining paper details with uploader information. |
| `citation_network` | View showing citation links and paper titles. |
| HNSW vector index | Supports efficient vector similarity retrieval. |
| `update_paper_timestamp()` | Sets `updated_at` when a paper is updated. |
| `trg_update_paper_timestamp` | Calls the timestamp function before updates to `papers`. |

The setup SQL includes sample records for database testing. File paths stored in sample rows are metadata examples; the SQL script does not automatically include the corresponding PDF files.

## Connect to the Existing Database

These commands are for the development setup where PostgreSQL 17 runs on Windows and is accessed from WSL Ubuntu.

```bash
cd "/mnt/c/Program Files/PostgreSQL/17/bin"
./psql.exe -U postgres -h localhost -p 5432 -d research_kb
```

Enter the PostgreSQL password when prompted. A successful connection displays a prompt similar to:

```text
research_kb=#
```

### If the connection fails

Run these commands in **Windows PowerShell** to check the PostgreSQL service:

```powershell
Get-Service postgresql-x64-17
```

If it is stopped, open PowerShell as administrator if required and run:

```powershell
Start-Service postgresql-x64-17
```

Then retry the WSL connection commands.

## Database Inspection and Query Commands

Run the following commands after connecting and seeing the `research_kb=#` prompt. The commands beginning with a backslash are `psql` meta-commands; the others are SQL queries.

### Check the database and pgvector

```sql
SELECT current_database();
SELECT version();

SELECT extname, extversion
FROM pg_extension
WHERE extname = 'vector';
```

### List database objects

```text
\dt
\dv
\di
\df
\dx
```

- `\dt` lists tables.
- `\dv` lists views.
- `\di` lists indexes.
- `\df` lists functions.
- `\dx` lists installed extensions.

### Inspect the table definitions

```text
\d users
\d papers
\d authors
\d paper_authors
\d tags
\d paper_tags
\d paper_citations
\d paper_chunks
```

### Query paper records

```sql
SELECT paper_id, title, abstract, publication_year, doi
FROM papers
ORDER BY paper_id;
```

### Query stored text chunks

```sql
SELECT chunk_id, paper_id, chunk_number, content
FROM paper_chunks
ORDER BY paper_id, chunk_number;
```

### Query the views

```sql
SELECT * FROM paper_details;
SELECT * FROM citation_network;
```

### Run a vector similarity query

This query compares each stored chunk vector with the vector for `chunk_id = 1`, then orders results by cosine distance. A lower distance means the vectors are closer according to the vector representation.

```sql
SELECT
    chunk_id,
    paper_id,
    chunk_number,
    content,
    embedding <=> (
        SELECT embedding
        FROM paper_chunks
        WHERE chunk_id = 1
    ) AS cosine_distance
FROM paper_chunks
WHERE embedding IS NOT NULL
ORDER BY cosine_distance
LIMIT 5;
```

Because the current vectors are demo vectors, the result demonstrates how similarity queries work, not meaningful semantic relevance.

### Inspect functions and procedures

```sql
SELECT
    n.nspname AS schema_name,
    p.proname AS routine_name,
    CASE p.prokind
        WHEN 'p' THEN 'PROCEDURE'
        WHEN 'f' THEN 'FUNCTION'
        ELSE p.prokind::text
    END AS routine_type,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_function_result(p.oid) AS result_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
ORDER BY routine_type, routine_name;
```

### Inspect triggers

```sql
SELECT
    event_object_table AS table_name,
    trigger_name,
    action_timing,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name, event_manipulation;
```

### Check audit tables

```text
\dt *audit*
```

### Exit psql

```text
\q
```

## Setup from Scratch

Use this section only for a new or empty development environment. To access the existing database, use the connection commands above instead. Review the SQL setup file before running it and do not recreate a database that contains data you need.

The setup script uses `psql` meta-commands such as `\gexec` and `\connect`, so run it through `psql` rather than pasting the entire file into a generic SQL editor. The PostgreSQL server must have pgvector installed.

From the project folder in WSL, locate the setup script:

```bash
cd "/mnt/c/Users/aryan/Downloads/Research Paper Internal Knowledge Base Search"
find . -type f -name "research_kb_setup_clean.sql"
```

If the script is at `sql/research_kb_setup_clean.sql`, run:

```bash
SQL_FILE_WIN="$(wslpath -w "$PWD/sql/research_kb_setup_clean.sql")"
"/mnt/c/Program Files/PostgreSQL/17/bin/psql.exe" \
  -U postgres -h localhost -p 5432 -d postgres \
  -v ON_ERROR_STOP=1 -f "$SQL_FILE_WIN"
```

If `find` reports that the file is nested inside `Research Paper Internal Knowledge Base Search/`, use:

```bash
SQL_FILE_WIN="$(wslpath -w "$PWD/Research Paper Internal Knowledge Base Search/research_kb_setup_clean.sql")"
"/mnt/c/Program Files/PostgreSQL/17/bin/psql.exe" \
  -U postgres -h localhost -p 5432 -d postgres \
  -v ON_ERROR_STOP=1 -f "$SQL_FILE_WIN"
```

Use only the command that matches the path returned by `find`. The setup script is intended to run from the `postgres` maintenance database and conditionally creates/connects to `research_kb`.

## Repository

GitHub: [Research KB — Research Paper Internal Knowledge Base Search](https://github.com/aryanmittal2107/Research-KB-Semantic-Search)

The repository includes the database setup SQL and schema documentation. The documented implementation is currently the database foundation; a complete web frontend/backend and an end-to-end real embedding-generation pipeline are not included in the database setup.

## Git Workflow

Run these commands from the local project repository folder to inspect its status:

```bash
cd "/mnt/c/Users/aryan/Downloads/Research Paper Internal Knowledge Base Search"
git status
git remote -v
git branch --show-current
git log --oneline -5
```

Review changes before committing:

```bash
git diff
git status
```

Stage the intended project files and inspect the staged changes:

```bash
git add README.md sql/ docs/
git diff --cached
git status
```

Commit and push:

```bash
git commit -m "Update Research KB README and documentation"
git push
```

GitHub does not accept a normal account password for HTTPS Git operations. Use a supported credential manager, GitHub CLI, personal access token, or SSH authentication. Do not commit passwords, tokens, private SSH keys, `.env` files, or database dumps.

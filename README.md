# Research KB — Research Paper Knowledge Base

Research KB is a PostgreSQL-based knowledge base for organizing research papers and their associated metadata in a structured database. It stores paper records, users/uploaders, authors, topic tags, citation relationships, text chunks, and vector embeddings. It also includes SQL views for joined information, indexes for query performance and vector retrieval, helper functions, stored procedures, automatic timestamp maintenance, and audit logging for paper changes.

## Technology Stack

- **PostgreSQL 17** — relational database engine.
- **pgvector** — PostgreSQL extension for storing vectors and calculating vector distances.
- **SQL and PL/pgSQL** — schema, constraints, views, indexes, functions, procedures, and triggers.
- **psql** — PostgreSQL command-line client.
- **WSL Ubuntu + Windows PostgreSQL** — local development environment.

## Features

### 1. Research paper management
The `papers` table stores a paper's title, abstract, publication year, DOI, file path, uploader reference, and timestamps. The title is required, publication years are constrained to be at least 1900, and DOI values must be unique when provided.

### 2. Users and uploaders
The `users` table stores user names and unique email addresses. `papers.uploaded_by` references the uploader. If a user is deleted, the paper remains but its `uploaded_by` value becomes `NULL`.

### 3. Author management and author order
The `authors` table stores names, affiliations, and optional unique email addresses. The `paper_authors` junction table implements a many-to-many relationship between papers and authors and stores author order.

### 4. Research-topic tags
The `tags` table stores unique topic labels. The `paper_tags` junction table allows each paper to have multiple tags and each tag to be attached to multiple papers.

### 5. Citation relationships
The `paper_citations` table stores the citing paper, cited paper, optional citation context, and creation time. Foreign keys maintain valid references, cascading deletes remove citation relationships for deleted papers, and a constraint prevents self-citations.

### 6. Text chunks
The `paper_chunks` table stores text passages, a chunk number, a parent paper reference, and a creation timestamp. The `(paper_id, chunk_number)` pair is unique.

### 7. Vector storage and similarity queries
`paper_chunks.embedding` is defined as `vector(1536)`. The pgvector `<=>` operator calculates cosine distance, and an HNSW index using `vector_cosine_ops` is created for vector similarity retrieval. The setup assigns random demo vectors to illustrate vector storage and query mechanics. These random vectors do **not** represent the meaning of the text and do not establish meaningful semantic-search quality.

### 8. Views
- `paper_details` combines paper metadata with uploader information.
- `citation_network` displays citing/cited paper IDs and titles, plus citation context.

### 9. Automatic update timestamps
`update_paper_timestamp()` sets `papers.updated_at` before a paper update. The setup removes the redundant `trg_papers_updated_at` trigger and keeps `trg_update_paper_timestamp`.

### 10. Audit logging
`paper_audit` stores the paper ID, operation (`INSERT`, `UPDATE`, or `DELETE`), old title, new title, and change timestamp. `audit_paper_changes()` is invoked by `trg_audit_paper_changes` after changes to `papers`. The audit record remains when the corresponding paper is deleted.

### 11. Helper functions
- `count_paper_chunks(p_paper_id)` returns the number of chunks belonging to a paper.
- `count_paper_citations(p_paper_id)` counts citation relationships in which the paper is either the citing or cited paper.

### 12. Stored procedures
- `add_paper(...)` adds a paper and raises an exception if the title is null or blank.
- `delete_paper(p_paper_id)` deletes a paper and raises an exception if that ID does not exist. Foreign-key cascade rules remove dependent chunks, author links, tag links, and citation links.

## Database Schema

| Table / object | Purpose |
|---|---|
| `users` | User/uploader records |
| `papers` | Paper metadata, uploader reference, and timestamps |
| `authors` | Author details |
| `paper_authors` | Paper-author mapping and author order |
| `tags` | Research-topic labels |
| `paper_tags` | Paper-tag mapping |
| `paper_citations` | Citation relationships and context |
| `paper_chunks` | Text chunks and vector embeddings |
| `paper_audit` | Audit history for paper insert/update/delete events |
| `paper_details` | Paper information joined with uploader information |
| `citation_network` | Citation relationships with paper titles |
| `idx_paper_chunks_embedding_hnsw` | HNSW index for cosine-distance vector retrieval |
| `idx_paper_chunks_paper_id` | Index for locating chunks by paper |
| `update_paper_timestamp()` | Timestamp trigger function |
| `audit_paper_changes()` | Audit trigger function |
| `count_paper_chunks()` | Counts chunks for a paper |
| `count_paper_citations()` | Counts citation relationships involving a paper |
| `add_paper(...)` | Stored procedure for inserting a paper |
| `delete_paper(...)` | Stored procedure for deleting a paper |

## 1. Connect to the Existing Database

The current development environment runs PostgreSQL 17 on Windows and connects from WSL Ubuntu.

```bash
cd "/mnt/c/Program Files/PostgreSQL/17/bin"
./psql.exe -U postgres -h localhost -p 5432 -d research_kb
```

Enter the PostgreSQL password when prompted. A successful connection shows a prompt similar to:

```text
research_kb=#
```

### If the connection fails

Run these commands in Windows PowerShell:

```powershell
Get-Service postgresql-x64-17
```

If the service is stopped, start PowerShell as administrator if required, then run:

```powershell
Start-Service postgresql-x64-17
```

Retry the WSL connection command afterward.

## 2. psql Navigation and Inspection Commands

Run these commands after connecting to `research_kb`.

```text
\conninfo
```
Shows connection details.

```text
\l
```
Lists databases.

```text
\dt
```
Lists tables.

```text
\dt *audit*
```
Lists tables with `audit` in their names.

```text
\dv
```
Lists views.

```text
\di
```
Lists indexes.

```text
\df
```
Lists functions.

```text
\df+ audit_paper_changes
```
Shows details about the audit trigger function.

```text
\dp
```
Lists table and view access privileges.

```text
\dx
```
Lists installed extensions.

```text
\d users
\d papers
\d authors
\d paper_authors
\d tags
\d paper_tags
\d paper_citations
\d paper_chunks
\d paper_audit
```
Shows table structures, columns, and constraints.

```text
\d+ paper_chunks
```
Shows extended information about the chunks table.

```text
\du
```
Lists database roles.

```text
\timing on
```
Displays query execution time.

```text
\x on
```
Enables expanded output, useful for wide rows. Use `\x off` to disable it.

```text
\q
```
Exits `psql`.

## 3. Check the Database and pgvector

```sql
SELECT current_database();
SELECT current_user;
SELECT version();

SELECT extname, extversion
FROM pg_extension
WHERE extname = 'vector';
```

List all public tables and their approximate row counts (the counts are planner statistics, not exact counts):

```sql
SELECT
    schemaname,
    relname AS table_name,
    n_live_tup AS estimated_rows
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY relname;
```

For exact counts of important tables:

```sql
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL
SELECT 'papers', COUNT(*) FROM papers
UNION ALL
SELECT 'authors', COUNT(*) FROM authors
UNION ALL
SELECT 'paper_authors', COUNT(*) FROM paper_authors
UNION ALL
SELECT 'tags', COUNT(*) FROM tags
UNION ALL
SELECT 'paper_tags', COUNT(*) FROM paper_tags
UNION ALL
SELECT 'paper_citations', COUNT(*) FROM paper_citations
UNION ALL
SELECT 'paper_chunks', COUNT(*) FROM paper_chunks
UNION ALL
SELECT 'paper_audit', COUNT(*) FROM paper_audit
ORDER BY table_name;
```

## 4. Query Paper Records

List all papers:

```sql
SELECT paper_id, title, publication_year, doi, uploaded_by,
       created_at, updated_at
FROM papers
ORDER BY paper_id;
```

Search by title:

```sql
SELECT paper_id, title, abstract
FROM papers
WHERE title ILIKE '%deep learning%'
ORDER BY title;
```

Search title and abstract:

```sql
SELECT paper_id, title, publication_year
FROM papers
WHERE title ILIKE '%machine learning%'
   OR abstract ILIKE '%machine learning%'
ORDER BY publication_year;
```

Filter by publication year:

```sql
SELECT paper_id, title, publication_year
FROM papers
WHERE publication_year >= 2018
ORDER BY publication_year DESC;
```

Find papers with a DOI:

```sql
SELECT paper_id, title, doi
FROM papers
WHERE doi IS NOT NULL
ORDER BY title;
```

Find papers with no uploader assigned:

```sql
SELECT paper_id, title
FROM papers
WHERE uploaded_by IS NULL;
```

## 5. Query Users, Authors, and Tags

List users:

```sql
SELECT user_id, name, email, created_at
FROM users
ORDER BY user_id;
```

List authors:

```sql
SELECT author_id, name, affiliation, email
FROM authors
ORDER BY name;
```

Show papers with their authors and author order:

```sql
SELECT p.paper_id, p.title, a.name AS author, pa.author_order
FROM papers p
JOIN paper_authors pa ON pa.paper_id = p.paper_id
JOIN authors a ON a.author_id = pa.author_id
ORDER BY p.paper_id, pa.author_order;
```

List tags:

```sql
SELECT tag_id, tag_name
FROM tags
ORDER BY tag_name;
```

Show each paper and its tags:

```sql
SELECT p.paper_id, p.title, t.tag_name
FROM papers p
JOIN paper_tags pt ON pt.paper_id = p.paper_id
JOIN tags t ON t.tag_id = pt.tag_id
ORDER BY p.paper_id, t.tag_name;
```

Find papers with a particular tag:

```sql
SELECT p.paper_id, p.title
FROM papers p
JOIN paper_tags pt ON pt.paper_id = p.paper_id
JOIN tags t ON t.tag_id = pt.tag_id
WHERE t.tag_name = 'Semantic Search'
ORDER BY p.title;
```

## 6. Query Citation Relationships

List all citation edges:

```sql
SELECT
    pc.citing_paper_id,
    citing.title AS citing_paper,
    pc.cited_paper_id,
    cited.title AS cited_paper,
    pc.citation_context
FROM paper_citations pc
JOIN papers citing ON citing.paper_id = pc.citing_paper_id
JOIN papers cited ON cited.paper_id = pc.cited_paper_id
ORDER BY pc.citing_paper_id, pc.cited_paper_id;
```

Find papers that cite paper ID 1:

```sql
SELECT citing.paper_id, citing.title
FROM paper_citations pc
JOIN papers citing ON citing.paper_id = pc.citing_paper_id
WHERE pc.cited_paper_id = 1
ORDER BY citing.title;
```

Find papers cited by paper ID 2:

```sql
SELECT cited.paper_id, cited.title
FROM paper_citations pc
JOIN papers cited ON cited.paper_id = pc.cited_paper_id
WHERE pc.citing_paper_id = 2
ORDER BY cited.title;
```

Count citations for each paper (incoming and outgoing relationships combined):

```sql
SELECT
    p.paper_id,
    p.title,
    COUNT(pc.citing_paper_id) AS total_related_citations
FROM papers p
LEFT JOIN paper_citations pc
    ON pc.citing_paper_id = p.paper_id
    OR pc.cited_paper_id = p.paper_id
GROUP BY p.paper_id, p.title
ORDER BY total_related_citations DESC, p.paper_id;
```

## 7. Query Text Chunks and Views

List all chunks:

```sql
SELECT chunk_id, paper_id, chunk_number, content, created_at
FROM paper_chunks
ORDER BY paper_id, chunk_number;
```

Find chunks for one paper:

```sql
SELECT chunk_number, content
FROM paper_chunks
WHERE paper_id = 1
ORDER BY chunk_number;
```

View the joined paper details:

```sql
SELECT *
FROM paper_details
ORDER BY paper_id;
```

View citation network:

```sql
SELECT *
FROM citation_network
ORDER BY citing_paper_id, cited_paper_id;
```

Inspect the SQL used to define a view:

```text
\d+ paper_details
\d+ citation_network
```

## 8. Vector Similarity and Index Inspection

Check which chunks have embeddings:

```sql
SELECT
    COUNT(*) AS total_chunks,
    COUNT(embedding) AS chunks_with_embeddings,
    COUNT(*) - COUNT(embedding) AS chunks_without_embeddings
FROM paper_chunks;
```

Compare stored vectors with the vector for chunk ID 1 using cosine distance:

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

Inspect indexes on `paper_chunks`:

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'paper_chunks'
ORDER BY indexname;
```

Ask PostgreSQL for the query plan:

```sql
EXPLAIN
SELECT chunk_id, paper_id
FROM paper_chunks
WHERE paper_id = 1;
```

For actual execution timing and row counts:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT chunk_id, paper_id
FROM paper_chunks
WHERE paper_id = 1;
```

`EXPLAIN ANALYZE` executes the query. Use it with read-only queries for inspection.

**Vector limitation:** the setup uses random demonstration vectors. Similarity ranking demonstrates pgvector mechanics only; meaningful semantic search requires real embeddings generated from paper text and queries with the same embedding model and matching dimensions.

## 9. Helper Function Commands

Count chunks for paper ID 1:

```sql
SELECT count_paper_chunks(1);
```

Count citation relationships involving paper ID 1:

```sql
SELECT count_paper_citations(1);
```

Show these counts for every paper:

```sql
SELECT
    paper_id,
    title,
    count_paper_chunks(paper_id) AS chunk_count,
    count_paper_citations(paper_id) AS citation_relationship_count
FROM papers
ORDER BY paper_id;
```

Inspect function definitions:

```sql
SELECT
    p.proname AS routine_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_function_result(p.oid) AS result_type,
    pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
ORDER BY p.proname;
```

## 10. Stored Procedure Commands

The following examples modify data. Use a clearly identifiable test paper and remove it after testing.

### Add a paper

```sql
CALL add_paper(
    'Research KB Procedure Demo',
    'Temporary record created to test the add_paper procedure.',
    2026,
    '10.5555/researchkb-demo-2026',
    'papers/research_kb_procedure_demo.pdf',
    NULL
);
```

Check whether it was inserted:

```sql
SELECT paper_id, title, publication_year, doi
FROM papers
WHERE title = 'Research KB Procedure Demo';
```

The DOI must be unique. If that DOI is already in use, choose a different test DOI.

### Delete a test paper using the procedure

First identify the ID:

```sql
SELECT paper_id, title
FROM papers
WHERE title = 'Research KB Procedure Demo';
```

Then pass the returned ID to the procedure. Example only, if the ID is 99:

```sql
CALL delete_paper(99);
```

Do not use `99` unless it is actually the ID of the temporary test record. The procedure raises an exception if the paper ID does not exist.

## 11. Safe INSERT, UPDATE, and DELETE Demonstration

The audit trigger records paper changes. For a controlled test, use a temporary record and remove it afterward.

Insert:

```sql
INSERT INTO papers (title, abstract, publication_year)
VALUES ('Research KB Audit Demo', 'Temporary audit test record', 2026)
RETURNING paper_id, title, created_at, updated_at;
```

Record the returned `paper_id`. Update using that ID (replace `7` with the ID returned by your insert):

```sql
UPDATE papers
SET title = 'Research KB Audit Demo Updated'
WHERE paper_id = 7
RETURNING paper_id, title, updated_at;
```

Check the audit trail:

```sql
SELECT audit_id, paper_id, action_type, old_title, new_title, changed_at
FROM paper_audit
WHERE paper_id = 7
ORDER BY audit_id;
```

Delete the temporary record (replace `7` with the correct test ID):

```sql
DELETE FROM papers
WHERE paper_id = 7;
```

Confirm the audit history remains:

```sql
SELECT audit_id, paper_id, action_type, old_title, new_title, changed_at
FROM paper_audit
WHERE paper_id = 7
ORDER BY audit_id;
```

**Important:** replace the example ID `7` with the ID returned by your own insert. Do not run these modification commands against an existing paper.

## 12. Audit and Trigger Inspection

List the latest audit records:

```sql
SELECT audit_id, paper_id, action_type, old_title, new_title, changed_at
FROM paper_audit
ORDER BY audit_id DESC
LIMIT 20;
```

Count audit events by action:

```sql
SELECT action_type, COUNT(*) AS event_count
FROM paper_audit
GROUP BY action_type
ORDER BY action_type;
```

List triggers on `papers`:

```sql
SELECT
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND event_object_table = 'papers'
ORDER BY trigger_name, event_manipulation;
```

Show trigger definitions and the functions they call:

```sql
SELECT
    t.tgname AS trigger_name,
    pg_get_triggerdef(t.oid) AS trigger_definition,
    p.proname AS function_name
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE n.nspname = 'public'
  AND c.relname = 'papers'
  AND NOT t.tgisinternal
ORDER BY t.tgname;
```

Expected design: one `BEFORE UPDATE` timestamp trigger and one audit trigger configured for `AFTER INSERT`, `AFTER UPDATE`, and `AFTER DELETE`.

## 13. Inspect All Functions and Procedures

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

Show stored procedure definitions:

```sql
SELECT
    p.proname AS procedure_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'p'
ORDER BY p.proname;
```

## 14. Transaction Commands

Transactions allow a group of SQL operations to be committed together or rolled back.

```sql
BEGIN;

SELECT COUNT(*) FROM papers;

ROLLBACK;
```

`ROLLBACK` discards changes made in the current transaction. For a real insert/update/delete that should be retained, use `COMMIT` instead of `ROLLBACK`. Audit records created by a trigger are part of the same transaction as the paper change, so they are also rolled back if that transaction is rolled back.

## 15. Setup from Scratch

Use this only for a new or disposable development environment. The script creates the database if needed, connects to it, creates schema objects, inserts sample records, creates indexes/views/triggers/functions/procedures, and runs verification queries. It uses `psql` meta-commands such as `\gexec` and `\connect`; therefore, run it using `psql`, not by pasting the entire file into a generic SQL editor.

Find the setup file from the WSL project folder:

```bash
cd "/mnt/c/Users/aryan/Downloads/Research Paper Internal Knowledge Base Search"
find . -type f -name "Research_KB_Updated_Setup_With_Audit.sql"
```

If the file is in the current folder, run:

```bash
SQL_FILE_WIN="$(wslpath -w "$PWD/Research_KB_Updated_Setup_With_Audit.sql")"
"/mnt/c/Program Files/PostgreSQL/17/bin/psql.exe" \
  -U postgres -h localhost -p 5432 -d postgres \
  -v ON_ERROR_STOP=1 -f "$SQL_FILE_WIN"
```

Adjust the file path if `find` reports a different location. The server must have pgvector installed.

**Do not run the complete setup script on the existing database without reviewing and backing up important data first.** It includes sample data and demo embeddings; it is not a dedicated incremental migration script.

## 16. Git and GitHub Commands

From the local project repository root:

```bash
git status
git remote -v
git branch --show-current
git log --oneline -10
```

Review changes:

```bash
git diff
git diff -- README.md
git diff -- sql/
```

Stage intended files and review the staged changes:

```bash
git add README.md sql/ docs/
git diff --cached
git status
```

Commit and push:

```bash
git commit -m "Expand Research KB documentation and SQL commands"
git push
```

GitHub does not accept a normal account password for HTTPS Git operations. Use an approved credential manager, GitHub CLI, personal access token, or SSH authentication. Never commit passwords, tokens, private SSH keys, `.env` files, or database dumps.

## Repository

GitHub: [Research KB — Research Paper Internal Knowledge Base Search](https://github.com/aryanmittal2107/Research-KB-Semantic-Search)

The current repository documents the PostgreSQL database foundation. A complete web frontend/backend and a real end-to-end embedding-generation pipeline are not included in the SQL setup. The vector examples currently use random demo embeddings rather than semantically meaningful vectors.

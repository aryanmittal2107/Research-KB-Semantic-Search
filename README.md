# Research KB — Internal Setup & Command Reference

> Internal team reference. This file focuses on setup, execution, verification, and troubleshooting; it is not the Phase 2 submission report.

## 1. Repository and working environment

Repository: `https://github.com/aryanmittal2107/Research-KB-Semantic-Search`

Run Linux commands in **Ubuntu WSL**. Run Windows Credential Manager steps from Windows if GitHub authentication fails.

```bash
cd ~/Research-KB-Semantic-Search
pwd
find . -maxdepth 3 -type f ! -path './.git/*' ! -path './.venv/*' | sort
cat README.md
```

If the repository has not been cloned into WSL:

```bash
cd ~
git clone https://github.com/aryanmittal2107/Research-KB-Semantic-Search.git
cd Research-KB-Semantic-Search
```

If the remote repository is missing the latest local files because a push was rejected, do not assume a fresh clone contains the full teammate implementation. Compare the repository contents with the local project copy first.

## 2. Identify the actual run instructions

Inspect the project files before installing dependencies. Use the matching section below only if that file exists.

```bash
ls -la
find . -maxdepth 2 -type f | sort
```

### If `requirements.txt` exists

```bash
python3 --version
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Exit the virtual environment when finished:

```bash
deactivate
```

### If `pyproject.toml` exists

Read its project instructions first:

```bash
sed -n '1,240p' pyproject.toml
```

Install commands depend on the build tool and project configuration. Do not run both the `requirements.txt` and `pyproject.toml` workflows blindly.

### If a `.env.example` exists

```bash
cat .env.example
```

Copy it to `.env` only if the README or application expects it:

```bash
cp .env.example .env
nano .env
```

Fill in local values. Do not commit `.env`, database passwords, API keys, or tokens.

## 3. PostgreSQL and pgvector checks

Check the installed client and server versions:

```bash
psql --version
pg_config --version
```

Check whether PostgreSQL is available in WSL (service commands depend on how it was installed):

```bash
sudo service postgresql status
sudo service postgresql start
```

Connect to PostgreSQL as the local administrative role if that role exists:

```bash
sudo -u postgres psql
```

Inside `psql`, inspect databases and roles:

```sql
\l
\du
\q
```

If the database has not been created, create it only after confirming the setup SQL's expected database name and permissions. The known project database name used during development was `research_kb`.

```bash
sudo -u postgres createdb research_kb
```

If it already exists, this command will report that; do not drop the database just to rerun setup.

Check pgvector availability inside the target database:

```bash
sudo -u postgres psql -d research_kb -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';"
```

If the extension is not installed in the database, inspect the setup SQL and confirm the OS package/version before enabling it. The SQL commonly includes `CREATE EXTENSION IF NOT EXISTS vector;`; use the project's own setup script as the source of truth.

## 4. Inspect and run the SQL setup

The original SQL file in the repository was:

```text
sql/research_kb_setup_clean.sql
```

Inspect the beginning of the script before execution:

```bash
sed -n '1,240p' sql/research_kb_setup_clean.sql
```

Run the script against the intended database (the `-v ON_ERROR_STOP=1` option stops at the first SQL error):

```bash
sudo -u postgres psql -v ON_ERROR_STOP=1 -d research_kb -f sql/research_kb_setup_clean.sql
```

If the script expects a different role or database, follow the script and README rather than forcing this command. Avoid rerunning destructive statements against a database containing data you need to keep.

Connect to the database:

```bash
sudo -u postgres psql -d research_kb
```

Useful `psql` commands:

```sql
\dt                 -- list tables
\dv                 -- list views
\df                 -- list functions
\df+ *count*        -- inspect count-related functions
\df+ *paper*        -- inspect paper-related functions
\dp                 -- inspect table privileges
\dx                 -- list installed extensions
\q                  -- quit
```

## 5. Verify the Phase 2 database routines

### List routine signatures

Procedure signatures may differ between versions of the SQL, so inspect the actual argument list before calling a procedure.

```sql
SELECT n.nspname AS schema_name,
       p.proname AS routine_name,
       CASE p.prokind WHEN 'p' THEN 'PROCEDURE'
                      WHEN 'f' THEN 'FUNCTION'
                      ELSE p.prokind::text END AS routine_type,
       pg_get_function_identity_arguments(p.oid) AS arguments,
       pg_get_function_result(p.oid) AS result_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND p.proname IN (
      'add_paper',
      'delete_paper',
      'count_paper_chunks',
      'count_paper_citations',
      'update_paper_timestamp',
      'audit_paper_changes'
  )
ORDER BY routine_type, routine_name;
```

### Call the count functions

Replace `1` with a valid `paper_id` from your database:

```sql
SELECT count_paper_chunks(1);
SELECT count_paper_citations(1);
```

Inspect paper IDs first:

```sql
SELECT paper_id, title
FROM papers
ORDER BY paper_id;
```

### Inspect audit rows

First inspect the audit table's exact name and columns:

```sql
\dt *audit*
```

Then query it using the table name shown by `\dt`, for example:

```sql
SELECT * FROM paper_audit ORDER BY 1 DESC LIMIT 20;
```

If the audit table has a timestamp column, order by that column instead of `1`. Check its actual schema before assuming column names:

```sql
\d paper_audit
```

### Inspect triggers

```sql
SELECT event_object_table AS table_name,
       trigger_name,
       action_timing,
       event_manipulation,
       action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name, event_manipulation;
```

If more than one trigger updates the same timestamp on the same table/event, inspect the definitions before removing or changing anything:

```sql
SELECT pg_get_triggerdef(t.oid)
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE NOT t.tgisinternal
  AND n.nspname = 'public'
ORDER BY c.relname, t.tgname;
```

### Safely test insert/update/delete and auditing

Use a disposable test record and the procedure's real signature from the routine listing above. Do not guess arguments or reuse an existing paper ID. Record the test ID, verify the audit entries after each operation, and delete the test record only after confirming its dependencies. Audit rows should be checked separately because they may intentionally remain after a paper is deleted.

## 6. Embeddings and semantic search

The database schema previously documented a `vector(1536)` embedding column and an HNSW cosine-distance index. A vector query requires the query vector to have the same dimensionality as the stored vectors.

The earlier SQL snapshot generated random demo vectors. These can test vector syntax/indexing, but they do **not** represent text meaning. For semantic search to be meaningful:
1. Generate embeddings from each content chunk using the configured embedding model.
2. Store those embeddings in `paper_chunks.embedding`.
3. Generate the query embedding with the same model.
4. Run nearest-neighbour search using the project's SQL/application implementation.

Before changing the model or schema, inspect the teammate's current implementation and verify the model's output dimension against the actual column definition. Do not change `vector(1536)` to another size unless the whole ingestion and query pipeline uses that same size.

Inspect the current column type:

```sql
SELECT table_name, column_name, data_type, udt_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'paper_chunks'
  AND column_name = 'embedding';
```

## 7. Git commands

Check working tree and remote:

```bash
git status
git remote -v
git branch --show-current
git log --oneline -5
```

After editing or adding files:

```bash
git add README.md README_REFERENCE.md docs/Research_KB_Phase_2_Submission.pdf
git status
git commit -m "Add Phase 2 submission report and setup reference"
git push -u origin main
```

If Git reports `nothing to commit`, do not create another commit unnecessarily.

### GitHub 403: permission denied

A message such as `Permission to aryanmittal2107/Research-KB-Semantic-Search.git denied to aniketrj45` means Git is authenticating as `aniketrj45` and that account does not currently have write access (or the collaborator invitation is not accepted).

1. Confirm the repository owner has invited the exact GitHub account and that the invitation was accepted.
2. On Windows, open **Credential Manager → Windows Credentials** and remove the relevant saved GitHub credential.
3. Retry `git push -u origin main` and authenticate as the invited account through the available Git Credential Manager/browser flow.
4. Never paste passwords, personal access tokens, or SSH private keys into chat or commit them to the repository.

`git config user.name` and `git config user.email` set commit metadata; they do not change the GitHub account used for authentication.

## 8. Troubleshooting quick reference

| Symptom | Checks |
|---|---|
| `psql: command not found` | Install PostgreSQL client tools in WSL or use the intended environment. |
| Connection refused | Check PostgreSQL service status and whether the server is running. |
| Database does not exist | Confirm database name in the setup SQL/README; create it only if appropriate. |
| `extension "vector" is not available` | pgvector OS package/server-version compatibility needs checking before `CREATE EXTENSION`. |
| SQL script stops on an error | Read the first reported SQL error and line; fix the underlying cause before rerunning. |
| Python module missing | Activate `.venv` and install dependencies from the repository's actual dependency file. |
| Embedding dimension mismatch | Ensure model output dimensions equal the database vector column dimensions. |
| Git push returns 403 | Check accepted collaborator access and clear stale Windows GitHub credentials. |

## 9. Before a demo or submission

```bash
git status
git log --oneline -5
```

Confirm the README's actual application startup command, run it in WSL, and capture a successful end-to-end test. Do not report the application as working until its current implementation has been run in the target environment.

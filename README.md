# Research KB — Research Paper Knowledge Base Search

GitHub repository: https://github.com/aryanmittal2107/Research-KB-Semantic-Search

## Included in this package
- `sql/research_kb_setup_clean.sql` — PostgreSQL/pgvector setup script.
- `docs/Research_Paper_Knowledge_Base_Schema_Updated.docx` — updated schema/design document.
- `MASTER_PROMPT_FOR_TEAMMATE.md` — instructions for a teammate to inspect, set up, test, and continue the project.

## Requirements
- PostgreSQL 17
- pgvector extension compatible with your PostgreSQL installation
- `psql` command-line client

## Important setup notes
1. Read the SQL script before running it.
2. The script uses `psql` meta-commands such as `\connect` and `\gexec`; run it with `psql`, not by pasting the whole file into a generic SQL query editor.
3. The script targets a database named `research_kb`.
4. Do not blindly rerun the setup script against an existing database or valuable data.
5. The included sample embeddings are random test vectors. They demonstrate vector storage/query mechanics, not meaningful semantic search quality.
6. This share package contains the SQL and schema documentation available to package here. It does not claim to include a complete frontend/backend application or a real embedding pipeline.

## Suggested command (after reviewing the script)
Run from a terminal where `psql` can connect to PostgreSQL:

```bash
psql -U postgres -d postgres -f sql/research_kb_setup_clean.sql
```

Adjust the host, port, and username to match your machine. The SQL file itself creates/connects to `research_kb`; confirm the connection and script behavior for your environment before execution.

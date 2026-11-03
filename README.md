# Research KB - Semantic Research Paper Search

A web-based research knowledge base for storing research papers and searching their content using semantic similarity. The application uses Flask, PostgreSQL, pgvector, and text embeddings.

## Features

- Semantic search across research-paper chunks
- Embedding generation with `BAAI/bge-small-en-v1.5`
- PostgreSQL storage with pgvector
- Dashboard statistics for papers, chunks, citations, and audit events
- REST API endpoints for health checks, statistics, papers, and search
- Frontend built with HTML, CSS, and JavaScript

## Technology Stack

- **Backend:** Python, Flask
- **Database:** PostgreSQL, pgvector
- **Embeddings:** FastEmbed
- **Frontend:** HTML, CSS, JavaScript
- **Database driver:** psycopg

## Project Structure

```text
Research-KB-Semantic-Search/
|-- backend/
|   |-- app.py
|   |-- generate_embeddings.py
|   |-- test_db.py
|   `-- requirements.txt
|-- frontend/
|   |-- templates/
|   |   `-- index.html
|   `-- static/
|       |-- css/
|       |-- images/
|       `-- js/
|-- sql/
|-- docs/
|-- .env.example
|-- .gitignore
|-- README.md
`-- REFERENCE_README.md
```

## Prerequisites

Install or prepare the following:

- Git
- Python 3.13 (recommended for this project)
- PostgreSQL
- The pgvector extension installed for your PostgreSQL version

You should have permission to create a database and enable the `vector` extension.

## Installation

### 1. Clone the repository

```powershell
git clone https://github.com/aryanmittal2107/Research-KB-Semantic-Search.git
cd Research-KB-Semantic-Search
```

### 2. Create and activate a virtual environment

On Windows PowerShell:

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r backend\requirements.txt
```

If the `py -3.13` command is unavailable, use `python -m venv .venv` with an installed compatible Python version.

If PowerShell blocks activation, you can use this alternative for the current terminal session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
```

### 3. Configure environment variables

Create a local `.env` file in the repository root by copying the example:

```powershell
Copy-Item .env.example .env
```

Open `.env` and enter the connection details for your PostgreSQL server. For example:

```dotenv
DB_HOST=localhost
DB_PORT=5432
DB_NAME=research_kb
DB_USER=postgres
DB_PASSWORD=replace_with_your_local_password
```

These are example values. Use the username, password, host, and port configured on your own PostgreSQL installation.

**Never commit `.env` or publish your database password.**

### 4. Create and initialize the database

Create a PostgreSQL database named `research_kb` if it does not already exist.

For example, from a terminal with PostgreSQL client tools available:

```powershell
createdb -h localhost -p 5432 -U postgres research_kb
```

If the database already exists, skip the creation command.

Apply the project's schema and setup SQL file to that database:

```powershell
psql -h localhost -p 5432 -U postgres -d research_kb -f sql/research_kb_setup_clean.sql
```

Replace `localhost`, `5432`, and `postgres` if your PostgreSQL connection uses different values. If you are running PostgreSQL inside WSL, run these commands in the environment where the PostgreSQL client can connect to your server.

Ensure pgvector is installed and the `vector` extension can be enabled. The setup SQL file is the source of truth for this project's schema and database initialization.

If your database already contains the project tables and data, inspect the SQL file before applying it again.

### 5. Verify the database connection

From the repository root, with the virtual environment activated, run:

```powershell
python backend\test_db.py
```

Resolve any connection or schema errors before starting the application.

### 6. Generate embeddings

If your database has research-paper chunks that still need embeddings, run:

```powershell
python backend\generate_embeddings.py
```

The embedding model may need to download the first time it is used, so an internet connection may be required. Make sure the database is initialized and the expected paper and chunk data is present before running this step.

## Run the Application

From the repository root:

```powershell
python backend\app.py
```

Open the application in your browser:

http://127.0.0.1:5000/

Keep the terminal running while using the application. Stop the development server with `Ctrl+C`.

## API Endpoints

| Endpoint | Purpose |
|---|---|
| `GET /` | Serves the web interface |
| `GET /api/health` | Checks application/database health |
| `GET /api/stats` | Returns dashboard statistics |
| `GET /api/papers` | Returns available papers |
| `GET /api/search?q=your%20query` | Searches paper content semantically |

Example search URL:

http://127.0.0.1:5000/api/search?q=neural%20network%20image%20recognition

The search endpoint uses embedding similarity to rank results. Any displayed similarity or relevance score is a ranking measure, **not a probability that a result is correct**.

## Troubleshooting

### Database connection fails

- Confirm PostgreSQL is running.
- Check the values in `.env`.
- Confirm the database exists and accepts connections on the configured host and port.
- Run `python backend\test_db.py` to test the connection.

### The `vector` extension or vector type is missing

Install a compatible pgvector package for your PostgreSQL installation, then ensure the extension is enabled in the `research_kb` database.

### Embedding generation fails

- Confirm the schema and paper chunks have been created.
- Check the database connection settings.
- Check network access if the embedding model has not yet been downloaded.

### The frontend does not load

Start the application from the repository root using `python backend\app.py`. Check the terminal for errors and verify that the `frontend/templates` and `frontend/static` directories are present.

## Additional Documentation

See [REFERENCE_README.md](REFERENCE_README.md) for the project's detailed reference documentation. Supporting materials are available in the `docs/` directory.

## Development Note

This project is intended for academic and development use. The Flask development server is not a production deployment server.

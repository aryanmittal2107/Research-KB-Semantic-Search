import os
from pathlib import Path

import psycopg
from dotenv import load_dotenv
from fastembed import TextEmbedding
from flask import Flask, jsonify, render_template, request

PROJECT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(PROJECT_ROOT / ".env")

app = Flask(
    __name__,
    template_folder=str(PROJECT_ROOT / "frontend" / "templates"),
    static_folder=str(PROJECT_ROOT / "frontend" / "static"),
)

EMBEDDING_MODEL_NAME = "BAAI/bge-small-en-v1.5"
embedding_model = TextEmbedding(model_name=EMBEDDING_MODEL_NAME)
def get_db_connection():
    return psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "research_kb"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD"),
        connect_timeout=5,
    )


@app.route("/")
def home():
    return render_template("index.html")


@app.route("/api/health")
def database_health():
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT current_database(), version();")
                database, version = cur.fetchone()

        return jsonify({
            "connected": True,
            "database": database,
            "postgresql": version.split(",")[0],
        })
    except psycopg.Error:
        app.logger.exception("Database health check failed")
        return jsonify({
            "connected": False,
            "error": "Database connection failed",
        }), 503


@app.route("/api/stats")
def dashboard_stats():
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT
                        (SELECT COUNT(*) FROM papers),
                        (SELECT COUNT(*) FROM paper_chunks),
                        (SELECT COUNT(*) FROM paper_citations),
                        (SELECT COUNT(*) FROM paper_audit);
                """)

                papers, chunks, citations, audit_events = cur.fetchone()

        return jsonify({
            "total_papers": papers,
            "research_chunks": chunks,
            "citation_links": citations,
            "audit_events": audit_events,
        })

    except psycopg.Error:
        app.logger.exception("Dashboard statistics query failed")
        return jsonify({
            "error": "Unable to load dashboard statistics."
        }), 503


@app.route("/api/papers")
def list_papers():
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT
                        paper_id,
                        title,
                        abstract,
                        publication_year,
                        doi,
                        created_at
                    FROM papers
                    ORDER BY publication_year DESC NULLS LAST,
                             paper_id DESC;
                """)

                rows = cur.fetchall()

        papers = [
            {
                "paper_id": row[0],
                "title": row[1],
                "abstract": row[2],
                "publication_year": row[3],
                "doi": row[4],
                "created_at": row[5].isoformat() if row[5] else None,
            }
            for row in rows
        ]

        return jsonify({"papers": papers, "count": len(papers)})

    except psycopg.Error:
        app.logger.exception("Paper Library query failed")
        return jsonify({
            "error": "Unable to load research papers."
        }), 503




@app.route("/api/search")
def search_papers():
    query = request.args.get("q", "").strip()

    if not query:
        return jsonify({"query": query, "count": 0, "results": []})

    if len(query) > 200:
        return jsonify({
            "error": "Search query must be 200 characters or fewer."
        }), 400

    try:
        # Convert the user's query into a 384-dimensional embedding.
        query_vector = next(
            embedding_model.query_embed([query])
        )
        vector_literal = "[" + ",".join(
            str(float(value)) for value in query_vector
        ) + "]"

        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    WITH chunk_distances AS (
                        SELECT
                            pc.paper_id,
                            pc.content AS matching_chunk,
                            pc.embedding <=> %s::vector AS distance
                        FROM paper_chunks pc
                        WHERE pc.embedding IS NOT NULL
                    ),
                    best_chunk_per_paper AS (
                        SELECT DISTINCT ON (paper_id)
                            paper_id,
                            matching_chunk,
                            distance
                        FROM chunk_distances
                        ORDER BY paper_id, distance ASC
                    )
                    SELECT
                        p.paper_id,
                        p.title,
                        p.abstract,
                        p.publication_year,
                        p.doi,
                        1.0 - b.distance AS relevance,
                        b.matching_chunk
                    FROM best_chunk_per_paper b
		    JOIN papers p ON p.paper_id = b.paper_id
	            WHERE b.distance <= 0.40
		    ORDER BY b.distance ASC
		    LIMIT 50;
                    """,
                    (vector_literal,),
                )

                rows = cur.fetchall()

        results = [
            {
                "paper_id": row[0],
                "title": row[1],
                "abstract": row[2],
                "publication_year": row[3],
                "doi": row[4],
                "relevance": round(float(row[5]), 4),
                "matching_chunk": row[6],
            }
            for row in rows
        ]

        return jsonify({
            "query": query,
            "count": len(results),
            "results": results,
        })

    except psycopg.Error:
        app.logger.exception("Research paper semantic search failed")
        return jsonify({
            "error": "Unable to search research papers."
        }), 503
    except Exception:
        app.logger.exception("Semantic search failed")
        return jsonify({
            "error": "Semantic search encountered an unexpected error."
        }), 500


if __name__ == "__main__":
    app.run(debug=True)

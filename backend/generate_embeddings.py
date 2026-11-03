import os
from pathlib import Path

import psycopg
from dotenv import load_dotenv
from fastembed import TextEmbedding

PROJECT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(PROJECT_ROOT / ".env")

MODEL_NAME = "BAAI/bge-small-en-v1.5"


def main():
    print(f"Loading embedding model: {MODEL_NAME}")
    model = TextEmbedding(model_name=MODEL_NAME)

    conninfo = {
        "host": os.getenv("DB_HOST", "127.0.0.1"),
        "port": os.getenv("DB_PORT", "5432"),
        "dbname": os.getenv("DB_NAME", "research_kb"),
        "user": os.getenv("DB_USER", "postgres"),
        "password": os.getenv("DB_PASSWORD"),
    }

    if not conninfo["password"]:
        raise RuntimeError("DB_PASSWORD is missing from your .env file.")

    with psycopg.connect(**conninfo) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT chunk_id, content "
                "FROM paper_chunks ORDER BY chunk_id"
            )
            chunks = cur.fetchall()

            if not chunks:
                print("No chunks found.")
                return

            texts = [content for _, content in chunks]
            vectors = list(model.embed(texts))

            for (chunk_id, _), vector in zip(chunks, vectors):
                if len(vector) != 384:
                    raise ValueError(
                        f"Chunk {chunk_id} has {len(vector)} dimensions."
                    )

                vector_literal = "[" + ",".join(
                    str(float(value)) for value in vector
                ) + "]"

                cur.execute(
                    """
                    UPDATE paper_chunks
                    SET embedding = %s::vector
                    WHERE chunk_id = %s
                    """,
                    (vector_literal, chunk_id),
                )

            print(f"Updated embeddings for {len(chunks)} chunks.")

            cur.execute(
                """
                SELECT COUNT(*), COUNT(embedding)
                FROM paper_chunks
                """
            )
            total, embedded = cur.fetchone()
            print(f"Total chunks: {total}")
            print(f"Chunks with embeddings: {embedded}")


if __name__ == "__main__":
    main()

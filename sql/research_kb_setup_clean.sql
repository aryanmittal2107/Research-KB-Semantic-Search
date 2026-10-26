--

-- 1. CREATE DATABASE
SELECT 'CREATE DATABASE research_kb'
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = 'research_kb'
)\gexec

\connect research_kb

-- 2. ENABLE PGVECTOR
CREATE EXTENSION IF NOT EXISTS vector;

SELECT extname, extversion
FROM pg_extension
WHERE extname = 'vector';

-- 3. USERS
CREATE TABLE IF NOT EXISTS users (
    user_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. PAPERS
CREATE TABLE IF NOT EXISTS papers (
    paper_id SERIAL PRIMARY KEY,
    title VARCHAR(300) NOT NULL,
    abstract TEXT,
    publication_year INT CHECK (publication_year >= 1900),
    doi VARCHAR(255) UNIQUE,
    file_path TEXT,
    uploaded_by INT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_paper_user
        FOREIGN KEY (uploaded_by)
        REFERENCES users(user_id)
        ON DELETE SET NULL
);

-- 5. AUTHORS
CREATE TABLE IF NOT EXISTS authors (
    author_id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    affiliation VARCHAR(250),
    email VARCHAR(150) UNIQUE
);

-- 6. PAPER-AUTHOR MANY-TO-MANY TABLE
CREATE TABLE IF NOT EXISTS paper_authors (
    paper_id INT NOT NULL,
    author_id INT NOT NULL,
    author_order INT,

    PRIMARY KEY (paper_id, author_id),

    CONSTRAINT fk_paper_author_paper
        FOREIGN KEY (paper_id)
        REFERENCES papers(paper_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_paper_author_author
        FOREIGN KEY (author_id)
        REFERENCES authors(author_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_author_order
        CHECK (author_order > 0)
);

-- 7. TAGS
CREATE TABLE IF NOT EXISTS tags (
    tag_id SERIAL PRIMARY KEY,
    tag_name VARCHAR(100) UNIQUE NOT NULL
);

-- 8. PAPER-TAGS MANY-TO-MANY TABLE
CREATE TABLE IF NOT EXISTS paper_tags (
    paper_id INT NOT NULL,
    tag_id INT NOT NULL,

    PRIMARY KEY (paper_id, tag_id),

    CONSTRAINT fk_paper_tag_paper
        FOREIGN KEY (paper_id)
        REFERENCES papers(paper_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_paper_tag_tag
        FOREIGN KEY (tag_id)
        REFERENCES tags(tag_id)
        ON DELETE CASCADE
);

-- 9. PAPER CITATIONS
CREATE TABLE IF NOT EXISTS paper_citations (
    citing_paper_id INT NOT NULL,
    cited_paper_id INT NOT NULL,
    citation_context TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (citing_paper_id, cited_paper_id),

    CONSTRAINT fk_citing_paper
        FOREIGN KEY (citing_paper_id)
        REFERENCES papers(paper_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_cited_paper
        FOREIGN KEY (cited_paper_id)
        REFERENCES papers(paper_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_no_self_citation
        CHECK (citing_paper_id <> cited_paper_id)
);

-- 10. PAPER CHUNKS + VECTOR EMBEDDINGS
CREATE TABLE IF NOT EXISTS paper_chunks (
    chunk_id BIGSERIAL PRIMARY KEY,
    paper_id INT NOT NULL,
    chunk_number INT NOT NULL,
    content TEXT NOT NULL,
    embedding vector(1536),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_chunk_paper
        FOREIGN KEY (paper_id)
        REFERENCES papers(paper_id)
        ON DELETE CASCADE,

    CONSTRAINT uq_paper_chunk
        UNIQUE (paper_id, chunk_number)
);

-- 11. INDEXES FOR SEARCH/PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_paper_chunks_embedding_hnsw
ON paper_chunks
USING hnsw (embedding vector_cosine_ops);

CREATE INDEX IF NOT EXISTS idx_paper_chunks_paper_id
ON paper_chunks(paper_id);

-- 12. SAMPLE USERS
INSERT INTO users (name, email)
VALUES
    ('Aryan Mittal', 'aryan@example.com'),
    ('Research Admin', 'admin@example.com')
ON CONFLICT (email) DO NOTHING;

-- 13. SAMPLE AUTHORS
INSERT INTO authors (name, affiliation, email)
VALUES
    ('Andrew Ng', 'Stanford University', 'andrew@example.com'),
    ('Ian Goodfellow', 'Research Lab', 'ian@example.com'),
    ('Yoshua Bengio', 'University Research Center', 'yoshua@example.com'),
    ('Geoffrey Hinton', 'University Research Center', 'geoffrey@example.com')
ON CONFLICT (email) DO NOTHING;

-- 14. SAMPLE PAPERS
INSERT INTO papers
    (title, abstract, publication_year, doi, file_path, uploaded_by)
VALUES
(
    'Deep Learning',
    'An overview of deep learning methods based on neural networks and representation learning.',
    2015,
    '10.1038/nature14539',
    'papers/deep_learning.pdf',
    (SELECT user_id FROM users WHERE email = 'aryan@example.com')
),
(
    'Deep Neural Networks for Image Classification',
    'Study of neural network architectures for image classification using learned representations.',
    2016,
    '10.1000/example.001',
    'papers/deep_neural_networks.pdf',
    (SELECT user_id FROM users WHERE email = 'aryan@example.com')
),
(
    'Machine Learning Approaches for Information Retrieval',
    'An investigation of machine learning techniques for improving information retrieval and document search.',
    2020,
    '10.1000/example.002',
    'papers/ml_information_retrieval.pdf',
    (SELECT user_id FROM users WHERE email = 'admin@example.com')
)
ON CONFLICT (doi) DO NOTHING;

-- 15. PAPER-AUTHOR RELATIONSHIPS
INSERT INTO paper_authors (paper_id, author_id, author_order)
SELECT 1, author_id, 1
FROM authors
WHERE email = 'andrew@example.com'
ON CONFLICT DO NOTHING;

INSERT INTO paper_authors (paper_id, author_id, author_order)
SELECT 1, author_id, 2
FROM authors
WHERE email = 'ian@example.com'
ON CONFLICT DO NOTHING;

INSERT INTO paper_authors (paper_id, author_id, author_order)
SELECT 1, author_id, 3
FROM authors
WHERE email = 'yoshua@example.com'
ON CONFLICT DO NOTHING;

INSERT INTO paper_authors (paper_id, author_id, author_order)
SELECT 2, author_id, 1
FROM authors
WHERE email = 'geoffrey@example.com'
ON CONFLICT DO NOTHING;

INSERT INTO paper_authors (paper_id, author_id, author_order)
SELECT 3, author_id, 1
FROM authors
WHERE email = 'andrew@example.com'
ON CONFLICT DO NOTHING;

-- 16. TAGS
INSERT INTO tags (tag_name)
VALUES
    ('Deep Learning'),
    ('Machine Learning'),
    ('Neural Networks'),
    ('Information Retrieval'),
    ('Semantic Search')
ON CONFLICT (tag_name) DO NOTHING;

-- 17. PAPER-TAG RELATIONSHIPS
INSERT INTO paper_tags (paper_id, tag_id)
SELECT 1, tag_id FROM tags WHERE tag_name = 'Deep Learning'
ON CONFLICT DO NOTHING;

INSERT INTO paper_tags (paper_id, tag_id)
SELECT 1, tag_id FROM tags WHERE tag_name = 'Machine Learning'
ON CONFLICT DO NOTHING;

INSERT INTO paper_tags (paper_id, tag_id)
SELECT 1, tag_id FROM tags WHERE tag_name = 'Neural Networks'
ON CONFLICT DO NOTHING;

INSERT INTO paper_tags (paper_id, tag_id)
SELECT 2, tag_id FROM tags WHERE tag_name = 'Deep Learning'
ON CONFLICT DO NOTHING;

INSERT INTO paper_tags (paper_id, tag_id)
SELECT 2, tag_id FROM tags WHERE tag_name = 'Neural Networks'
ON CONFLICT DO NOTHING;

INSERT INTO paper_tags (paper_id, tag_id)
SELECT 3, tag_id FROM tags WHERE tag_name = 'Machine Learning'
ON CONFLICT DO NOTHING;

INSERT INTO paper_tags (paper_id, tag_id)
SELECT 3, tag_id FROM tags WHERE tag_name = 'Information Retrieval'
ON CONFLICT DO NOTHING;

INSERT INTO paper_tags (paper_id, tag_id)
SELECT 3, tag_id FROM tags WHERE tag_name = 'Semantic Search'
ON CONFLICT DO NOTHING;

-- 18. CITATION RELATIONSHIPS
INSERT INTO paper_citations
    (citing_paper_id, cited_paper_id, citation_context)
VALUES
(
    2,
    1,
    'Uses deep learning concepts introduced in the cited work.'
),
(
    3,
    1,
    'Discusses deep learning as a foundation for machine learning based search.'
)
ON CONFLICT DO NOTHING;

-- 19. SAMPLE PAPER CHUNKS
INSERT INTO paper_chunks (paper_id, chunk_number, content)
VALUES
(
    1,
    1,
    'Deep neural networks use multiple layers to learn hierarchical representations from data.'
),
(
    1,
    2,
    'Convolutional neural networks are particularly effective for image classification tasks.'
),
(
    2,
    1,
    'Machine learning can improve information retrieval by learning patterns from documents and queries.'
),
(
    2,
    2,
    'Semantic search attempts to retrieve documents based on meaning rather than exact keyword matching.'
),
(
    3,
    1,
    'Machine learning techniques can be used to improve document search and knowledge discovery.'
)
ON CONFLICT (paper_id, chunk_number) DO NOTHING;

-- 20. DEMO EMBEDDINGS
UPDATE paper_chunks
SET embedding = (
    SELECT array_agg(random()::real ORDER BY n)::vector
    FROM generate_series(1, 1536) AS s(n)
)
WHERE embedding IS NULL;

-- 21. PAPER DETAILS VIEW
CREATE OR REPLACE VIEW paper_details AS
SELECT
    p.paper_id,
    p.title,
    p.abstract,
    p.publication_year,
    p.doi,
    u.name AS uploaded_by,
    p.created_at,
    p.updated_at
FROM papers p
LEFT JOIN users u
    ON p.uploaded_by = u.user_id;

-- 22. CITATION NETWORK VIEW
CREATE OR REPLACE VIEW citation_network AS
SELECT
    pc.citing_paper_id,
    citing.title AS citing_paper,
    pc.cited_paper_id,
    cited.title AS cited_paper,
    pc.citation_context
FROM paper_citations pc
JOIN papers citing
    ON pc.citing_paper_id = citing.paper_id
JOIN papers cited
    ON pc.cited_paper_id = cited.paper_id;

-- 23. UPDATED_AT TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION update_paper_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 24. UPDATED_AT TRIGGER
DROP TRIGGER IF EXISTS trg_update_paper_timestamp ON papers;

CREATE TRIGGER trg_update_paper_timestamp
BEFORE UPDATE ON papers
FOR EACH ROW
EXECUTE FUNCTION update_paper_timestamp();

-- 25. TEST QUERIES

\dt

SELECT * FROM papers ORDER BY paper_id;

SELECT chunk_id, paper_id, chunk_number, content
FROM paper_chunks
ORDER BY paper_id, chunk_number;

SELECT * FROM paper_details;

SELECT * FROM citation_network;

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

\d paper_chunks

-- END OF DATABASE SETUP

-- OFFSET pagination: PostgreSQL scans rows in sort order, then discards
-- the first OFFSET rows before returning the requested page.

SELECT id, title, created_at
FROM posts
ORDER BY created_at DESC, id DESC
LIMIT 20 OFFSET 0;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title, created_at
FROM posts
ORDER BY created_at DESC, id DESC
LIMIT 20 OFFSET 0;

SELECT id, title, created_at
FROM posts
ORDER BY created_at DESC, id DESC
LIMIT 20 OFFSET 10000;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title, created_at
FROM posts
ORDER BY created_at DESC, id DESC
LIMIT 20 OFFSET 10000;

SELECT id, title, created_at
FROM posts
ORDER BY created_at DESC, id DESC
LIMIT 20 OFFSET 100000;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title, created_at
FROM posts
ORDER BY created_at DESC, id DESC
LIMIT 20 OFFSET 100000;

SELECT id, title, created_at
FROM posts
ORDER BY created_at DESC, id DESC
LIMIT 20 OFFSET 500000;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title, created_at
FROM posts
ORDER BY created_at DESC, id DESC
LIMIT 20 OFFSET 500000;

SELECT id, title, created_at
FROM posts
ORDER BY created_at DESC, id DESC
LIMIT 20 OFFSET 900000;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title, created_at
FROM posts
ORDER BY created_at DESC, id DESC
LIMIT 20 OFFSET 900000;
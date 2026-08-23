-- Compare the same deep region (page size 20, zero-based offset 500000).
-- Inspect Execution Time, actual rows, rows removed/skipped, Index Scan or
-- Index Only Scan, and Buffers. Exact times depend on hardware, cache state,
-- PostgreSQL settings, and the current database state.

-- 1. Deep OFFSET: the ordered scan must reach and discard 500000 rows.
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title, created_at
FROM posts
ORDER BY created_at DESC, id DESC
LIMIT 20 OFFSET 500000;

-- 2. Keyset query after a known cursor. Here the cursor is materialized from
-- the row immediately before the target region only to make this file self-contained.
EXPLAIN (ANALYZE, BUFFERS)
WITH known_cursor AS (
    SELECT created_at, id
    FROM posts
    ORDER BY created_at DESC, id DESC
    OFFSET 499999
    LIMIT 1
)
SELECT p.id, p.title, p.created_at
FROM posts AS p
WHERE (p.created_at, p.id) < (SELECT created_at, id FROM known_cursor)
ORDER BY p.created_at DESC, p.id DESC
LIMIT 20;

-- 3. Jump + seek: obtain the predecessor cursor once, then seek to the page.
EXPLAIN (ANALYZE, BUFFERS)
WITH jump_cursor AS (
    SELECT created_at, id
    FROM posts
    ORDER BY created_at DESC, id DESC
    OFFSET 499999
    LIMIT 1
)
SELECT p.id, p.title, p.created_at
FROM posts AS p
WHERE (p.created_at, p.id) < (SELECT created_at, id FROM jump_cursor)
ORDER BY p.created_at DESC, p.id DESC
LIMIT 20;

-- In a real workflow, query 2 receives the cursor from an earlier request,
-- so its seek portion does not repeat the jump. Query 3 makes that one-time
-- jump explicit. Compare execution plans rather than assuming timings.

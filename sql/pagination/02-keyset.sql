-- The first keyset page has no cursor.
SELECT id, title, created_at
FROM posts
ORDER BY created_at DESC, id DESC
LIMIT 20;

-- Illustrative parameterized form (psql does not expand :name by default):
-- WHERE (created_at, id) < (:cursor_created_at, :cursor_id)
-- ORDER BY created_at DESC, id DESC
-- LIMIT 20;

-- Fully executable example: derive the cursor from the last row of page 1,
-- then fetch page 2 with one seek query.
-- получает первые 20 постов;
-- находит последний пост из этой первой двадцатки и использует его как cursor, чтобы вернуть следующие 20 постов
WITH first_page AS (
    SELECT id, title, created_at
    FROM posts
    ORDER BY created_at DESC, id DESC
    LIMIT 20
), cursor AS (
    SELECT created_at, id
    FROM first_page
    ORDER BY created_at ASC, id ASC
    LIMIT 1
)
SELECT p.id, p.title, p.created_at
FROM posts AS p
WHERE (p.created_at, p.id) < (SELECT created_at, id FROM cursor)
ORDER BY p.created_at DESC, p.id DESC
LIMIT 20;

EXPLAIN (ANALYZE, BUFFERS)
WITH first_page AS (
    SELECT id, title, created_at
    FROM posts
    ORDER BY created_at DESC, id DESC
    LIMIT 20
), cursor AS (
    SELECT created_at, id
    FROM first_page
    ORDER BY created_at ASC, id ASC
    LIMIT 1
)
SELECT p.id, p.title, p.created_at
FROM posts AS p
WHERE (p.created_at, p.id) < (SELECT created_at, id FROM cursor)
ORDER BY p.created_at DESC, p.id DESC
LIMIT 20;

-- For ORDER BY ... DESC, '<' selects a tuple after the cursor in that
-- ordering. It does not mean id is smaller by 20 or describe physical
-- table position. Both sort-key values are compared lexicographically.

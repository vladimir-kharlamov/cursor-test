-- Page + Cursor (jump + seek), with page_size = 20 and page_number = 25001.
-- target_offset = (25001 - 1) * 20 = 500000.
-- The predecessor is at zero-based offset 499999.
-- OFFSET 500000 LIMIT 1 would return the first row of the target page;
-- seeking after it would exclude that row, so this query intentionally uses
-- OFFSET 499999 LIMIT 1 as the predecessor cursor.

WITH jump_cursor AS (
    SELECT created_at, id
    FROM posts
    ORDER BY created_at DESC, id DESC
    OFFSET 499999
    LIMIT 1
)
SELECT p.id, p.title, p.created_at
FROM posts AS p
WHERE (p.created_at, p.id) < (
    SELECT created_at, id
    FROM jump_cursor
)
ORDER BY p.created_at DESC, p.id DESC
LIMIT 20;

-- The initial jump is still expensive. It is paid once; subsequent pages
-- should use the last returned row as a keyset cursor.
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
WHERE (p.created_at, p.id) < (
    SELECT created_at, id
    FROM jump_cursor
)
ORDER BY p.created_at DESC, p.id DESC
LIMIT 20;

-- Separate jump step, showing the boundary row directly.
EXPLAIN (ANALYZE, BUFFERS)
SELECT created_at, id
FROM posts
ORDER BY created_at DESC, id DESC
OFFSET 499999
LIMIT 1;

-- Page 1 is an edge case: it has no predecessor cursor, so query it without
-- a WHERE predicate. For later pages, use the previous page's last row.

-- Описание сути идеи комбинированного подхода.
-- В текущих примерах важен сам подход:
-- первая страница загружается без WHERE;
-- последняя строка страницы становится cursor;
-- cursor содержит (created_at, id);
-- cursor сохраняется в Redis;
-- следующая страница использует WHERE (created_at, id) < (...);
-- отсутствие cursor означает запрос первой страницы;
-- пустая страница удаляет cursor из Redis.
-- Примеры на Go и PHP показывают, как это реализовать в коде.
-- code_examples/pagination.go 

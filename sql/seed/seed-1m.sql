INSERT INTO posts (title, created_at)
SELECT
    'Post ' || series,
    TIMESTAMPTZ '2020-01-01 00:00:00+00'
        + (series / 1000) * INTERVAL '1 minute'
        + (series % 1000) * INTERVAL '1 second'
FROM generate_series(1, 1000000) AS series;

ANALYZE posts;

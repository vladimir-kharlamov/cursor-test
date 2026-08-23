<?php

// Одна запись cursor: последняя строка уже загруженной страницы.
final class PageCursor
{
    public function __construct(
        public readonly string $createdAt,
        public readonly int $id,
    ) {
    }
}

// $redis - инстанс Redis, где сохраняем cursor отдельно для каждой ленты/сессии.
// Для первой страницы $cursor равен null, поэтому WHERE не добавляется.
function fetchPostsPage(PDO $db, ?PageCursor $cursor, int $pageSize = 20): array
{
    $sql = <<<'SQL'
        SELECT id, title, created_at
        FROM posts
        ORDER BY created_at DESC, id DESC
        LIMIT :page_size
    SQL;

    if ($cursor !== null) {
        $sql = <<<'SQL'
            SELECT id, title, created_at
            FROM posts
            WHERE (created_at, id) < (:cursor_created_at, :cursor_id)
            ORDER BY created_at DESC, id DESC
            LIMIT :page_size
        SQL;
    }

    $statement = $db->prepare($sql);
    $statement->bindValue(':page_size', $pageSize, PDO::PARAM_INT);

    if ($cursor !== null) {
        $statement->bindValue(':cursor_created_at', $cursor->createdAt);
        $statement->bindValue(':cursor_id', $cursor->id, PDO::PARAM_INT);
    }

    $statement->execute();
    return $statement->fetchAll(PDO::FETCH_ASSOC);
}

// Последняя строка страницы становится cursor для следующего запроса.
function cursorFromPage(array $page): ?PageCursor
{
    if ($page === []) {
        return null;
    }

    $lastPost = $page[array_key_last($page)];
    return new PageCursor($lastPost['created_at'], (int) $lastPost['id']);
}

// Главный сценарий: page 1 без cursor, следующие страницы с cursor из Redis.
function getNextPostsPage(PDO $db, Redis $redis, string $feedKey, int $pageSize = 20): array
{
    $storedCursor = $redis->get($feedKey);
    $cursor = $storedCursor === false
        ? null
        : new PageCursor(...json_decode($storedCursor, true, flags: JSON_THROW_ON_ERROR));

    $page = fetchPostsPage($db, $cursor, $pageSize);
    $nextCursor = cursorFromPage($page);

    if ($nextCursor === null) {
        $redis->del($feedKey);
    } else {
        $redis->set($feedKey, json_encode([
            'createdAt' => $nextCursor->createdAt,
            'id' => $nextCursor->id,
        ], JSON_THROW_ON_ERROR));
    }

    return $page;
}

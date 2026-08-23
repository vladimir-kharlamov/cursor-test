package pagination

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"

	"github.com/redis/go-redis/v9"
)

// PageCursor хранит сортировочные значения последней строки страницы.
type PageCursor struct {
	CreatedAt string `json:"createdAt"`
	ID        int64  `json:"id"`
}

type Post struct {
	ID        int64
	Title     string
	CreatedAt string
}

// FetchPostsPage: при nil cursor загружает первую страницу без WHERE;
// при наличии cursor делает keyset-запрос для следующей страницы.
func FetchPostsPage(ctx context.Context, db *sql.DB, cursor *PageCursor, pageSize int) ([]Post, error) {
	query := `
		SELECT id, title, created_at
		FROM posts
		ORDER BY created_at DESC, id DESC
		LIMIT $1`
	args := []any{pageSize}

	if cursor != nil {
		query = `
			SELECT id, title, created_at
			FROM posts
			WHERE (created_at, id) < ($1, $2)
			ORDER BY created_at DESC, id DESC
			LIMIT $3`
		args = []any{cursor.CreatedAt, cursor.ID, pageSize}
	}

	rows, err := db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	posts := make([]Post, 0, pageSize)
	for rows.Next() {
		var post Post
		if err := rows.Scan(&post.ID, &post.Title, &post.CreatedAt); err != nil {
			return nil, err
		}
		posts = append(posts, post)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return posts, nil
}

// CursorFromLastRow преобразует последнюю строку результата в cursor.
func CursorFromLastRow(createdAt string, id int64) *PageCursor {
	return &PageCursor{CreatedAt: createdAt, ID: id}
}

// GetNextPostsPage: Redis хранит cursor по ключу конкретной ленты/сессии.
// Если ключа нет, это первая страница; после ответа сохраняется её граница.
func GetNextPostsPage(ctx context.Context, db *sql.DB, cache *redis.Client, feedKey string, pageSize int) ([]Post, error) {
	stored, err := cache.Get(ctx, feedKey).Result()
	var cursor *PageCursor

	if err == nil {
		cursor = &PageCursor{}
		if unmarshalErr := json.Unmarshal([]byte(stored), cursor); unmarshalErr != nil {
			return nil, fmt.Errorf("decode page cursor: %w", unmarshalErr)
		}
	} else if err != redis.Nil {
		return nil, fmt.Errorf("read page cursor: %w", err)
	}

	posts, err := FetchPostsPage(ctx, db, cursor, pageSize)
	if err != nil {
		return nil, err
	}

	if len(posts) == 0 {
		if err := cache.Del(ctx, feedKey).Err(); err != nil {
			return nil, fmt.Errorf("delete page cursor: %w", err)
		}
		return posts, nil
	}

	nextCursor := CursorFromLastRow(posts[len(posts)-1].CreatedAt, posts[len(posts)-1].ID)
	encoded, err := json.Marshal(nextCursor)
	if err != nil {
		return nil, fmt.Errorf("encode page cursor: %w", err)
	}
	if err := cache.Set(ctx, feedKey, encoded, 0).Err(); err != nil {
		return nil, fmt.Errorf("save page cursor: %w", err)
	}

	return posts, nil
}

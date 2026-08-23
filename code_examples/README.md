# Примеры Page + Cursor

## Идея

Первая страница не имеет предыдущей строки, поэтому запрос выполняется без `WHERE`:

```sql
SELECT ... FROM posts
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

После получения страницы приложение берет ее последнюю строку и сохраняет пару `(created_at, id)` как cursor. Следующий запрос использует:

```sql
WHERE (created_at, id) < (:cursor_created_at, :cursor_id)
```

Redis в примерах хранит cursor по ключу ленты или пользовательской сессии. Это не сами данные PostgreSQL, а только состояние навигации. Для первой страницы отсутствие ключа Redis означает `cursor = null`.

- `pagination.php` показывает вариант с `PDO` и расширением `redis`.
- `pagination.go` показывает вариант с `database/sql` и клиентом `github.com/redis/go-redis/v9`.

Для запуска PHP нужен установленный класс `Redis` из PHP extension `redis`. Для Go-проекта добавьте зависимость командой `go get github.com/redis/go-redis/v9`.

Примеры содержат основные функции и намеренно не включают настройку HTTP-роутов, подключение к базам и полный bootstrap приложения.

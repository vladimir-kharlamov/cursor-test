# PostgreSQL Pagination Lab

Учебный Docker-проект для экспериментального сравнения `LIMIT/OFFSET`, cursor/keyset pagination, техники `Page + Cursor` (`jump + seek`), а также `EXPLAIN` и `EXPLAIN ANALYZE`.

## Архитектура

Проект состоит из двух контейнеров:

- `cursor_test_postgres` собирается из локального `postgres:16-alpine` через `Dockerfile`.
- `cursor_test_adminer` предоставляет веб-интерфейс на `http://localhost:8080`.

Compose создает стандартную внутреннюю сеть. Adminer подключается к PostgreSQL по имени Compose-сервиса `postgres`, а не по `localhost`: `localhost` внутри контейнера Adminer означает сам контейнер Adminer.

PostgreSQL bind mount связывает директорию macOS `[your abs path]/cursor_test/data/postgres` с `/var/lib/postgresql/data` внутри PostgreSQL container. Поэтому удаление контейнера не удаляет данные из `data/postgres`. И наоборот, удаление `data/postgres` уничтожит локальные данные PostgreSQL этого проекта.

## Структура

```text
Dockerfile
compose.yaml
.env
.gitignore
README.md
data/postgres/
sql/init/01-schema.sql
sql/seed/seed-1m.sql
sql/pagination/01-offset.sql
sql/pagination/02-keyset.sql
sql/pagination/03-page-cursor.sql
sql/pagination/04-comparison.sql
scripts/seed.sh
```

`sql/init/01-schema.sql` запускается entrypoint PostgreSQL через `/docker-entrypoint-initdb.d/` только при первом создании пустого data directory. Миллион строк туда не входит: dataset загружается отдельной командой.

## Запуск

```sh
cd [your abs path]/cursor_test
docker compose up -d --build
docker compose ps
docker compose logs -f postgres
```

Подключение через `psql` внутри контейнера:

```sh
docker compose exec postgres psql -U cursor_user -d cursor_test
```

Adminer: http://localhost:8080

Параметры входа:

- System: `PostgreSQL`
- Server: `postgres`
- Username: `cursor_user`
- Password: значение `POSTGRES_PASSWORD` из `.env`
- Database: `cursor_test`

Пароль в `.env` 

## Dataset

Запускайте `seed.sh` после успешного выполнения `docker compose up -d --build` и
проверки, что PostgreSQL имеет статус `healthy`. Выполнять скрипт нужно из корня
проекта `[your abs path]/cursor_test`, до запуска pagination-тестов:

```sh
cd [your abs path]/cursor_test
./scripts/seed.sh
```

Скрипт использует `generate_series(1, 1000000)`, выполняет `ANALYZE posts` и
выводит `SELECT count(*) FROM posts;`. Он не запускается автоматически.
После успешного выполнения в таблице должно быть ровно `1000000` строк.
Не запускайте `./scripts/seed.sh` повторно без сброса базы: каждый запуск добавит
ещё 1 000 000 строк.

Проверка количества строк вручную:

```sh
docker compose exec postgres \
  psql -U cursor_user -d cursor_test \
  -c "SELECT count(*) FROM posts;"
```

## Pagination experiments

Файлы запускаются через stdin или Adminer:

```sh
docker compose exec -T postgres psql -U cursor_user -d cursor_test < sql/pagination/01-offset.sql
docker compose exec -T postgres psql -U cursor_user -d cursor_test < sql/pagination/02-keyset.sql
docker compose exec -T postgres psql -U cursor_user -d cursor_test < sql/pagination/03-page-cursor.sql
docker compose exec -T postgres psql -U cursor_user -d cursor_test < sql/pagination/04-comparison.sql
```

`01-offset.sql` показывает глубину `OFFSET` до 900000. `02-keyset.sql` демонстрирует составной cursor `(created_at, id)`. При `ORDER BY created_at DESC, id DESC` используется `<`: это поиск tuple, который находится после cursor в сортировке. Это не означает «id меньше на 20» и не описывает физическое положение строки в таблице.

`03-page-cursor.sql` использует `page_size = 20`, `page_number = 25001`: `(25001 - 1) * 20 = 500000`. Cursor-предшественник находится на zero-based offset `499999`, поэтому после seek первая строка результата имеет глобальный offset `500000`. Первоначальный jump не бесплатен и выполняется один раз; последующее листание использует keyset cursor.

Смотрите в планах `Execution Time`, `actual rows`, `rows removed/skipped`, `Index Scan` или `Index Only Scan`, `Buffers` и стоимость глубокого `OFFSET`. Конкретные времена зависят от hardware, cache и состояния PostgreSQL.

## Reset database

`docker compose down` не удаляет данные bind mount. Для полного сброса тестовой базы:

**ВНИМАНИЕ: следующая команда после интерактивного подтверждения безвозвратно
удаляет данные именно этой тестовой базы. Перед подтверждением проверьте текущую
директорию.**

```sh
docker compose down
rm -rI ./data/postgres/*
docker compose up -d --build
```

Ключ `-I` запрашивает подтверждение перед удалением большого количества файлов.
Не подтверждайте удаление, если текущая директория не является корнем проекта.

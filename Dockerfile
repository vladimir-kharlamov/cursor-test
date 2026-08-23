FROM postgres:16-alpine

COPY sql/init/01-schema.sql /docker-entrypoint-initdb.d/01-schema.sql

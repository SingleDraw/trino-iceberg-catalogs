
# Complete setups for Trino with Iceberg Catalogs:
- JDBC
- Hive Metastore
- Rest

# Usage:
> use tag for selected setup: `[ jdbc | rest | hms ]`
```bash
# Init .env
make init-env

# Runs selected setup
make run-`tag`
# Run various queries
make test-`tag`
# tear down setup with volumes
make down-`tag`

#Optional: generate full compose yaml for given setup:
make gen-com-`tag`
```

# Setups include:
- Minio S3 storage
- Clickhouse

# Known issues:
When using `clickhouse/clickhouse-server:25.10-alpine`, or newer trino fails to connect to clickhouse:
```log
Query <id> failed: Error listing schemas for catalog clickhouse: java.io.IOException: Magic is not correct - expect [-126] but got [123]
```
The reason is that Clickhouse 25 introduced breaking protocol changes that Trino's JDBC driver hasn't caught up with yet.
Works with `clickhouse/clickhouse-server:24.8-alpine` for now.
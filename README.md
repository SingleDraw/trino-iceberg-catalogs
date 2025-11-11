
# Complete setups for Trino with Iceberg Catalogs:
- JDBC
- Hive Metastore
- Rest

# Usage:
> use tag for selected setup: [jdbc|rest|hms]
- make run-<tag>
- make test-<tag>
- make down-<tag>

# Setups include:
- Minio S3 storage
- Clickhouse

# Todo
- add MariaDB with tests
- Add RBAC users in Trino, Minio, Clickhouse etc.
- Cover with Certs (mTLS, TLS)
- Add client in Trino tests
- Add joins in test queries

# Known issues:
When using `clickhouse/clickhouse-server:25.10-alpine`, or newer trino fails to connect to clickhouse:
```log
Query <id> failed: Error listing schemas for catalog clickhouse: java.io.IOException: Magic is not correct - expect [-126] but got [123]
```
The reason is that Clickhouse 25 introduced breaking protocol changes that Trino's JDBC driver hasn't caught up with yet.
Works with `clickhouse/clickhouse-server:24.8-alpine` for now.
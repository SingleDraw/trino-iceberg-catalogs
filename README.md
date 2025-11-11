# Trino Iceberg Catalogs

Modular Trino + Iceberg environments powered by Postgres and MinIO, supporting **Hive Metastore**, **REST**, and **JDBC** catalog variants with ClickHouse integration. Provides ready-to-use setups for testing and development with Trino against Iceberg and ClickHouse.

---

## Features

- Multiple Iceberg catalog configurations:
  - **JDBC catalog** (Postgres backend)
  - **Hive Metastore**
  - **REST catalog**
- Trino query engine
- MinIO S3 storage
- ClickHouse analytics/serving layer
- Predefined Docker images for reproducible environments

---

## Prerequisites

- Docker & Docker Compose installed
- `make` command available

---

## Usage

1. Initialize environment:
```bash
make init-env
````

2. Pull all required Docker images:

```bash
make pull-images
```

3. Run a selected setup (`jdbc`, `rest`, or `hms`):

```bash
make run-<tag>
```

4. Run test queries against the catalog:

```bash
make test-<tag>
```

5. Tear down the setup and remove volumes:

```bash
make down-<tag>
```

6. Generate a complete merged `docker-compose.yml` for the selected setup:

```bash
make gen-com-<tag>
```

---

## Notes on Tags

* `[jdbc | rest | hms]` — choose the catalog backend:

  * `jdbc` → Postgres-backed Iceberg catalog
  * `rest` → Iceberg REST catalog
  * `hms` → Hive Metastore catalog

---

## Known Issues

* **ClickHouse compatibility**:
  Using `clickhouse/clickhouse-server:25.10-alpine` or newer may fail with Trino:

  ```log
  Query <id> failed: Error listing schemas for catalog clickhouse: java.io.IOException: Magic is not correct - expect [-126] but got [123]
  ```

  Works with `clickhouse/clickhouse-server:24.8-alpine`.

---

## Contributing

Feel free to open issues or pull requests for:

* Adding new catalog variants
* Updating image versions
* Improving test queries

---

## License

MIT License


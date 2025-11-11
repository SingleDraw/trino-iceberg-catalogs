
# read .env file
-include .env

PROJECT_NAME := trino-iceberg-cluster
YAML_DIR := compose
ENV_FLAGS := --env-file .env --env-file .env.images

define generate-compose-string 
	-f $(YAML_DIR)/core.yml \
	-f $(YAML_DIR)/iceberg-$(1).yml \
	-f $(YAML_DIR)/clickhouse.yml \
	-f $(YAML_DIR)/minio.yml
endef



define run-docker-compose
	docker compose $(ENV_FLAGS) -p $(PROJECT_NAME) $(1) up -d
endef

define down-docker-compose
	docker compose $(ENV_FLAGS) -p $(PROJECT_NAME) $(1) down -v
endef



JDBC_COMPOSE_STRING := $(call generate-compose-string,jdbc)
REST_COMPOSE_STRING := $(call generate-compose-string,rest)
HMS_COMPOSE_STRING := $(call generate-compose-string,hms)

# ----------------------------------------------------
# Optional helpers to generate merged docker-compose files
# ----------------------------------------------------
define generate-compose-file
	docker compose $(ENV_FLAGS) $(1) config > merged.yml
endef
gen-com-rest:
	@$(call generate-compose-file,$(REST_COMPOSE_STRING))
	@echo "Generated merged Docker Compose file for REST Catalog setup..."
gen-com-jdbc:
	@$(call generate-compose-file,$(JDBC_COMPOSE_STRING))
	@echo "Generated merged Docker Compose file for JDBC Catalog setup..."
gen-com-hms:
	@$(call generate-compose-file,$(HMS_COMPOSE_STRING))
	@echo "Generated merged Docker Compose file for Hive Metastore Catalog setup..."

# ----------------------------------------------------
# Helpers
# ----------------------------------------------------
img-size:
	docker inspect apache/hive:4.0.0 --format='{{.Size}}' | numfmt --to=iec

init-env:
	@cp .env.example .env
	@echo "Initialized .env file from .env.example"

create-bucket:
	@echo "===> Create Minio bucket <==="
	@docker compose -p $(PROJECT_NAME) exec minio mc alias set local http://minio:9000 minioadmin miniopassword
	@docker compose -p $(PROJECT_NAME) exec minio mc mb local/warehouse --ignore-existing
	@docker compose -p $(PROJECT_NAME) exec minio mc policy set public local/warehouse

test-clickhouse-docker:
	@echo "===> Testing Trino connection to ClickHouse <==="
	@docker compose -p $(PROJECT_NAME) exec trino trino --execute "\
		SHOW SCHEMAS FROM clickhouse; \
		CREATE SCHEMA IF NOT EXISTS clickhouse.test; \
		CREATE TABLE IF NOT EXISTS clickhouse.test.testtable (id int, price double); \
		INSERT INTO clickhouse.test.testtable VALUES (1, 9.99); \
		SHOW TABLES FROM clickhouse.test; \
		SELECT * FROM clickhouse.test.testtable LIMIT 10;"


create-test-data:
	@echo "===> Creating test data in iceberg.sales.test_data <==="
	time docker compose -p $(PROJECT_NAME) exec trino trino --execute "\
		CREATE SCHEMA IF NOT EXISTS iceberg.sales; \
		DROP TABLE IF EXISTS iceberg.sales.test_data; \
		CREATE TABLE iceberg.sales.test_data AS \
		SELECT \
			orderkey AS id, \
			CAST(totalprice AS DOUBLE) AS price, \
			'2025-11-07' AS date \
		FROM tpch.sf1.orders \
		LIMIT 1000000; \
	"

test-data-count:
	@echo "===> Counting rows in iceberg.sales.test_data <==="
	time docker compose -p $(PROJECT_NAME) exec trino trino --execute "\
		SELECT COUNT(*) FROM iceberg.sales.test_data; \
	"

# ----------------------------------------------------
# Trino with Iceberg over REST API
# ----------------------------------------------------
run-rest:
	@$(call run-docker-compose,$(REST_COMPOSE_STRING))

down-rest:
	@$(call down-docker-compose,$(REST_COMPOSE_STRING))

test-rest:
# 	@make create-bucket
	@echo "===> Testing Trino connection to Iceberg catalog <==="
	@docker compose -p $(PROJECT_NAME) exec trino trino --execute "SHOW CATALOGS;"

	@echo "===> Testing Iceberg schemas <==="
	@docker compose -p $(PROJECT_NAME) exec trino trino --execute "\
			SHOW SCHEMAS FROM iceberg; \
		   	CREATE SCHEMA IF NOT EXISTS iceberg.sales; \
   			CREATE TABLE IF NOT EXISTS iceberg.sales.orders (id int, price double) WITH (location='s3://warehouse/sales/orders'); \
   			INSERT INTO iceberg.sales.orders VALUES (1, 9.99); \
		"
	@echo "===> Testing Iceberg tables <==="
	@docker compose -p $(PROJECT_NAME) exec trino trino --execute "\
			SHOW TABLES FROM iceberg.sales; \
			SELECT * FROM iceberg.sales.orders; \
			"
	@make test-clickhouse-docker

# ----------------------------------------------------
# Trino with Iceberg over JDBC Catalog + ClickHouse
# ----------------------------------------------------
run-jdbc:
	@$(call run-docker-compose,$(JDBC_COMPOSE_STRING))

down-jdbc:
	@$(call down-docker-compose,$(JDBC_COMPOSE_STRING))

test-jdbc:
# 	@make create-bucket
	@echo "===> Testing Trino connection to Iceberg catalog <==="
	@docker compose -p $(PROJECT_NAME) exec trino trino --execute "SHOW CATALOGS;"

	@echo "===> Testing Iceberg schemas <==="
	@docker compose -p $(PROJECT_NAME) exec trino trino --execute "\
			SHOW SCHEMAS FROM iceberg; \
		   	CREATE SCHEMA IF NOT EXISTS iceberg.sales; \
   			CREATE TABLE IF NOT EXISTS iceberg.sales.orders (id int, price double) WITH (location='s3a://warehouse/sales/orders'); \
   			INSERT INTO iceberg.sales.orders VALUES (1, 9.99); \
		"
	@echo "===> Testing Iceberg tables <==="
	@docker compose -p $(PROJECT_NAME) exec trino trino --execute "\
			SHOW TABLES FROM iceberg.sales; \
			SELECT * FROM iceberg.sales.orders; \
			"
	@make test-clickhouse-docker

# ----------------------------------------------------
# Trino with Iceberg over Hive Metastore
# ----------------------------------------------------
download-jars:
	@bash ./scripts/download-jars.sh

run-hms:
	@make download-jars
	@$(call run-docker-compose,$(HMS_COMPOSE_STRING))

down-hms:
	@$(call down-docker-compose,$(HMS_COMPOSE_STRING))

test-hms:
# 	@make create-bucket
	@echo "===> Testing Trino connection to Iceberg catalog <==="
	@docker compose -p $(PROJECT_NAME) exec trino trino --execute "SHOW CATALOGS;"

	@echo "===> Testing Iceberg schemas <==="
	@docker compose -p $(PROJECT_NAME) exec trino trino --execute "\
			SHOW SCHEMAS FROM iceberg; \
		   	CREATE SCHEMA IF NOT EXISTS iceberg.sales; \
   			CREATE TABLE IF NOT EXISTS iceberg.sales.orders (id int, price double) WITH (location='s3a://warehouse/external/sales/orders'); \
   			INSERT INTO iceberg.sales.orders VALUES (1, 9.99); \
			CREATE TABLE IF NOT EXISTS iceberg.sales.managed_order (id int, price double); \
			INSERT INTO iceberg.sales.managed_order VALUES (1, 21.77); \
		"
	@echo "===> Testing Iceberg tables <==="
	@docker compose -p $(PROJECT_NAME) exec trino trino --execute "\
			SHOW TABLES FROM iceberg.sales; \
			SELECT * FROM iceberg.sales.orders; \
			SELECT * FROM iceberg.sales.managed_order; \
			"
	@make test-clickhouse-docker

# -----------------------------------------------------

gen-trino-passwords:
	@bash ./scripts/gen-trino-passwords.sh true

gen-certs:
	@bash ./scripts/gen-certs.sh

run:
	@bash ./scripts/gen-trino-passwords.sh
	@docker compose up -d

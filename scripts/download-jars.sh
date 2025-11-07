#!/bin/bash

# This script downloads necessary JAR files for Hive Metastore integration with Trino.

set -e

TARGET_DIR=./hms-jars

# wget command check
if ! command -v wget &> /dev/null; then
    echo "wget could not be found, please install wget to proceed."
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
fi
      
POSTGRES_JDBC_VERSION=42.7.3

# Download PostgreSQL JDBC Driver
if [ ! -f "$TARGET_DIR/postgresql-${POSTGRES_JDBC_VERSION}.jar" ]; then
    wget https://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_VERSION}.jar -P "$TARGET_DIR"
    echo 'Downloaded PostgreSQL JDBC driver jar.'
fi
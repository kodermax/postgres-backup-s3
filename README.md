# Postgres S3 docker/kubernetes backup

[![Build status](https://github.com/BackupTools/postgres-backup-s3/workflows/Docker%20Image%20CI/badge.svg)]() [![Pulls](https://img.shields.io/docker/pulls/backuptools/postgres-backup-s3?style=flat&labelColor=1B3D4B&color=06A64F&logoColor=white&logo=docker&label=pulls)]()

Docker image to backup Postgres database(s) to S3 using pg_dump and compress using pigz (default), xz, bzip2, lrzip, brotli, zstd.

## Advantages/features

- [x] Supports custom S3 endpoints (e.g. MinIO)
- [x] Streamed uploads (no temp files)
- [x] Parallel gzip via pigz by default
- [x] Bucket auto-creation if missing
- [x] Works in Kubernetes or Docker
- [x] Per-database backups unless DB is specified in `PG_URI`
- [x] Optional PGP encryption (recipient key via `GPG_KEYID`)
- [x] Compression methods: `pigz`, `xz`, `bzip2`, `lrzip`, `brotli`, `zstd`
- [x] Database ping before dump
- [x] Retention: delete old backups via `S3_KEEP_DAYS`
- [x] Robust GPG key import with retries
- [ ] TODO: Support more databases (e.g. MySQL)
- [ ] TODO: Alternative to `PG_URI` via separate envs

## Configuration

```bash
# S3
S3_BUCK=postgres1-backups
S3_NAME=folder-name/backup-name-prefix
S3_URI=https://s3-key:s3-secret@s3.host.tld

# Postgres
PG_URI=postgres://user:password@postgres-host:5432/db-name
PGCONNECT_TIMEOUT=10

# Optional encryption
GPG_KEYSERVER=keyserver.ubuntu.com   # your HKPS/HKP keyserver
GPG_KEYID=<key_id>                   # recipient key, enables encryption if set

# Compression
COMPRESS=pigz                        # pigz | xz | bzip2 | lrzip | brotli | zstd
COMPRESS_LEVEL=9                     # compression level for selected compressor

# Retention (optional)
S3_KEEP_DAYS=7                       # delete backups older than N days
```

Or see `docker-compose.yml` file to run this container with Docker.

### Retention details

- When `S3_KEEP_DAYS` is set, files matching `"${S3_NAME}-*.pgdump*"` older than the specified days are removed from the bucket (covers encrypted and plain backups).

## Cron backup with kubernetes

See `kubernetes-cronjob.yml` file.

## Authors & contributors

- [Standart AG, LLC](https://standart.lv/)
- [Pavel Khorikov](https://github.com/JargeZ)

#!/bin/bash
set -e
set -u
set -o pipefail

# Date function
get_date () {
    date +[%Y-%m-%d\ %H:%M:%S]
}

# Script
: ${GPG_KEYSERVER:='keyserver.ubuntu.com'}
: ${GPG_KEYID:=''}
: ${COMPRESS:='pigz'}
: ${COMPRESS_LEVEL:='9'}
: ${MAINTENANCE_DB:='postgres'}
: ${S3_KEEP_DAYS:=''}
: ${PGCONNECT_TIMEOUT:='10'}
START_DATE=`date +%Y-%m-%d_%H-%M-%S`

# Required envs
if [ -z "${PG_URI:-}" ] || [ -z "${S3_URI:-}" ] || [ -z "${S3_BUCK:-}" ] || [ -z "${S3_NAME:-}" ]; then
    echo "$(get_date) Missing required envs. Need PG_URI, S3_URI, S3_BUCK, S3_NAME"
    exit 1
fi

trap 'echo "$(get_date) Backup failed" >&2' ERR

if [ -z "$GPG_KEYID" ]
then
    echo "$(get_date) !WARNING! It's strongly recommended to encrypt your backups."
else
    echo "$(get_date) Preparing keys: importing from keyserver"
    # Retry import up to 3 times in case keyserver is unstable
    for i in 1 2 3; do
        if gpg --keyserver ${GPG_KEYSERVER} --keyserver-options timeout=10 --recv-keys ${GPG_KEYID}; then
            break
        fi
        echo "$(get_date) GPG import failed (attempt $i). Retrying..."
        sleep 2
        if [ "$i" = "3" ]; then
            echo "$(get_date) Failed to import GPG key after retries" >&2
            exit 1
        fi
    done
fi

echo "$(get_date) Postgres backup started"

export MC_HOST_backup=$S3_URI

mc mb backup/${S3_BUCK} --insecure || true

case $COMPRESS in
  'pigz' )
      COMPRESS_CMD='pigz -'${COMPRESS_LEVEL}
      COMPRESS_POSTFIX='.gz'
    ;;
  'xz' )
      COMPRESS_CMD='xz -'${COMPRESS_LEVEL}
      COMPRESS_POSTFIX='.xz'
    ;;
  'bzip2' )
      COMPRESS_CMD='bzip2 -'${COMPRESS_LEVEL}
      COMPRESS_POSTFIX='.bz2'
    ;;
  'lrzip' )
      COMPRESS_CMD='lrzip -l -L5'
      COMPRESS_POSTFIX='.lrz'
    ;;
  'brotli' )
      COMPRESS_CMD='brotli -'${COMPRESS_LEVEL}
      COMPRESS_POSTFIX='.br'
    ;;
  'zstd' )
      COMPRESS_CMD='zstd -'${COMPRESS_LEVEL}
      COMPRESS_POSTFIX='.zst'
    ;;
  * )
      echo "$(get_date) Invalid compression method: $COMPRESS. The following are available: pigz, xz, bzip2, lrzip, brotli, zstd"
      exit 1
    ;;
esac

dump_db(){
  DATABASE=$1
  # Ping database
  psql ${PG_URI%/}/${DATABASE} -v ON_ERROR_STOP=1 -c ''

  echo "$(get_date) Dumping database: $DATABASE"

  if [ -z "$GPG_KEYID" ]
  then
    pg_dump ${PG_URI%/}/${DATABASE} | $COMPRESS_CMD | mc pipe backup/${S3_BUCK}/${S3_NAME}-${START_DATE}-${DATABASE}.pgdump${COMPRESS_POSTFIX} --insecure
  else
    pg_dump ${PG_URI%/}/${DATABASE} | $COMPRESS_CMD \
    | gpg --encrypt -z 0 --recipient ${GPG_KEYID} --trust-model always \
    | mc pipe backup/${S3_BUCK}/${S3_NAME}-${START_DATE}-${DATABASE}.pgdump${COMPRESS_POSTFIX}.pgp --insecure
  fi
}

DB_NAME=${PG_URI##*/}
if [[ $DB_NAME == *"@"* ]]
then
  DB_NAME=""
fi

if [ -z "$DB_NAME" ]
then
  echo "$(get_date) No database selected. Running backup for all databases:"
  DB_LIST=$(psql ${PG_URI%/}/${MAINTENANCE_DB} -A -c "SELECT datname FROM pg_database WHERE datname NOT LIKE 'template%';" | head -n -1 | tail -n +2)
  for db in $DB_LIST; do
    dump_db "$db"
  done
else
  PG_URI=${PG_URI%$DB_NAME}
  dump_db "$DB_NAME"
fi

if [ -n "$S3_KEEP_DAYS" ]
then
	echo "$(get_date) Retention enabled: removing backups older than ${S3_KEEP_DAYS} days from S3"
	# Remove objects matching naming scheme and older than specified days
	# Matches both encrypted and non-encrypted backups due to '*.pgdump*'
	mc find backup/${S3_BUCK} \
		--insecure \
		--name "${S3_NAME}-*.pgdump*" \
		--older-than "${S3_KEEP_DAYS}d" \
		--exec "mc rm --force {} --insecure" || true
fi

echo "$(get_date) Postgres backup completed successfully"

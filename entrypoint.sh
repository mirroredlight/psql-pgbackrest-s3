#!/usr/bin/env bash

if [ "$RECOVERY" = "true" ]; then
  echo "recovery mode, waiting external commands..."
  tail -f /dev/null
  exit 0
fi

mkdir -p /etc/pgbackrest
cat /etc/pgbackrest-template/pgbackrest.conf | envsubst > /etc/pgbackrest/pgbackrest.conf
chown -R $PGUSER:$PGUSER /etc/pgbackrest

pgconf="$PGDATA/postgresql.conf"
hbaconf="$PGDATA/pg_hba.conf"

mkdir -p /var/run/postgresql && chown -R $PGUSER:$PGUSER /var/run/postgresql && chmod -R 775 /var/run/postgresql
mkdir -p $PGDATA && chown -R $PGUSER:$PGUSER $PGDATA && chmod -R 750 $PGDATA

# create db cluster if it's not exist
if [[ ! -f $PGDATA/PG_VERSION ]]; then
  gosu $PGUSER initdb --encoding=UTF8 --locale=C -D $PGDATA
fi

# init pgbackrest
if ! [ -d "/var/lock/pgbackrest" ]; then

  gosu $PGUSER pg_ctl start -o "-p $PGPORT -k /var/run/postgresql" -D $PGDATA
  echo "===================="
  cat /etc/pgbackrest/pgbackrest.conf
  echo "===================="
  rm -f /tmp/pgbackrest/*
  echo "===================="
  gosu $PGUSER pgbackrest --stanza=app --pg1-port=$PGPORT --log-level-console=info stanza-create
  gosu $PGUSER pg_ctl restart -o "-p $PGPORT -k /var/run/postgresql" -D $PGDATA

  gosu $PGUSER pgbackrest --stanza=app --pg1-port=$PGPORT --log-level-console=info check
  pgbackrest_check_result=$?

  if [ $pgbackrest_check_result -ne 0 ]; then
    echo "pgbackrest check failed."
    ls /tmp/pgbackrest/
    exit $pgbackrest_check_result
  fi

  gosu $PGUSER pg_ctl stop -o "-p $PGPORT -k /var/run/postgresql" -D $PGDATA

  mkdir -p /var/lock && chown -R $PGUSER:$PGUSER && gosu $PGUSER touch /var/lock/pgbackrest
fi

gosu $PGUSER "$@"

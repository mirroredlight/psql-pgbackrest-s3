#!/usr/bin/env bash
echo ""
echo "====================================================================="
echo " _____   _____ ____          _____ _  _______  ______  _____ _______ "
echo "|  __ \ / ____|  _ \   /\   / ____| |/ /  __ \|  ____|/ ____|__   __|"
echo "| |__) | |  __| |_) | /  \ | |    | ' /| |__) | |__  | (___    | |   "
echo "|  ___/| | |_ |  _ < / /\ \| |    |  < |  _  /|  __|  \___ \   | |   "
echo "| |    | |__| | |_) / ____ \ |____| . \| | \ \| |____ ____) |  | |   "
echo "|_|     \_____|____/_/    \_\_____|_|\_\_|  \_\______|_____/   |_|   "
echo "====================================================================="
echo ""

rm -f /usr/local/pgsql/data/postmaster.pid

# Function to start the PostgreSQL server
start_postgres() {
    gosu $PGUSER pg_ctl start -o "-p $PGPORT -k /var/run/postgresql" -D $PGDATA
}

# Function to stop the PostgreSQL server
stop_postgres() {
    gosu $PGUSER pg_ctl stop -o "-p $PGPORT -k /var/run/postgresql" -D $PGDATA
}

# Function to initialize pgBackRest
initialize_pgbackrest() {
    start_postgres
    echo "===================="
    cat /etc/pgbackrest/pgbackrest.conf
    echo "===================="
    rm -f /tmp/pgbackrest/*
    echo "===================="
    sleep 5
    gosu $PGUSER pgbackrest --stanza=app --pg1-port=$PGPORT --log-level-console=info stanza-create
    stop_postgres
    start_postgres
    gosu $PGUSER pgbackrest --stanza=app --pg1-port=$PGPORT --log-level-console=info check
    stop_postgres
}

# Setup directories and permissions
prepare_directories() {
    mkdir -p /etc/pgbackrest
    cat /etc/pgbackrest-template/pgbackrest.conf | envsubst > /etc/pgbackrest/pgbackrest.conf
    chown -R $PGUSER:$PGUSER /etc/pgbackrest
    mkdir -p /var/run/postgresql && chown -R $PGUSER:$PGUSER /var/run/postgresql && chmod -R 775 /var/run/postgresql
    mkdir -p $PGDATA && chown -R $PGUSER:$PGUSER $PGDATA && chmod -R 750 $PGDATA
}

# Initialize the database cluster
initialize_db_cluster() {
    if [[ ! -f $PGDATA/PG_VERSION ]]; then
        gosu $PGUSER initdb --encoding=UTF8 --locale=C -D $PGDATA
    fi
}

main() {
    prepare_directories
    initialize_db_cluster

    if ! [ -d "/var/lock/pgbackrest" ]; then
        initialize_pgbackrest
        mkdir -p /var/lock && chown -R $PGUSER:$PGUSER /var/lock && gosu $PGUSER touch /var/lock/pgbackrest
    fi
    gosu $PGUSER "$@"
}


# Check if recovery mode is enabled
if [ "$RECOVERY" = "true" ]; then
    echo "Recovery mode, waiting for external commands..."
    tail -f /dev/null
    exit 0
fi

main "$@"
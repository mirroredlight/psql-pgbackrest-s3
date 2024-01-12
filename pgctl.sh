#!/bin/bash

show_usage() {
    echo "Usage: $0 [list|restore|backup]"
}

list_backups() {
    docker compose exec db pgbackrest --stanza=app --log-level-console=info info
}

restore_backup() {
    local restore_id=$1
    docker compose stop db
    docker compose start recovery
    docker compose exec recovery pgbackrest --stanza=app --log-level-console=info --delta --set=$restore_id restore
    docker compose stop recovery
    docker compose start db
}

create_backup() {
    docker compose exec db pgbackrest --stanza=app --log-level-console=info backup
}

if [[ $# -eq 0 ]]; then
    show_usage
    exit 1
fi

case $1 in
    list)
        list_backups
        ;;
    restore)
        if [[ -z $2 ]]; then
            echo "Restore command requires a restore_id."
            show_usage
            exit 1
        fi
        restore_backup $2
        ;;
    backup)
        create_backup
        ;;
    *)
        echo "Invalid command: $1"
        show_usage
        exit 1
        ;;
esac

FROM debian:bookworm

LABEL org.opencontainers.image.source="https://github.com/mirroredlight/psql-pgbackrest-s3"
LABEL org.opencontainers.image.title="psql backups to s3"
LABEL org.opencontainers.image.description="PostgreSQL server with pgBackRest installed for backups to s3"

ENV LANG=en_US.utf8
ENV PGVERSION=15.5
ENV PGPORT=5432
ENV PGUSER=postgres
ENV PGDATA=/usr/local/pgsql/data
ENV PG_BACKREST_VERSION=2.49
ENV PGUSER_UID=70
ENV PGUSER_GID=70

RUN groupadd -g $PGUSER_GID $PGUSER && \
    useradd -m -d /home/$PGUSER -s /bin/bash -g $PGUSER -u $PGUSER_UID $PGUSER

RUN apt-get update

RUN apt-get install -y build-essential wget pkg-config libpcre3-dev \
    libssl-dev zlib1g-dev libicu-dev libreadline-dev libxslt1-dev libxml2-dev \
    bzip2 libz-dev uuid-dev linux-headers-amd64 \
    tzdata libyaml-dev util-linux libcrypto++8 libpq5 \
    git bash python3 python3-pip libbz2-dev libxml2 lz4 libzstd-dev \
    postgresql-server-dev-all sudo gosu gettext-base

RUN ln -sf python3 /usr/bin/python && \
    mkdir -p /downloads

RUN cd /downloads && \
    wget https://github.com/pgbackrest/pgbackrest/archive/release/$PG_BACKREST_VERSION.tar.gz && \
    tar xf $PG_BACKREST_VERSION.tar.gz && \
    rm $PG_BACKREST_VERSION.tar.gz

RUN cd /downloads/pgbackrest-release-$PG_BACKREST_VERSION/src && \
    ./configure && make && cp pgbackrest /usr/bin/ && \
    rm -rf /downloads/pgbackrest-release-$PG_BACKREST_VERSION

RUN cd /downloads && \
    wget https://ftp.postgresql.org/pub/source/v$PGVERSION/postgresql-$PGVERSION.tar.gz && \
    tar -xf postgresql-$PGVERSION.tar.gz && \
    rm postgresql-$PGVERSION.tar.gz

RUN cd /downloads/postgresql-$PGVERSION && \
    ./configure --with-icu --with-openssl --with-libxml --with-libxslt --with-uuid=e2fs && \
    make world && make install-world && \
    rm -rf /downloads/postgresql-$PGVERSION

RUN apt-get purge -y --auto-remove build-essential

RUN chmod -R 755 /usr/bin/pgbackrest

RUN mkdir -p /var/log/pgbackrest && \
    chown -R $PGUSER:$PGUSER /var/log/pgbackrest && \
    chmod -R 777 /var/log/pgbackrest

RUN mkdir -p /var/lib/pgbackrest && \
    chown -R $PGUSER:$PGUSER /var/lib/pgbackrest && \
    chmod -R 750 /var/lib/pgbackrest

RUN mkdir -p /var/spool/pgbackrest && \
    chown -R $PGUSER:$PGUSER /var/spool/pgbackrest && \
    chmod -R 750 /var/spool/pgbackrest

RUN mkdir -p /var/run/postgresql && \
    chown -R $PGUSER:$PGUSER /var/run/postgresql && \
    chmod -R 775 /var/run/postgresql

RUN mkdir -p $PGDATA && \
    chown -R $PGUSER:$PGUSER $PGDATA && \
    chmod -R 750 $PGDATA

STOPSIGNAL SIGINT

RUN sed -i "$ a listen_addresses = '*'" /usr/local/pgsql/share/postgresql.conf.sample
RUN sed -i "$ a port = 5432" /usr/local/pgsql/share/postgresql.conf.sample
RUN sed -i "$ a max_connections = 100" /usr/local/pgsql/share/postgresql.conf.sample
RUN sed -i "$ a unix_socket_directories = '/var/run/postgresql'" /usr/local/pgsql/share/postgresql.conf.sample
RUN sed -i "$ a shared_buffers = 128MB" /usr/local/pgsql/share/postgresql.conf.sample
RUN sed -i "$ a wal_level = replica" /usr/local/pgsql/share/postgresql.conf.sample
RUN sed -i "$ a max_wal_size = 1GB" /usr/local/pgsql/share/postgresql.conf.sample
RUN sed -i "$ a min_wal_size = 80MB" /usr/local/pgsql/share/postgresql.conf.sample
RUN sed -i "$ a archive_mode = on" /usr/local/pgsql/share/postgresql.conf.sample
RUN sed -i "$ a archive_command = 'pgbackrest --stanza=app archive-push %p'" /usr/local/pgsql/share/postgresql.conf.sample
RUN sed -i "$ a max_wal_senders = 3" /usr/local/pgsql/share/postgresql.conf.sample
RUN sed -i "$ a log_line_prefix = ''" /usr/local/pgsql/share/postgresql.conf.sample
RUN sed -i "$ a log_timezone = 'Etc/UTC'" /usr/local/pgsql/share/postgresql.conf.sample

RUN sed -i "$ a host all all all trust" /usr/local/pgsql/share/pg_hba.conf.sample

ENV PATH=/usr/local/pgsql/bin:$PATH

COPY ./entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

#!/bin/bash

set -e

role=$1
pg_data=/var/lib/postgresql/9.5/main

P="sudo -u postgres"
# Place configs
cd /code
mv /etc/postgresql /etc/postgresql.bak
cp -r postgresql-$role /etc/postgresql
chown -R postgres:postgres /etc/postgresql/*

if [ $role == master ]; then

    echo Create archive folder
    $P mkdir "$pg_data/archive"
	echo Start server
	/etc/init.d/postgresql start
    echo Create replicator user
	$P psql -c "CREATE USER replicator REPLICATION LOGIN ENCRYPTED PASSWORD 'thepassword';"
    echo Master ready
	echo '' | nc -l 9001
fi


if [ $role == slave ]; then
    echo Creating .pgpass
	$P bash -c 'echo "postgres-shards-master:*:*:*:thepassword" > ~postgres/.pgpass && chmod 600 ~postgres/.pgpass'

	echo Waiting for master
	./wait-for-it.sh postgres-shards-master:9001 -s -t 0

    echo Starting base backup as replicator
    $P rm -rf $pg_data
    $P pg_basebackup -h postgres-shards-master -D $pg_data -U replicator -v -X stream

    echo Writing recovery.conf file
	cp /etc/postgresql/9.5/main/recovery.conf $pg_data/

	echo Start server
	/etc/init.d/postgresql start
    
    echo Slave ready
fi



# Monitor
cd /var/log
tail -f postgresql/postgresql-9.5-main.log


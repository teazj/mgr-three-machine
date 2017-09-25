#!/bin/bash

chown -R mysql:mysql /var/lib/mysql && chown mysql:mysql /var/log/mysqld.log                
[ -d /var/lib/mysql ] && mysqld --initialize-insecure --user=mysql --basedir=/usr/sbin --datadir=/var/lib/mysql

exec $1
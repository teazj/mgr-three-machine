#!/bin/bash
sysbench --test=oltp --oltp-table-size=4000 --oltp-read-only=off --init-rng=on --num-threads=5 --max-requests=0 --oltp-dist-type=uniform --max-time=36 --mysql-user=sbuser  --mysql-password='sbpass' --db-driver=mysql --mysql-port=6033 --mysql-table-engine=innodb  --mysql-host=127.0.0.1  --mysql-db=sbtest --oltp-tables-count=5 --report-interval=1 run

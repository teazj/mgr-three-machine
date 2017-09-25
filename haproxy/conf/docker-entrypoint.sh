#!/bin/bash
/usr/sbin/httpd -D FOREGROUND &
exec $1 $2 $3

#!/bin/bash
proxysql_user="admin"
proxysql_password="admin"
proxysql_host="127.0.0.1"
proxysql_port="6032"
readGroupId="1"
writeGroupId="0"
mgr1_ip=172.22.0.6
mgr2_ip=172.22.0.7
mgr3_ip=172.22.0.8

errFile=/var/lib/proxysql/checker.log

##mysql cmd
proxysql_cmd="mysql -u$proxysql_user -p$proxysql_password -h$proxysql_host -P$proxysql_port -Nse"
proxysql_sb="mysql -usbuser -psbpass -h 127.0.0.1 -Nse"


## now writegroup
write_hostname=$($proxysql_cmd "SELECT hostname FROM mysql_servers WHERE hostgroup_id = "$writeGroupId"")
$proxysql_cmd "SELECT hostname FROM mysql_servers WHERE hostgroup_id = "$writeGroupId"" >>$errFile


echo $write_hostname

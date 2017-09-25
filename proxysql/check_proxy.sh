#!/bin/bash
readGroupId="1"
writeGroupId="0"
mgr1_ip=172.22.0.6
mgr2_ip=172.22.0.7
mgr3_ip=172.22.0.8

errFile=/var/lib/proxysql/checker.log

##mysql cmd
proxysql_cmd="mysql -uadmin -padmin -h127.0.0.1 -P6032 -Nse"
proxysql_sb="mysql -usbuser -psbpass -h 127.0.0.1 -Nse"

## now writegroup
write_hostname=$($proxysql_cmd "SELECT hostname FROM mysql_servers WHERE hostgroup_id = $writeGroupId")
#hostgroups=$($proxysql_cmd "SELECT hostname FROM mysql_servers")

#DB status
mgr1(){
mgr1_status=$(mysql -usbuser -psbpass -h 172.22.0.6 --connect-timeout=3  -Nse "select member_state from performance_schema.replication_group_members where MEMBER_HOST='mgr1'")
if [ $mgr1_status == ONLINE ];then
    echo "mgr1 status is ok !!!" >> $errFile
    $proxysql_cmd "update mysql_servers set status='ONLINE' where hostname='172.22.0.6';"
else
    echo "mgr1 status is $mgr1_status !!!" >> $errFile
    $proxysql_cmd "update mysql_servers set status='OFFLINE_HARD' where hostname='172.22.0.6';"
fi
}

mgr2(){
mgr2_status=$(mysql -usbuser -psbpass -h 172.22.0.7 --connect-timeout=3  -Nse "select member_state from performance_schema.replication_group_members where MEMBER_HOST='mgr2'")
if [ $mgr2_status == ONLINE ];then
    echo "mgr2 status is ok !!!" >> $errFile
    $proxysql_cmd "update mysql_servers set status='ONLINE' where hostname='172.22.0.7';"
else
    echo "mgr2 status is $mgr2_status !!!" >> $errFile
    $proxysql_cmd "update mysql_servers set status='OFFLINE_HARD' where hostname='172.22.0.7';"
fi
}

mgr3(){
mgr3_status=$(mysql -usbuser -psbpass -h 172.22.0.8 --connect-timeout=3  -Nse "select member_state from performance_schema.replication_group_members where MEMBER_HOST='mgr3'")
if [ $mgr3_status == ONLINE ];then
    echo "mgr3 status is ok !!!" >> $errFile
    $proxysql_cmd "update mysql_servers set status='ONLINE' where hostname='172.22.0.8';"
else
    echo "mgr3 status is $mgr3_status !!!" >> $errFile
    $proxysql_cmd "update mysql_servers set status='OFFLINE_HARD' where hostname='172.22.0.8';"
fi
}

mgr1
mgr2
mgr3

#primary master

primary_master(){
write_hostname=$($proxysql_cmd "select hostname FROM mysql_servers where hostgroup_id=$writeGroupId and status='ONLINE'")
primary_mgr1=$(mysql -usbuser -psbpass -h 172.22.0.6 --connect-timeout=3  -Nse "select member_host from performance_schema.global_status JOIN performance_schema.replication_group_members WHERE variable_name = 'group_replication_primary_member' AND member_id=variable_value")
primary_mgr2=$(mysql -usbuser -psbpass -h 172.22.0.7 --connect-timeout=3  -Nse "select member_host from performance_schema.global_status JOIN performance_schema.replication_group_members WHERE variable_name = 'group_replication_primary_member' AND member_id=variable_value")
primary_mgr3=$(mysql -usbuser -psbpass -h 172.22.0.8 --connect-timeout=3  -Nse "select member_host from performance_schema.global_status JOIN performance_schema.replication_group_members WHERE variable_name = 'group_replication_primary_member' AND member_id=variable_value")


if [ $primary_mgr1 == mgr1 ];then
    $proxysql_cmd "update mysql_servers set hostgroup_id=0 where hostname='172.22.0.6'"
    $proxysql_cmd "update mysql_servers set hostgroup_id=1 where hostname='172.22.0.7'"
    $proxysql_cmd "update mysql_servers set hostgroup_id=1 where hostname='172.22.0.8'"
elif [ $primary_mgr2 == mgr2 ];then
    $proxysql_cmd "update mysql_servers set hostgroup_id=1 where hostname='172.22.0.6'"
    $proxysql_cmd "update mysql_servers set hostgroup_id=0 where hostname='172.22.0.7'"
    $proxysql_cmd "update mysql_servers set hostgroup_id=1 where hostname='172.22.0.8'"
elif [ $primary_mgr3 == mgr3 ];then
    $proxysql_cmd "update mysql_servers set hostgroup_id=1 where hostname='172.22.0.6'"
    $proxysql_cmd "update mysql_servers set hostgroup_id=1 where hostname='172.22.0.7'"
    $proxysql_cmd "update mysql_servers set hostgroup_id=0 where hostname='172.22.0.8'"
else
    echo "$primary_master is not find"
fi
}

primary_master

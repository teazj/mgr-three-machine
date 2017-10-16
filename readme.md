## mysql mgr docker环境


## 初始化数据库
	chown -R mysql:mysql /data/s1
	[ -d /data/s1 ] && /usr/sbin/mysqld --initialize-insecure --user=mysql --basedir=/usr/sbin --datadir=/data/s1
	/usr/sbin/mysqld --defaults-file=/data/my1.cnf --user=mysql 2>&1 &>/dev/null &

## mysql主设置
	SET SQL_LOG_BIN=0;
	CREATE USER rpl_user@'%';
	GRANT REPLICATION SLAVE ON *.* TO rpl_user@'%' IDENTIFIED BY 'rpl_pass';
	SET SQL_LOG_BIN=1;
	CHANGE MASTER TO MASTER_USER='rpl_user', MASTER_PASSWORD='rpl_pass' FOR CHANNEL 'group_replication_recovery';
	INSTALL PLUGIN group_replication SONAME 'group_replication.so';
	SHOW PLUGINS;
	SET GLOBAL group_replication_bootstrap_group=ON;
	START GROUP_REPLICATION;
	SET GLOBAL group_replication_bootstrap_group=OFF;
	SELECT * FROM performance_schema.replication_group_members;



## 从库设置
	SET SQL_LOG_BIN=0;
	CREATE USER rpl_user@'%';
	GRANT REPLICATION SLAVE ON *.* TO rpl_user@'%' IDENTIFIED BY 'rpl_pass';
	SET SQL_LOG_BIN=1;
	CHANGE MASTER TO MASTER_USER='rpl_user', MASTER_PASSWORD='rpl_pass' FOR CHANNEL 'group_replication_recovery';
	INSTALL PLUGIN group_replication SONAME 'group_replication.so';
	START GROUP_REPLICATION;
	SELECT * FROM performance_schema.replication_group_members;



## HA测试
	global
	    log 127.0.0.1   local3
	    maxconn 4096
	    user haproxy
	    group haproxy
	    daemon
	    debug

	listen mysql 0.0.0.0:3306
	    mode tcp
	    log global
	    retries 3
	    timeout connect 5000000000000ms
	    option redispatch
	    timeout client 2000000000000000ms
	    timeout server 200000000000000000ms
	    option tcplog
	    option clitcpka
	#    balance leastconn
	    balance roundrobin
	    server  S1 127.0.0.1:3316  check inter 2000 rise 2 fall 5 weight 5
	    server  S2 127.0.0.1:3326  check inter 2000 rise 2 fall 5 weight 5
	    server  S3 127.0.0.1:3336  check inter 2000 rise 2 fall 5 weight 5



## 查看轮询到那太服务器上
	mysql -h 127.0.0.1 -P 3306 -e "select @@PORT"


## 设置变量general_log以开启通用查询日志
	set @@global.general_log=1;
	set global general_log=1;


## 数据库操作
	update mysql.user set authentication_string=password('12wsxCDE#') where user='root' and Host = 'localhost';
	CREATE DATABASE IF NOT EXISTS test default charset utf8 COLLATE utf8_general_ci;
	use test
	CREATE TABLE `t3` (
	  `id` int(30) unsigned NOT NULL AUTO_INCREMENT,
	  `name` char(30) NOT NULL COMMENT 'name',
	  `sex` char(30) NOT NULL COMMENT 'sex',
	  PRIMARY KEY (`id`)
	) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;

	use test;
	insert into t3(name,sex) values('t1',11);


## 添加数据
	ab -c 5 -n 9999 http://localhost/update.php

## 查看数据
	ab -c 5 -n 9999 http://localhost/index.php

## 查看数据操作日志
	tail -f data/s3/mgr.log  | grep -v "COMMIT" | grep -v "BEGIN"


## 手动提交事务
	set autocommit=0;
	insert into test set name='123' where id=1;
	commit;


## 开始事务
	start transaction;
	update test set name="123" where id=1;
	commit;



## 单组模式补充

	查看单组
	show global status like 'group_replication_primary_member';
	show variables like '%group_replication_group_seeds%';


	SELECT member_host as "primary master"  FROM performance_schema.global_status JOIN performance_schema.replication_group_members  WHERE variable_name = 'group_replication_primary_member' AND member_id=variable_value;





	update performance_schema.global_status JOIN performance_schema.replication_group_members  WHERE variable_name = 'group_replication_primary_member' AND member_id=variable_value   set MEMBER_HOST="mgr1" ;


## 备份

[mysql]
name=mysql5.7.17
baseurl=http://repo.mysql.com/yum/mysql-5.7-community/el/7/x86_64/
enabled=1
gpgcheck=0

yum install mysql-community-common.x86_64  mysql-community-libs.x86_64  mysql-community-libs-compat.x86_64 mysql-community-client.x86_64  mysql-community-devel.x86_64   mysql-community-embedded.x86_64   mysql-community-embedded-compat.x86_64  mysql-community-embedded-devel.x86_64  mysql-community-server.x86_64  mysql-community-test.x86_64   -y

yum install http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm

yum -y install  perl-DBI  perl-core perl-CPAN perl-DBD-MySQL  perl-Digest-MD5 perl-TermReadKey perl-devel perl-Time-HiRes perl perl-devel libaio libaio-devel  percona-xtrabackup-24


	mysqldump -uroot -p --default-character-set=utf8 --routines --triggers --events --master-data=2 --all-databases>db_all_20150610.sql

	mysqlbackup --defaults-file=/etc/my.cnf --backup-image=/backups/my.mbi_`date +%d%m_%H%M` --backup-dir=/backups/backup_'date +%d%m_%H%M' --user=root -pmYsecr3t 		      --host=127.0.0.1 --no-history-logging backup-to-image






//全部数据库备份
innobackupex --user=root --password='12wsxCDE#' /data/backup/
 
//单数据库备份
innobackupex --user=root --password=123456 --database=backup_test /data/backup/
 
//多库
innobackupex--user=root --password=123456 --include='dba.*|dbb.*' /data/backup/
 
//多表
innobackupex --user=root --password=123456 --include='dba.tablea|dbb.tableb' /data/backup/
 
//数据库备份并压缩
log=zztx01_`date +%F_%H-%M-%S`.log
db=zztx01_`date +%F_%H-%M-%S`.tar.gz
innobackupex --user=root --stream=tar /data/backup  2>/data/backup/$log | gzip 1> /data/backup/$db
//不过注意解压需要手动进行，并加入 -i 的参数，否则无法解压出所有文件,疑惑了好长时间
 
//如果有错误可以加上  --defaults-file=/etc/my.cnf
2、还原

service mysqld stop
mv /data/mysql /data/mysql_bak && mkdir -p /data/mysql
 
//--apply-log选项的命令是准备在一个备份上启动mysql服务
innobackupex --defaults-file=/etc/my.cnf --user=root --apply-log /data/backup/2015-09-18_16-35-12
 
//--copy-back 选项的命令从备份目录拷贝数据,索引,日志到my.cnf文件里规定的初始位置
innobackupex --defaults-file=/etc/my.cnf --user=root --copy-back /data/backup/2015-09-18_16-35-12
 
chown -R mysql.mysql /data/mysq
service mysqld start
四、增量备份与还原

1、创建测试数据库和表


create database backup_test; //创建库
 
CREATE TABLE `backup` ( //创建表
`id` int(11) NOT NULL AUTO_INCREMENT ,
`name` varchar(20) NOT NULL DEFAULT '' ,
`create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ,
`del` tinyint(1) NOT NULL DEFAULT '0',
PRIMARY KEY (`id`)
) ENGINE=myisam DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;
2、增量备份


#--incremental：增量备份的文件夹
#--incremental-dir：针对哪个做增量备份
 
//第一次备份
mysql> INSERT INTO backup (name) VALUES ('xx'),('xxxx'); //插入数据
innobackupex  --user=root --incremental-basedir=/data/backup/2015-09-18_16-35-12 --incremental /data/backup/
 
//再次备份
mysql> INSERT INTO backup (name) VALUES ('test'),('testd'); //在插入数据
innobackupex --user=root --incremental-basedir=/data/backup/2015-09-18_18-05-20 --incremental /data/backup/
3、查看增量备份记录文件

[root@localhost 2015-09-18_16-35-12]# cat xtrabackup_checkpoints //全备目录下的文件
backup_type = full-prepared
from_lsn = 0 //全备起始为0
to_lsn = 23853959
last_lsn = 23853959
compact = 0
 
[root@localhost 2015-09-18_18-05-20]# cat xtrabackup_checkpoints //第一次增量备份目录下的文件
backup_type = incremental
from_lsn = 23853959
to_lsn = 23854112
last_lsn = 23854112
compact = 0
 
[root@localhost 2015-09-18_18-11-43]# cat xtrabackup_checkpoints //第二次增量备份目录下的文件
backup_type = incremental
from_lsn = 23854112
to_lsn = 23854712
last_lsn = 23854712
compact = 0
增量备份做完后，把backup_test这个数据库删除掉，drop database backup_test;这样可以对比还原后
4、增量还原

分为两个步骤
a.prepare
1
innobackupex --apply-log /path/to/BACKUP-DIR
此时数据可以被程序访问使用；可使用—use-memory选项指定所用内存以加快进度，默认100M；
b.recover
1
innobackupex --copy-back /path/to/BACKUP-DIR
从my.cnf读取datadir/innodb_data_home_dir/innodb_data_file_path等变量
先复制MyISAM表，然后是innodb表，最后为logfile；--data-dir目录必须为空
开始合并


innobackupex --apply-log --redo-only /data/backup/2015-09-18_16-35-12
innobackupex --apply-log --redo-only --incremental /data/backup/2015-09-18_16-35-12 --incremental-dir=/data/backup/2015-09-18_18-05-20
innobackupex --apply-log --redo-only --incremental /data/backup/2015-09-18_16-35-12 --incremental-dir=/data/backup/2015-09-18_18-11-43
 
#/data/backup/2015-09-18_16-35-12 全备份目录
#/data/backup/2015-09-18_18-05-20 第一次增量备份产生的目录
#/data/backup/2015-09-18_18-11-43 第二次增量备份产生的目录
恢复数据


service mysqld stop
innobackupex --copy-back /data/backup/2015-09-18_16-35-12
service mysqld start
五、innobackup 常用参数说明

--defaults-file
同xtrabackup的--defaults-file参数
--apply-log
对xtrabackup的--prepare参数的封装
--copy-back
做数据恢复时将备份数据文件拷贝到MySQL服务器的datadir ；
--remote-host=HOSTNAME
通过ssh将备份数据存储到进程服务器上；
--stream=[tar]
备 份文件输出格式, tar时使用tar4ibd , 该文件可在XtarBackup binary文件中获得.如果备份时有指定--stream=tar, 则tar4ibd文件所处目录一定要在$PATH中(因为使用的是tar4ibd去压缩, 在XtraBackup的binary包中可获得该文件)。
在 使用参数stream=tar备份的时候，你的xtrabackup_logfile可能会临时放在/tmp目录下，如果你备份的时候并发写入较大的话 xtrabackup_logfile可能会很大(5G+)，很可能会撑满你的/tmp目录，可以通过参数--tmpdir指定目录来解决这个问题。
--tmpdir=DIRECTORY
当有指定--remote-host or --stream时, 事务日志临时存储的目录, 默认采用MySQL配置文件中所指定的临时目录tmpdir
--redo-only --apply-log组,
强制备份日志时只redo ,跳过rollback。这在做增量备份时非常必要。
--use-memory=#
该参数在prepare的时候使用，控制prepare时innodb实例使用的内存量
--throttle=IOS
同xtrabackup的--throttle参数
--sleep=是给ibbackup使用的，指定每备份1M数据，过程停止拷贝多少毫秒，也是为了在备份时尽量减小对正常业务的影响，具体可以查看ibbackup的手册 ；
--compress[=LEVEL]
对备份数据迚行压缩，仅支持ibbackup，xtrabackup还没有实现；
--include=REGEXP
对 xtrabackup参数--tables的封装，也支持ibbackup。备份包含的库表，例如：--include="test.*"，意思是要备份 test库中所有的表。如果需要全备份，则省略这个参数；如果需要备份test库下的2个表：test1和test2,则写 成：--include="test.test1|test.test2"。也可以使用通配符，如：--include="test.test*"。
--databases=LIST
列出需要备份的databases，如果没有指定该参数，所有包含MyISAM和InnoDB表的database都会被备份；
--uncompress
解压备份的数据文件，支持ibbackup，xtrabackup还没有实现该功能；
--slave-info,
备 份从库, 加上--slave-info备份目录下会多生成一个xtrabackup_slave_info 文件, 这里会保存主日志文件以及偏移, 文件内容类似于:CHANGE MASTER TO MASTER_LOG_FILE='', MASTER_LOG_POS=0
--socket=SOCKET
指定mysql.sock所在位置，以便备份进程登录mysql.





## 技术交流
	QQ：58847393

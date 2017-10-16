## mysql  group  replication  生产使用方案

## 概述

	搭建数据库分布式集群；使用proxysql做数据转发；使用xtrabackup 数据备份；


## 知识要点

	mgr使用事务序列的方式保证每个集群节点数据一直性；proxysql 做负载均衡，高可用；xtrabackup 做数据库整备、增量备份；


## mgr集群的安装

	# yum源配置

	yum install http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm

	# 数控源配置

	[mysql]
	name=mysql5.7.19
	baseurl=http://repo.mysql.com/yum/mysql-5.7-community/el/7/x86_64/
	enabled=1
	gpgcheck=0

	# 安装依赖包、xtrabackup、数据库 这里是最大安装，可优化
	yum -y install  perl-DBI  perl-core perl-CPAN perl-DBD-MySQL  perl-Digest-MD5 perl-TermReadKey perl-devel perl-Time-HiRes perl perl-devel libaio libaio-devel  percona-xtrabackup-24
	yum install mysql-community-common.x86_64  mysql-community-libs.x86_64  mysql-community-libs-compat.x86_64 mysql-community-client.x86_64  mysql-community-devel.x86_64   mysql-community-embedded.x86_64   mysql-community-embedded-compat.x86_64  mysql-community-embedded-devel.x86_64  mysql-community-server.x86_64  mysql-community-test.x86_64   -y


	# 配置文件请参考conf下  my1.cnf   my2.cnf   my3.cnf


	# 数据库初始化

	chown -R mysql:mysql /var/lib/mysql && chown mysql:mysql /var/log/mysqld.log
	[ -d /var/lib/mysql ] && mysqld --initialize-insecure --user=mysql --basedir=/usr/sbin --datadir=/var/lib/mysql
	启动数据库：/usr/sbin/mysqld --defaults-file=/etc/my.cnf --user=mysql 2>&1 &>/dev/nul


	# 数据库设置
	#主设置

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


	# 从库设置

	SET SQL_LOG_BIN=0;
	CREATE USER rpl_user@'%';
	GRANT REPLICATION SLAVE ON *.* TO rpl_user@'%' IDENTIFIED BY 'rpl_pass';
	SET SQL_LOG_BIN=1;
	CHANGE MASTER TO MASTER_USER='rpl_user', MASTER_PASSWORD='rpl_pass' FOR CHANNEL 'group_replication_recovery';
	INSTALL PLUGIN group_replication SONAME 'group_replication.so';
	START GROUP_REPLICATION;
	SELECT * FROM performance_schema.replication_group_members;



	# 辅助命令

	# 查看轮询到那太服务器上
		mysql -h 127.0.0.1 -P 3306 -e "select @@PORT"


	# 设置变量general_log以开启通用查询日志
		set @@global.general_log=1;
		set global general_log=1;


	# 数据库操作
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


	# 添加数据
		ab -c 5 -n 9999 http://localhost/update.php

	# 查看数据
		ab -c 5 -n 9999 http://localhost/index.php

	# 查看数据操作日志
		tail -f data/s3/mgr.log  | grep -v "COMMIT" | grep -v "BEGIN"


	# 手动提交事务
		set autocommit=0;
		insert into test set name='123' where id=1;
		commit;


	# 开始事务
		start transaction;
		update test set name="123" where id=1;
		commit;

	# 单组模式补充

		查看单组
		show global status like 'group_replication_primary_member';
		show variables like '%group_replication_group_seeds%';
		SELECT member_host as "primary master"  FROM performance_schema.global_status JOIN performance_schema.replication_group_members  WHERE variable_name = 'group_replication_primary_member' AND member_id=variable_value;
		update performance_schema.global_status JOIN performance_schema.replication_group_members  WHERE variable_name = 'group_replication_primary_member' AND member_id=variable_value   set MEMBER_HOST="mgr1" ;


	# HA测试

		global
		    log 127.0.0.1   local3
		    maxconn 4096
		    user haproxy
		    group haproxy
		    daemon
		    debug
		listen administats
		        bind    0.0.0.0:8088
		        mode    http
		        option  httplog
		        stats   enable
		        stats   uri /ha
		        stats   refresh 30s
		        stats   realm Haproxy\ Statistics
		        stats   auth admin:123456
		        stats   hide-version
		        stats   admin if TRUE

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
		#    option httpchk
		#    balance leastconn
		    balance roundrobin
		    server  S1 mgr1:3306  check inter 2000 rise 2 fall 5 weight 5
		    server  S2 mgr2:3306  check inter 2000 rise 2 fall 5 weight 5


	# html 批量导入数据
	2.php  index.php


## 添加节点

	主节点mysqlbin删除的情况下，使用mysqldump备份导入节点，重新配置greps_replication


## 备份

	# mysqldump 备份

		mysqldump -uroot -p --default-character-set=utf8 --routines --triggers --events --master-data=2 --all-databases>db_all.sql

	# 全部数据库备份

		innobackupex --user=root --password='12wsxCDE#' /data/backup/

	# 单数据库备份

		innobackupex --user=root --password=123456 --database=backup_test /data/backup/

	# 多库
		innobackupex--user=root --password=123456 --include='dba.*|dbb.*' /data/backup/

	# 多表
		innobackupex --user=root --password=123456 --include='dba.tablea|dbb.tableb' /data/backup/

	# 数据库备份并压缩
		log=zztx01_`date +%F_%H-%M-%S`.log
		db=zztx01_`date +%F_%H-%M-%S`.tar.gz
		innobackupex --user=root --stream=tar /data/backup  2>/data/backup/$log | gzip 1> /data/backup/$db

	不过注意解压需要手动进行，并加入 -i 的参数，否则无法解压出所有文件
	如果有错误可以加上  --defaults-file=/etc/my.cnf

## 还原

		service mysqld stop
		mv /data/mysql /data/mysql_bak && mkdir -p /data/mysql

		//--apply-log选项的命令是准备在一个备份上启动mysql服务
		innobackupex --defaults-file=/etc/my.cnf --user=root --apply-log /data/backup/2015-09-18_16-35-12

		//--copy-back 选项的命令从备份目录拷贝数据,索引,日志到my.cnf文件里规定的初始位置
		innobackupex --defaults-file=/etc/my.cnf --user=root --copy-back /data/backup/2015-09-18_16-35-12

		chown -R mysql.mysql /data/mysq
		service mysqld start

## 增量备份与还原

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

## 恢复数据

		service mysqld stop
		innobackupex --copy-back /data/backup/2015-09-18_16-35-12
		service mysqld start

## innobackup 常用参数说明

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


##  proxysql安装

	wget https://github.com/sysown/proxysql/releases/download/v1.4.2/proxysql-1.4.2-1-centos7.x86_64.rpm
	yum localinstall proxysql-1.4.2-1-centos7.x86_64.rpm -y



## 登录proxysql

	mysql -uadmin -padmin -h 127.0.0.1 -P 6032
	\R Admin>
	show databases;
	show tables;
	select * from mysql_servers;
	select username,password,default_hostgroup from mysql_users;

##  在节点上创建监控ProxySQL的监控用户和业务用户

	CREATE USER 'ProxySQL'@'%' IDENTIFIED BY 'ProxySQLPa55';
	GRANT USAGE ON  *.* TO 'ProxySQL'@'%';
	CREATE USER 'prodba'@'%' IDENTIFIED BY '12wsxCDE#';
	GRANT ALL ON *.* TO 'prodba'@'%';
	FLUSH PRIVILEGES;

## ProxySQL配置
	配置文件请参考conf下proxysql.cnf
	proxysql未做读写分离，因后端做的是单主模式；

	insert into mysql_servers(hostgroup_id,hostname,port) values(0,'172.22.0.6',3306);
	insert into mysql_servers(hostgroup_id,hostname,port) values(1,'172.22.0.7',3306);
	insert into mysql_servers(hostgroup_id,hostname,port) values(1,'172.22.0.8',3306);

	设置写帐号
	INSERT INTO MySQL_users(username,password,default_hostgroup) VALUES ('prodba','12wsxCDE#',0);

	修改监控帐号
	UPDATE global_variables SET variable_value='ProxySQL' WHERE variable_name='mysql-monitor_username';
	UPDATE global_variables SET variable_value='ProxySQLPa55' WHERE variable_name='mysql-monitor_password';

## 添加监控
	监控脚本请查看conf下check_proxy.sh
	insert into scheduler(id, active, interval_ms, filename, arg1, arg2, arg3, arg4)  values(1, 1, 3000, '/var/lib/proxysql/check_proxy.sh', 0, 1, 1, '/var/lib/proxysql/checker.log');

##  保存配置
	LOAD SCHEDULER TO RUNTIME;
	SAVE SCHEDULER TO DISK;
	LOAD MYSQL SERVERS TO RUNTIME;
	LOAD MYSQL USERS TO RUNTIME;
	save mysql servers to disk;
	save mysql users to disk;

## proxysql登录mysql

	mysql -u sbuser -psbpass -h 127.0.0.1 -P 6033 -e "select @@hostname"
	mysql -u sbuser -psbpass -h 127.0.0.1 -P 6033

	show variables like '%port%';


	select * from sys.gr_member_routing_candidate_status\G

## sysbench 数据分析

	http://rpm.pbone.net/index.php3/stat/4/idpl/31976514/dir/centos_7/com/sysbench-0.4.12-12.el7.x86_64.rpm.html
	ftp://ftp.ntua.gr/pub/linux/centos/7.3.1611/cloud/x86_64/openstack-pike/common/sysbench-0.4.12-12.el7.x86_64.rpm

## 现在初始化数据库

	sysbench --test=oltp --oltp-table-size=4000 --oltp-read-only=off --init-rng=on --num-threads=5 --max-requests=0 --oltp-dist-type=uniform --max-time=36 --mysql-user=sbuser  --mysql-password='sbpass' --db-driver=mysql --mysql-port=6033 --mysql-table-engine=innodb  --mysql-host=127.0.0.1  --mysql-db=dbtest  prepare

## 使用sysbench来压测mysql

	sysbench --test=oltp --oltp-table-size=4000 --oltp-read-only=off --init-rng=on --num-threads=5 --max-requests=0 --oltp-dist-type=uniform --max-time=36 --mysql-user=sbuser  --mysql-password='sbpass' --db-driver=mysql --mysql-port=6033 --mysql-table-engine=innodb  --mysql-host=127.0.0.1  --mysql-db=test  run

## 查看proxysql为我们统计了那些信息呢。
	select * from stats_mysql_commands_counters where Total_cnt;

	select * from stats_mysql_query_digest order by sum_time DESC;




## 读写分离配置
	INSERT INTO mysql_query_rules(active,match_pattern,destination_hostgroup,apply) VALUES(1,'^SELECT.*FOR UPDATE$',0,1);
	INSERT INTO mysql_query_rules(active,match_pattern,destination_hostgroup,apply) VALUES(1,'^SELECT',1,1);
	LOAD MYSQL QUERY RULES TO RUNTIME;
	SAVE MYSQL QUERY RULES TO DISK;

	active表示是否启用这个sql路由项，
	match_pattern就是我们正则匹配项，
	destination_hostgroup表示我们要将该类sql转发到哪些mysql上面去，这里我们将select转发到group 1，也就是两个slave上。
	apply为1表示该正则匹配后，将不再接受其他匹配，直接转发。
	添加了sql路由，我们来看看是否实现了读写分离呢。


## 清空proxysql的query统计
	SELECT 1 FROM stats_mysql_query_digest_reset LIMIT 1;


## 查看执行结果
	select hostgroup hg,sum_time,count_star,digest_text from stats_mysql_query_digest order by Digest_text;

	可以看到，所有的非select*for update的查询语句都已经转发到slave了，也就是group 1.
	登录到slave上我们确实可以到很多查询已经切过来了。
	show processlist;

	show variables like "%port%";

	sysbench --test=oltp --oltp-table-size=4000 --oltp-read-only=off --init-rng=on --num-threads=5 --max-requests=0 --oltp-dist-type=uniform --max-time=36 --mysql-user=sbuser  --mysql-password='sbpass' --db-driver=mysql --mysql-port=6033 --mysql-table-engine=innodb  --mysql-host=127.0.0.1  --mysql-db=test  run





## 查询重写
	# 配置

	查询重写这种东西，对于线上环境紧急故障处理还是很有用处的。如果定位到了问题所在，必须修改SQL，时间紧急，让应用重新发布上线是不太现实了，这时查询重写这个东西就非常有用了。
	举个简单的例子
	SELECT DISTINCT c FROM sbtest1 WHERE id BETWEEN ? AND ? ORDER BY c
	这类SQL是有优化余地的，我们可以去掉ORDER BY c，多此一举，因为在做DISTINCT时我们已经做了排序。需要改成如下模式

	SELECT DISTINCT c FROM sbtest1 WHERE id BETWEEN ? AND ?
	其实查询重写的实现在proxysql中也实现为正则匹配替换。是不是非常赞，不需要非常复杂的算法就实现了，非常赞，用户可控度也大，用着非常舒服。
	我们编辑一条SQL路由规则。

	INSERT INTO mysql_query_rules (active,match_pattern,replace_pattern,apply) VALUES (1,'DISTINCT(.*)ORDER BY c','DISTINCT\1',1);
	这条规则什么意思呢，这条路由规则表示当proxysql匹配到DISTINCT<若干字符>ORDER BY c这个模式后，就将这个模式的ORDER BY c去掉。那么DISTINCT\1中的\1是什么意思呢，玩过sed的同学很快就反应过来，这不就是向前引用么，哈哈答对了。举个例子你就明白了。
	假如我们有这样一个文件:

	[root@hpc01 ~]$ cat aaa
	,90909
	,dasfsdfssd98908
	我们想把每行的逗号去掉，我们可以利用sed的向前引用:

	[root@hpc01 ~]$ sed "s/,\(.*\)/\1/g" aaa
	90909
	dasfsdfssd98908
	逗号后面的所有字符用\(.*\)表示，在后面替换我们用\1表示这部分。sed最大支持到\9，还是很强大的。如果实在不明白什么意思，推荐学习学习《sed与awk》。反正要玩proxysql正则表达式要玩得溜溜的。
	还要注意，我们要重写的selete语句，你可曾记得，我们已经将所有非seletc* from update语句已经重定向到slave，也就是select语句已经有了一条路由规则了。而且那条路由已经将apply字段设为1，也就是不再接受其他路由规则。好，我们需要更改apply字段才可以使这条规则生效。

	update mysql_query_rules set apply=0 where match_pattern='^SELECT';
	使配置生效

	LOAD MYSQL QUERY RULES TO RUNTIME;
	SAVE MYSQL QUERY RULES TO DISK;
	注意，以上配置都是在proxysql中操作的，别跑错了跑到数据库中搞啊。

	# 验证配置
	首先清空以前的统计信息，不然混在一起，无法辨认。

	admin@127.0.0.1 [(none)] 03:16:37>>>SELECT 1 FROM stats_mysql_query_digest_reset LIMIT 1;
	+---+
	| 1 |
	+---+
	| 1 |
	+---+
	1 row in set (0.01 sec)
	直接使用sysbench压测
	然后查看proxysql统计信息。

	select hostgroup hg,sum_time,count_star,digest_text from stats_mysql_query_digest order by sum_time DESC;



## Nagios监控

	查看groups状态
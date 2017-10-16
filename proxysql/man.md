## proxysql软件地址
	https://github.com/sysown/proxysql/releases

## 安装
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
	将数据库和数据库相关用户配置进ProxySQL。
	这些命令是在ProxySQL中执行的。

	insert into mysql_servers(hostgroup_id,hostname,port) values(0,'172.22.0.6',3306);
	insert into mysql_servers(hostgroup_id,hostname,port) values(1,'172.22.0.7',3306);
	insert into mysql_servers(hostgroup_id,hostname,port) values(1,'172.22.0.8',3306);

	INSERT INTO MySQL_users(username,password,default_hostgroup) VALUES ('prodba','12wsxCDE#',0);
	UPDATE global_variables SET variable_value='ProxySQL' WHERE variable_name='MySQL-monitor_username';
	UPDATE global_variables SET variable_value='ProxySQLPa55' WHERE variable_name='MySQL-monitor_password';

## 添加监控
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


3.查询重写
3.1配置
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
3.2验证配置
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
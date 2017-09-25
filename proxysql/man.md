## proxysql软件地址
	https://github.com/sysown/proxysql/releases

## 安装
	wget https://github.com/sysown/proxysql/releases/download/v1.4.2/proxysql-1.4.2-1-centos7.x86_64.rpm
	yum localinstall proxysql-1.4.2-1-centos7.x86_64.rpm -y



## 登录proxysql
	mysql -uadmin -padmin -h 127.0.0.1 -P 6032
	mysql -uadmin -padmin -h127.0.0.1 -P6032 --prompt=' \R admin>'
	\R Admin>
	show databases;
	show tables;
	select * from mysql_servers;
	select username,password,default_hostgroup from mysql_users;


##  在节点上创建监控ProxySQL的监控用户和业务用户
	CREATE USER 'ProxySQL'@'%' IDENTIFIED BY 'ProxySQLPa55';
	GRANT select ON  *.* TO 'ProxySQL'@'%';
	CREATE USER 'sbuser'@'%' IDENTIFIED BY 'sbpass';
	GRANT ALL ON * . * TO 'sbuser'@'%';
	FLUSH PRIVILEGES;



## ProxySQL配置
	将数据库和数据库相关用户配置进ProxySQL。
	这些命令是在ProxySQL中执行的。se

	insert into mysql_servers(hostgroup_id,hostname,port) values(0,'172.22.0.6',3306);
	insert into mysql_servers(hostgroup_id,hostname,port) values(1,'172.22.0.7',3306);
	insert into mysql_servers(hostgroup_id,hostname,port) values(1,'172.22.0.8',3306);

	select hostgroup_id,hostname,port from mysql_servers;

	INSERT INTO mysql_users(username,password,default_hostgroup) VALUES ('sbuser','sbpass',0);
	UPDATE global_variables SET variable_value='ProxySQL' WHERE variable_name='mysql-monitor_username';
	UPDATE global_variables SET variable_value='ProxySQLPa55' WHERE variable_name='mysql-monitor_password';

	SET mysql-monitor_username='ProxySQL';
	SET mysql-monitor_password='ProxySQLPa55';
	SET mysql-connect_timeout_server_max=20000000;
	SELECT * FROM monitor.mysql_server_connect_log ORDER BY time_start_us DESC LIMIT 10;

	select * from mysql_users\G
	select * from stats.stats_mysql_query_digest_reset limit 1;

##  保存配置
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

## 下面这个sql在proxysql是专门清空stats_mysql_query_digest表的

	SELECT 1 FROM stats_mysql_query_digest_reset LIMIT 1;

## 现在初始化数据库

	sysbench --test=/usr/share/sysbench/tests/include/oltp_legacy/oltp.lua  --oltp-table-size=10000 --oltp-read-only=off --init-rng=on --num-threads=5 --max-requests=0 --oltp-dist-type=uniform --max-time=36 --mysql-user=sbuser  --mysql-password='sbpass' --db-driver=mysql  --mysql-table-engine=innodb  --mysql-host=127.0.0.1  --mysql-db=sbtest   prepare

## 使用sysbench来压测mysql

	sysbench --test=/usr/share/sysbench/tests/include/oltp_legacy/oltp.lua  --oltp-table-size=4000 --oltp-read-only=off --init-rng=on --num-threads=5 --max-requests=0 --oltp-dist-type=uniform --max-time=36 --mysql-user=sbuser  --mysql-password='sbpass' --db-driver=mysql  --mysql-table-engine=innodb  --mysql-host=127.0.0.1  --mysql-db=sbtest run


## 清空测试数据

	sysbench --num-threads=16 --test=oltp --mysql-table-engine=innodb --db-driver=mysql  --mysql-host=127.0.0.1  --mysql-db=sbtest --oltp-table-size=500000 --mysql-user=sbuser  --mysql-password='sbpass'  cleanup


## 查看proxysql为我们统计了那些信息呢。
	select * from stats_mysql_commands_counters where Total_cnt;

	select * from stats_mysql_query_digest order by sum_time desc;

	select hostgroup hg,sum_time,count_star,digest_text from stats_mysql_query_digest order by Digest_text;


## 读写分离配置
	INSERT INTO mysql_query_rules(active,match_pattern,destination_hostgroup,apply) VALUES(1,'^SELECT.*FOR UPDATE$',0,1);
	INSERT INTO mysql_query_rules (active, match_pattern, destination_hostgroup, cache_ttl) VALUES (1, '^SELECT .* FOR UPDATE', 0, NULL);
	INSERT INTO mysql_query_rules(active,match_pattern,destination_hostgroup,apply) VALUES(1,'^SELECT',1,1);
	INSERT INTO mysql_query_rules (active, match_pattern, destination_hostgroup, cache_ttl) VALUES (1, '^SELECT .*', 1, NULL);

	设置读写hostgroup
	INSERT INTO mysql_replication_hostgroups (writer_hostgroup, reader_hostgroup) VALUES (0, 1);

	添加读写分离
	INSERT INTO mysql_query_rules (active, match_pattern, destination_hostgroup, cache_ttl, apply) VALUES (1, '^SELECT c FROM sbtest[0-9]{1,2} WHERE id=.*', 1, 1000, 1);

	查看分离条目
	SELECT rule_id, match_pattern, hits FROM mysql_query_rules LEFT JOIN stats_mysql_query_rules USING (rule_id);
	LOAD MYSQL QUERY RULES TO RUNTIME;
	LOAD MYSQL USERS TO RUNTIME;
	SAVE MYSQL USERS TO DISK;
	LOAD MYSQL QUERY RULES TO RUNTIME;
	SAVE MYSQL QUERY RULES TO DISK;
	LOAD MYSQL SERVERS TO RUNTIME;
	SAVE MYSQL SERVERS TO DISK;

	active表示是否启用这个sql路由项，
	match_pattern就是我们正则匹配项，
	destination_hostgroup表示我们要将该类sql转发到哪些mysql上面去，这里我们将select转发到group 1，也就是两个slave上。
	apply为1表示该正则匹配后，将不再接受其他匹配，直接转发。
	添加了sql路由，我们来看看是否实现了读写分离呢。


## 清空proxysql的query统计
	SELECT 1 FROM stats_mysql_query_digest_reset LIMIT 1;


## 数据统计模式
	SHOW TABLES FROM stats;

## 查看执行结果
	select hostgroup hg,sum_time,count_star,digest_text from stats_mysql_query_digest order by Digest_text;
	select hostgroup, digest_text, count_star, sum_time, min_time, max_time from stats_mysql_query_digest order by sum_time desc LIMIT 10;

	可以看到，所有的非select*for update的查询语句都已经转发到slave了，也就是group 1.
	登录到slave上我们确实可以到很多查询已经切过来了。
	show processlist;

	show variables like "%port%";

	SELECT DISTINCT c FROM sbtest16 WHERE id BETWEEN ? AND ?+? ORDER BY c
	SELECT DISTINCT c FROM sbtest16 WHERE id = ?+? ORDER BY c
	INSERT INTO mysql_query_rules (active, match_pattern, replace_pattern, destination_hostgroup, apply) VALUES (1, '^SELECT DISTINCT c FROM sbtest([0-9]{1,2}) WHERE id BETWEEN ([0-9]+) AND



insert into scheduler(id, active, interval_ms, filename, arg1, arg2, arg3, arg4)  values(1, 1, 1000, '/var/lib/proxysql/check_proxy.sh', 0, 1, 1, '/var/lib/proxysql/checker.log');

LOAD SCHEDULER TO RUNTIME;
SAVE SCHEDULER TO DISK;







datadir="/var/lib/proxysql"

admin_variables =
{
        admin_credentials="admin:admin"
        mysql_ifaces="0.0.0.0:6032"
        refresh_interval=2000
#       cluster_username="sbuser"
#       cluster_password="sbpass"
}

mysql_variables=
{
        threads=2
        max_connections=2048
        default_query_delay=0
        default_query_timeout=10000
        poll_timeout=2000
        interfaces="0.0.0.0:3306"
        default_schema="information_schema"
        stacksize=1048576
        connect_timeout_server=10000
        monitor_history=60000
        monitor_connect_interval=20000
        monitor_ping_interval=10000
        ping_timeout_server=200
        commands_stats=true
        sessions_sort=true
        monitor_username="ProxySQ"
        monitor_password="ProxySQLPa55"
}

mysql_servers =
(
    {
            address = "172.22.0.6"
            port = 3306
            hostgroup = 1
            max_connections = 5000
            weight = 5000
    },
    {
            address = "172.22.0.7"
            port = 3306
            hostgroup = 1
            max_connections = 5000
            weight = 5000
    },
    {
            address = "172.22.0.8"
            port = 3306
            hostgroup = 0
            max_connections = 5000
            weight = 5000
            max_replication_lag = 10
    }
)

mysql_users:
(
        {
                username = "sbuser"
                password = "sbpass"
                default_hostgroup = 0
                max_connections=15000
                default_schema="percona"
                active = 1
        }
)
mysql_query_rules:
(
        {
                rule_id=1
                active=1
                match_pattern="^SELECT .*$"
                destination_hostgroup=1
                apply=1
        },
        {
                rule_id=2
                active=1
                match_pattern="^SELECT .* FOR UPDATE$"
                destination_hostgroup=0
                apply=1
        }
)

mysql_replication_hostgroups=
(
        {
                writer_hostgroup=0
                reader_hostgroup=1
                comment="percona repl 1"
        }
)









通用选项:
  --num-threads=N   创建测试线程的数目。默认为1.
  --max-requests=N   请求的最大数目。默认为10000，0代表不限制。
  --max-time=N   最大执行时间，单位是s。默认是0,不限制。
  --forced-shutdown=STRING  超过max-time强制中断。默认是off。]
  --thread-stack-size=SIZE   每个线程的堆栈大小。默认是32K。
  --init-rng=[on|off]  在测试开始时是否初始化随机数发生器。默认是off。
  --test=STRING      指定测试项目名称。
  --debug=[on|off]    是否显示更多的调试信息。默认是off。
  --validate=[on|off]   在可能情况下执行验证检查。默认是off。
测试项目:
  fileio - File I/O test
  cpu - CPU performance test
  memory - Memory functions speed test
  threads - Threads subsystem performance test
  mutex - Mutex performance test(互斥性能测试)
  oltp - OLTP test,我们的测试主角。

指令: prepare(测试前准备工作) run(正式测试) cleanup(测试后删掉测试数据) help version

See 'sysbench --test=<name> help' for a list of options for each test. 查看每个测试项目的更多选项列表。

[root@localhost bin]# sysbench --test=fileio help
  --file-num=N   创建测试文件的数量。默认是128
  --file-block-size=N  测试时文件块的大小。默认是16384(16K)
  --file-total-size=SIZE   测试文件的总大小。默认是2G
  --file-test-mode=STRING  文件测试模式{seqwr(顺序写), seqrewr(顺序读写), seqrd(顺序读), rndrd(随机读), rndwr(随机写), rndrw(随机读写)}
  --file-io-mode=STRING   文件操作模式{sync(同步),async(异步),fastmmap(快速map映射),slowmmap(慢map映射)}。默认是sync
  --file-extra-flags=STRING   使用额外的标志来打开文件{sync,dsync,direct} 。默认为空
  --file-fsync-freq=N   执行fsync()的频率。(0 – 不使用fsync())。默认是100
  --file-fsync-all=[on|off] 每执行完一次写操作就执行一次fsync。默认是off
  --file-fsync-end=[on|off] 在测试结束时才执行fsync。默认是on
  --file-fsync-mode=STRING  使用哪种方法进行同步{fsync, fdatasync}。默认是fsync
  --file-merged-requests=N   如果可以，合并最多的IO请求数(0 – 表示不合并)。默认是0
  --file-rw-ratio=N     测试时的读写比例。默认是1.5

 

[root@localhost bin]# sysbench --test=cpu help
  --cpu-max-prime=N  最大质数发生器数量。默认是10000
[root@localhost bin]# ./sysbench --test=memory help
  --memory-block-size=SIZE  测试时内存块大小。默认是1K
  --memory-total-size=SIZE    传输数据的总大小。默认是100G
  --memory-scope=STRING    内存访问范围{global,local}。默认是global
  --memory-hugetlb=[on|off]  从HugeTLB池内存分配。默认是off
  --memory-oper=STRING     内存操作类型。{read, write, none} 默认是write
  --memory-access-mode=STRING存储器存取方式{seq,rnd} 默认是seq

[root@localhost bin]# sysbench --test=threads help
  --thread-yields=N   每个请求产生多少个线程。默认是1000
  --thread-locks=N    每个线程的锁的数量。默认是8

[root@localhost bin]# sysbench --test=mutex help
  --mutex-num=N    数组互斥的总大小。默认是4096
  --mutex-locks=N    每个线程互斥锁的数量。默认是50000
  --mutex-loops=N    内部互斥锁的空循环数量。默认是10000

[root@localhost bin]# sysbench --test=oltp help
oltp options:
  --oltp-test-mode=STRING    执行模式{simple,complex(advanced transactional),nontrx(non-transactional),sp}。默认是complex
  --oltp-reconnect-mode=STRING 重新连接模式{session(不使用重新连接。每个线程断开只在测试结束),transaction(在每次事务结束后重新连接),query(在每个SQL语句执行完重新连接),random(对于每个事务随机选择以上重新连接模式)}。默认是session
  --oltp-sp-name=STRING   存储过程的名称。默认为空
  --oltp-read-only=[on|off]  只读模式。Update，delete，insert语句不可执行。默认是off
  --oltp-skip-trx=[on|off]   省略begin/commit语句。默认是off
  --oltp-range-size=N      查询范围。默认是100
  --oltp-point-selects=N          number of point selects [10]
  --oltp-simple-ranges=N          number of simple ranges [1]
  --oltp-sum-ranges=N             number of sum ranges [1]
  --oltp-order-ranges=N           number of ordered ranges [1]
  --oltp-distinct-ranges=N        number of distinct ranges [1]
  --oltp-index-updates=N          number of index update [1]
  --oltp-non-index-updates=N      number of non-index updates [1]
  --oltp-nontrx-mode=STRING   查询类型对于非事务执行模式{select, update_key, update_nokey, insert, delete} [select]
  --oltp-auto-inc=[on|off]      AUTO_INCREMENT是否开启。默认是on
  --oltp-connect-delay=N     在多少微秒后连接数据库。默认是10000
  --oltp-user-delay-min=N    每个请求最短等待时间。单位是ms。默认是0
  --oltp-user-delay-max=N    每个请求最长等待时间。单位是ms。默认是0
  --oltp-table-name=STRING  测试时使用到的表名。默认是sbtest
  --oltp-table-size=N         测试表的记录数。默认是10000
  --oltp-dist-type=STRING    分布的随机数{uniform(均匀分布),Gaussian(高斯分布),special(空间分布)}。默认是special
  --oltp-dist-iter=N    产生数的迭代次数。默认是12
  --oltp-dist-pct=N    值的百分比被视为'special' (for special distribution)。默认是1
  --oltp-dist-res=N    ‘special’的百分比值。默认是75

General database options:
  --db-driver=STRING  指定数据库驱动程序('help' to get list of available drivers)
  --db-ps-mode=STRING编制报表使用模式{auto, disable} [auto]
Compiled-in database drivers:
    mysql - MySQL driver
mysql options:
  --mysql-host=[LIST,...]       MySQL server host [localhost]
  --mysql-port=N                MySQL server port [3306]
  --mysql-socket=STRING         MySQL socket
  --mysql-user=STRING           MySQL user [sbtest]
  --mysql-password=STRING       MySQL password []
  --mysql-db=STRING             MySQL database name [sbtest]
  --mysql-table-engine=STRING   storage engine to use for the test table {myisam,innodb,bdb,heap,ndbcluster,federated} [innodb]
  --mysql-engine-trx=STRING     whether storage engine used is transactional or not {yes,no,auto} [auto]
  --mysql-ssl=[on|off]          use SSL connections, if available in the client library [off]
  --myisam-max-rows=N           max-rows parameter for MyISAM tables [1000000]
  --mysql-create-options=STRING additional options passed to CREATE TABLE []




  测试实例测试环境：
CPU:name: Intel(R) Xeon(R) CPU E5606  @ 2.13GHz
内存：4G
系统：RHEL5.4 X86
DB：percona-5.5.18

1、测试CPU

# sysbench --test=cpu --cpu-max-prime=2000 run
Maximum prime number checked in CPU test: 2000
Test execution summary:
    total time:                          2.8035s
    total number of events:              10000
    total time taken by event execution: 2.7988
    per-request statistics:
         min:                                  0.28ms
         avg:                                  0.28ms
         max:                                  0.51ms
         approx.  95 percentile:               0.28ms
Threads fairness:
    events (avg/stddev):           10000.0000/0.00
    execution time (avg/stddev):   2.7988/0.00
2、线程测试
# sysbench  --test=threads --num-threads=500 --thread-yields=100 --thread-locks=4 run
Test execution summary:
    total time:                          1.6930s
    total number of events:              10000
    total time taken by event execution: 829.6164
    per-request statistics:
         min:                                  0.08ms
         avg:                                 82.96ms
         max:                                471.16ms
         approx.  95 percentile:             206.11ms
Threads fairness:
    events (avg/stddev):           20.0000/7.45
    execution time (avg/stddev):   1.6592/0.01
3、IO测试
    (1)prepare阶段，生成需要的测试文件，完成后会在当前目录下生成很多小文件。
    #sysbench --test=fileio --num-threads=16 --file-total-size=10G --file-test-mode=rndrw prepare
    --num-threads 开启的线程
    --file-total-size 总的文件大小
    (2)run阶段
    #sysbench --test=fileio --num-threads=200 --file-total-size=10G --file-test-mode=rndrw run    
    --file-test-mode
        rndrw:合并的随机读写
        rndwr：随机写入
        rndrd：随机读取
        seqrewr：顺序重写
        seqwr：顺序写
Operations performed:  6013 Read, 3994 Write, 11540 Other = 21547 Total
Read 93.953Mb  Written 62.406Mb  Total transferred 156.36Mb  (8.7984Mb/sec)
  563.10 Requests/sec executed

Test execution summary:
    total time:                          17.7712s
    total number of events:              10007
    total time taken by event execution: 881.7831
    per-request statistics:
         min:                                  0.01ms
         avg:                                 88.12ms
         max:                               1363.57ms
         approx.  95 percentile:             419.12ms

Threads fairness:
    events (avg/stddev):           50.0350/12.93
    execution time (avg/stddev):   4.4089/1.16        
    (3)清理测试时生成的文件
    #sysbench --test=fileio --num-threads=200 --file-total-size=10G --file-test-mode=rndrw cleanup
4、内存测试
#sysbench --test=memory --memory-block-size=8k --memory-total-size=4G run
5、mysql OLTP测试
mysql> create database sbtest;
准备测试使用的数据，我准备了1000W行数据
# sysbench --test=oltp   --mysql-user=root --mysql-host=localhost --mysql-socket=/tmp/mysql.sock --mysql-password=  --mysql-table-engine=innodb --oltp-table-size=10000000 prepare    

#使用16个线程开始测试，读写模式。
#sysbench  --mysql-db=sbtest --max-requests=0 --test=oltp --mysql-engine-trx=yes --mysql-table-engine=innodb --oltp-table-size=10000000 --db-ps-mode=disable  --mysql-user=root --mysql-host=localhost --mysql-socket=/tmp/mysql.sock  --mysql-password= --num-threads=16 --max-time=600 run
OLTP test statistics:
    queries performed:
        read:                            5777898
        write:                           2063535
        other:                           825414
        total:                           8666847
    transactions:                        412707 (687.83 per sec.)
    deadlocks:                           0      (0.00 per sec.)
    read/write requests:                 7841433 (13068.78 per sec.)
    other operations:                    825414 (1375.66 per sec.)

Test execution summary:
    total time:                          600.0128s
    total number of events:              412707
    total time taken by event execution: 9595.4495
    per-request statistics:
         min:                                  3.87ms
         avg:                                 23.25ms
         max:                               8699.18ms
         approx.  95 percentile:              44.69ms

Threads fairness:
    events (avg/stddev):           25794.1875/97.71
    execution time (avg/stddev):   599.7156/0.00

#使用16个线程开始测试，只读模式。
#sysbench  --mysql-db=sbtest --max-requests=0 --test=oltp --mysql-engine-trx=yes --mysql-table-engine=innodb --oltp-table-size=10000000 --db-ps-mode=disable  --mysql-user=root --mysql-host=localhost --mysql-socket=/tmp/mysql.sock  --oltp-read-only --mysql-password= --num-threads=16 --max-time=600 run
OLTP test statistics:
    queries performed:
        read:                            3617138
        write:                           0
        other:                           516734
        total:                           4133872
    transactions:                        258367 (430.59 per sec.)
    deadlocks:                           0      (0.00 per sec.)
    read/write requests:                 3617138 (6028.33 per sec.)
    other operations:                    516734 (861.19 per sec.)

Test execution summary:
    total time:                          600.0233s
    total number of events:              258367
    total time taken by event execution: 9597.2735
    per-request statistics:
         min:                                  3.76ms
         avg:                                 37.15ms
         max:                                103.82ms
         approx.  95 percentile:              49.00ms

Threads fairness:
    events (avg/stddev):           16147.9375/20.32
    execution time (avg/stddev):   599.8296/0.01

#清理测试的残留信息
sysbench  --mysql-db=sbtest --max-requests=0 --test=oltp --mysql-engine-trx=yes --mysql
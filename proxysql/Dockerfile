FROM centos:centos7
MAINTAINER zhang.jian <zhang.jian@chinaebi.com>

RUN yum install -y http://192.168.20.215/proxysql/proxysql-1.4.2-1-centos7.x86_64.rpm

RUN rpmkeys --import https://www.percona.com/downloads/RPM-GPG-KEY-percona
RUN yum install -y http://192.168.20.215/proxysql/percona-release-0.1-4.noarch.rpm
RUN yum makecache
RUN yum install -y Percona-Server-client-56

ADD proxysql.cnf /etc/proxysql.cnf

#COPY proxysql-entry.sh /entrypoint.sh
#RUN chmod +x /entrypoint.sh
#ENTRYPOINT ["/entrypoint.sh"]

COPY jq /usr/bin/jq
RUN chmod a+x /usr/bin/jq

COPY add_cluster_nodes.sh /usr/bin/add_cluster_nodes.sh
RUN chmod a+x /usr/bin/add_cluster_nodes.sh

VOLUME /var/lib/proxysql

EXPOSE 3306 6032
RUN yum -y install openssh-server
RUN sshd-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key && \
sshd-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key && \
sshd-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key && \
sshd-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key  && \
sshd-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key  && \
sshd-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key

CMD ["/usr/sbin/sshd","-D"]
FROM centos:centos7
MAINTAINER  zhang.jian@chinaebi.com
RUN yum makecache
RUN yum -y install php httpd haproxy php-devel php-mysql php-odbc 
RUN sed -i '1 i\ServerName\ localhost:80' /etc/httpd/conf/httpd.conf
COPY conf/docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 80 8088 3306
#CMD ["/usr/sbin/httpd","-D","FOREGROUND"]
CMD ["haproxy","-f","/etc/haproxy/haproxy.cfg"]

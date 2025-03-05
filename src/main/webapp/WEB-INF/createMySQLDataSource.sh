#!/bin/bash
# In order to use the variables in CLI scripts
# https://access.redhat.com/solutions/321513
sed -i -e "s|.*<resolve-parameter-values.*|<resolve-parameter-values>true</resolve-parameter-values>|g" /opt/eap/bin/jboss-cli.xml
/opt/eap/bin/jboss-cli.sh --connect <<EOF
data-source add --name=JPAWorldDataSourceDS \
--jndi-name=java:jboss/datasources/JPAWorldDataSource \
--connection-url=${AZURE_MYSQL_CONNECTIONSTRING}&characterEncoding=utf8&sslMode=REQUIRED&serverTimezone=UTC&authenticationPlugins=com.azure.identity.extensions.jdbc.mysql.AzureMysqlAuthenticationPlugin \
--driver-name=ROOT.war_com.mysql.cj.jdbc.Driver_9_2 \
--min-pool-size=5 \
--max-pool-size=20 \
--blocking-timeout-wait-millis=5000 \
--enabled=true \
--driver-class=com.mysql.cj.jdbc.Driver \
--jta=true \
--use-java-context=true \
--valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.mysql.MySQLValidConnectionChecker \
--exception-sorter-class-name=com.mysql.cj.jdbc.integration.jboss.ExtendedMysqlExceptionSorter
exit
EOF

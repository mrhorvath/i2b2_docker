FROM openjdk:8 as builder
ENV APP_HOME=/opt
ENV BUILD_HOME=$APP_HOME/build
ENV WILDFLY_HOME=/opt/jboss/wildfly

RUN mkdir -p $BUILD_HOME
WORKDIR $BUILD_HOME

ARG I2B2_VERSION

RUN curl -L https://github.com/i2b2/i2b2-core-server/archive/$I2B2_VERSION.tar.gz -o i2b2-core.tar.gz
RUN tar -xzf i2b2-core.tar.gz --strip 1

RUN wget -O ant.tar.gz http://archive.apache.org/dist/ant/binaries/apache-ant-1.9.11-bin.tar.gz
RUN mkdir ant && tar xzf ant.tar.gz -C ant --strip-components 1

RUN wget -O axis2.zip http://archive.apache.org/dist/axis/axis2/java/core/1.7.1/axis2-1.7.1-war.zip
RUN unzip -p axis2.zip axis2.war > axis2.war

RUN mkdir -p $WILDFLY_HOME/standalone/deployments/i2b2.war && unzip axis2.war -d $WILDFLY_HOME/standalone/deployments/i2b2.war
RUN touch $WILDFLY_HOME/standalone/deployments/i2b2.war.dodeploy

RUN find . -name build.properties -exec sed -i -e "s|^\(jboss.home\)=.*|\1=$WILDFLY_HOME|" {} \;
RUN find . -name "*_application_directory.properties" -exec sed -i -e "s|^\(edu.harvard.i2b2.*applicationdir\)=.*\(/standalone/configuration/.*\)|\1=$WILDFLY_HOME\2|" {} \;

RUN $BUILD_HOME/ant/bin/ant -buildfile $BUILD_HOME/edu.harvard.i2b2.server-common/build.xml clean dist deploy jboss_pre_deployment_setup
RUN $BUILD_HOME/ant/bin/ant -buildfile $BUILD_HOME/edu.harvard.i2b2.pm/master_build.xml clean build-all deploy
RUN $BUILD_HOME/ant/bin/ant -buildfile $BUILD_HOME/edu.harvard.i2b2.ontology/master_build.xml clean build-all deploy
RUN $BUILD_HOME/ant/bin/ant -buildfile $BUILD_HOME/edu.harvard.i2b2.crc/master_build.xml clean build-all deploy
RUN $BUILD_HOME/ant/bin/ant -buildfile $BUILD_HOME/edu.harvard.i2b2.workplace/master_build.xml clean build-all deploy
RUN $BUILD_HOME/ant/bin/ant -buildfile $BUILD_HOME/edu.harvard.i2b2.fr/master_build.xml clean build-all deploy
RUN $BUILD_HOME/ant/bin/ant -buildfile $BUILD_HOME/edu.harvard.i2b2.im/master_build.xml clean build-all deploy

#ADD datasources /opt/jboss/wildfly/standalone/deployments
ADD modules /opt/jboss/wildfly/modules/
RUN cp $WILDFLY_HOME/standalone/deployments/*.jar $WILDFLY_HOME/

FROM jboss/wildfly

COPY --from=builder /opt/jboss/wildfly/standalone/deployments /opt/jboss/wildfly/standalone/deployments/
COPY --from=builder /opt/jboss/wildfly/standalone/configuration /opt/jboss/wildfly/standalone/configuration/
COPY --from=builder /opt/jboss/wildfly/modules /opt/jboss/wildfly/modules
# COPY ./ds /opt/jboss/wildfly/standalone/deployments/
#RUN /opt/jboss/wildfly/bin/add-user.sh admin Admin#70365 --silent
#CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0"]
COPY docker-entrypoint.sh /usr/local/bin/
COPY  docker-entrypoint-init.d /docker-entrypoint-init.d
#COPY docker-entrypoint-init.d/ /
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0"]
FROM apache/kafka:3.9.0

USER root
RUN apk add --no-cache curl zip

ADD https://github.com/scylladb/scylla-cdc-source-connector/releases/download/v2.0.4/scylladb-scylla-cdc-source-connector-2.0.4.zip /tmp/scylla-cdc.zip
RUN mkdir -p /opt/kafka/connect/scylla-only /tmp/scylla-unpack && ls -l /tmp/scylla-cdc.zip && cp /tmp/scylla-cdc.zip /tmp/archive && unzip -q /tmp/archive -d /tmp/scylla-unpack && cp -r /tmp/scylla-unpack/scylladb-scylla-cdc-source-connector-2.0.4/lib/. /opt/kafka/connect/scylla-only/ && cd /opt/kafka/connect/scylla-only && zip -q -d debezium-core-2.7.4.Final.jar META-INF/services/org.apache.kafka.connect.storage.Converter && rm -rf /tmp/scylla-cdc.zip /tmp/archive /tmp/scylla-unpack
COPY connect.properties /opt/kafka/config/connect.properties
COPY distributed.properties /opt/kafka/config/distributed.properties
COPY register-connectors.sh /opt/kafka/config/register-connectors.sh

USER appuser

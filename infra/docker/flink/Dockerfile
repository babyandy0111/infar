FROM flink:1.18.1-java11

# 設定版本變數
ARG KAFKA_VERSION=3.1.0-1.18
ARG JDBC_VERSION=3.1.2-1.18
ARG POSTGRES_VERSION=42.7.2
ARG ES_VERSION=3.0.1-1.18

# 1. 下載並安裝 Connector (基礎設施層)
RUN wget -P /opt/flink/lib/ https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/${KAFKA_VERSION}/flink-sql-connector-kafka-${KAFKA_VERSION}.jar && \
    wget -P /opt/flink/lib/ https://repo1.maven.org/maven2/org/apache/flink/flink-connector-jdbc/${JDBC_VERSION}/flink-connector-jdbc-${JDBC_VERSION}.jar && \
    wget -P /opt/flink/lib/ https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRES_VERSION}/postgresql-${POSTGRES_VERSION}.jar && \
    wget -P /opt/flink/lib/ https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-elasticsearch7/${ES_VERSION}/flink-sql-connector-elasticsearch7-${ES_VERSION}.jar

# 2. 打包業務 SQL (業務邏輯層)
# 注意：我們在執行 docker build 時，會透過 context 傳入 SQL 檔案
RUN mkdir -p /opt/flink/jobs
COPY order_processor.sql /opt/flink/jobs/

# 權限修正
RUN chown -R flink:flink /opt/flink/lib/*.jar /opt/flink/jobs/

ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 6123 8081
CMD ["help"]

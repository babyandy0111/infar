FROM flink:1.18.1-java11

# 設定版本變數
ARG KAFKA_VERSION=3.1.0-1.18
ARG JDBC_VERSION=3.1.2-1.18
ARG POSTGRES_VERSION=42.7.2

# 下載必要的 Connector 並直接放入 lib 目錄 (自動載入)
# 使用一次性 RUN 指令減少 Image Layer
RUN wget -P /opt/flink/lib/ https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/${KAFKA_VERSION}/flink-sql-connector-kafka-${KAFKA_VERSION}.jar && \
    wget -P /opt/flink/lib/ https://repo1.maven.org/maven2/org/apache/flink/flink-connector-jdbc/${JDBC_VERSION}/flink-connector-jdbc-${JDBC_VERSION}.jar && \
    wget -P /opt/flink/lib/ https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRES_VERSION}/postgresql-${POSTGRES_VERSION}.jar

# 權限修正
RUN chown flink:flink /opt/flink/lib/*.jar

# 保持官方的 Entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 6123 8081
CMD ["help"]

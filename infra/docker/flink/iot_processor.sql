-- =============================================================================
-- Flink IoT 即時監測 Job (Watermark + Sliding Window + Elasticsearch Sink)
-- =============================================================================

-- 1. 定義 Kafka 來源表 (感測器數據)
CREATE TABLE kafka_sensors (
    device_id STRING,
    temperature DOUBLE,
    humidity DOUBLE,
    event_time BIGINT, -- 原始數據中的毫秒時間戳
    -- 💡 核心：將 BIGINT 轉為 TIMESTAMP(3) 並定義 Watermark
    ts AS TO_TIMESTAMP(FROM_UNIXTIME(event_time / 1000)),
    -- 💡 核心：允許數據遲到 5 秒
    WATERMARK FOR ts AS ts - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'iot-sensor-data',
    'properties.bootstrap.servers' = 'kafka-service.infra.svc.cluster.local:9092',
    'properties.group.id' = 'flink-iot-group',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json'
);

-- 2. 定義 Elasticsearch Sink (存儲統計結果)
CREATE TABLE es_sensor_stats (
    device_id STRING,
    avg_temp DOUBLE,
    avg_hum DOUBLE,
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    -- ES 需要一個主鍵來處理更新
    PRIMARY KEY (device_id, window_start) NOT ENFORCED
) WITH (
    'connector' = 'elasticsearch-7',
    'hosts' = 'http://elasticsearch-service.infra.svc.cluster.local:9200',
    'index' = 'sensor_stats_sliding',
    'sink.batch-size' = '50',      -- 累積 50 筆才寫入 ES
    'sink.flush-interval' = '5s'   -- 或者每 5 秒強制寫入一次
);

-- 🚀 任務：每 1 分鐘計算一次「過去 5 分鐘」的平均值 (趨勢監控)
SET 'parallelism.default' = '2'; -- 假設 IoT 數據量較大，開啟 2 個併發

INSERT INTO es_sensor_stats
SELECT 
    device_id,
    AVG(temperature) as avg_temp,
    AVG(humidity) as avg_hum,
    HOP_START(ts, INTERVAL '1' MINUTE, INTERVAL '5' MINUTE) as window_start,
    HOP_END(ts, INTERVAL '1' MINUTE, INTERVAL '5' MINUTE) as window_end
FROM kafka_sensors
-- 數據清洗：過濾掉感測器故障的異常極端值
WHERE temperature BETWEEN -50 AND 150
GROUP BY 
    device_id, 
    HOP(ts, INTERVAL '1' MINUTE, INTERVAL '5' MINUTE);

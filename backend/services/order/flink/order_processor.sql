-- =============================================================================
-- Flink 秒殺即時處理 Job (全功能版：落盤 + 每分鐘聚合統計)
-- =============================================================================

-- 🚀 Flink 效能優化參數
SET 'pipeline.object-reuse' = 'true';                  -- 開啟物件重用，減少 GC 壓力
SET 'table.exec.mini-batch.enabled' = 'true';          -- 開啟 MiniBatch，批次寫入下游資料庫
SET 'table.exec.mini-batch.allow-latency' = '5 s';     -- 允許最大延遲 5 秒進行聚合
SET 'table.exec.mini-batch.size' = '1000';             -- 每 1000 筆資料聚合一次
SET 'parallelism.default' = '8';                       -- 配合 Kafka 的 8 個 Partition

CREATE TABLE kafka_orders (
    user_id INT,
    product_id INT,
    amount DECIMAL(10, 2),
    order_no STRING,
    ts AS PROCTIME()
) WITH (
    'connector' = 'kafka',
    'topic' = 'order-create',
    'properties.bootstrap.servers' = 'kafka-service.infra.svc.cluster.local:9092',
    'properties.group.id' = 'flink-order-group',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'json'
);

-- 訂單明細 Sink
CREATE TABLE postgres_orders (
    user_id INT,
    order_no STRING,
    amount DECIMAL(10, 2),
    status TINYINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://postgres.infra.svc.cluster.local:5432/infar_db',
    'table-name' = 'orders',
    'username' = 'infar_admin',
    'password' = 'InfarDbPass123'
);

-- 銷售聚合 Sink (Upsert 模式)
CREATE TABLE postgres_sales_stats (
    product_id INT,
    total_orders BIGINT,
    total_revenue DECIMAL(15, 2),
    PRIMARY KEY (product_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://postgres.infra.svc.cluster.local:5432/infar_db',
    'table-name' = 'sales_stats',
    'username' = 'infar_admin',
    'password' = 'InfarDbPass123'
);

EXECUTE STATEMENT SET BEGIN

-- 🚀 任務 1：明細落盤
INSERT INTO postgres_orders
SELECT user_id, order_no, amount, CAST(1 AS TINYINT) FROM kafka_orders;

-- 🚀 任務 2：即時統計 (以商品為維度累計)
INSERT INTO postgres_sales_stats
SELECT 
    product_id,
    COUNT(*) as total_orders,
    SUM(amount) as total_revenue
FROM kafka_orders
GROUP BY product_id;

END;

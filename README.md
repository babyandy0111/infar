# Infar 微服務架構與部署平台

本專案提供一個企業級、可觀測且具備高安全性的 Kubernetes (K8s) 微服務開發與部署環境。架構設計嚴格遵循**「基礎設施即代碼 (IaC)」**與**「GitOps」**原則，並採用 **cdk8s (Go)** 進行宣告式配置，確保本機開發環境與正式雲端環境的高度一致性。

---

## 🏗 基礎架構總覽 (Infrastructure Architecture)

目前 K8s 叢集內已部署並整合以下核心模組：

*   **資料儲存與快取層 (Data & Cache)**:
    *   `PostgreSQL` (關聯式資料庫，版本 16.2)
    *   `Redis Stack` (具備 RediSearch 全文檢索能力)
*   **事件驅動與大數據層 (Event & Streaming)**:
    *   `Kafka & ZooKeeper` (高吞吐量訊息佇列，具備自動修復 Cluster ID 機制)
    *   `Apache Flink` (實時串流運算引擎)
*   **持續交付層 (CI/CD)**:
    *   `ArgoCD` (實現 GitOps 自動化部署與狀態同步)
*   **全方位可觀測性 (Observability)**:
    *   `Linkerd` (Service Mesh，提供 HTTP/TCP 流量觀測、mTLS 零信任加密)
    *   `Prometheus & Promtail` (系統指標與容器即時日誌收集)
    *   `Loki & Grafana` (日誌聚合與中央視覺化，內建 **Infar 專屬雙重戰情室**)
*   **網路入口 (Gateway)**:
    *   `Nginx Ingress Controller` (本機開發用的 L7 負載平衡器)

---

## 🚀 核心亮點：專業級自動化與自癒機制

本專案的基礎設施管理已達到極高的自動化標準：

1.  **純淨的命名規則 (No Hash Names)：** 透過精密的 Helm 覆寫設定，徹底移除了 cdk8s 自動產生的隨機 Hash 字尾。所有服務皆擁有如 `postgres-0`, `prometheus-server`, `loki-0` 等穩定、可預測的名稱，完美解決內部 DNS 解析與儀表板顯示問題。
2.  **100% 宣告式冪等部署 (Idempotent Apply)：** 安裝腳本 (`setup.sh`) 內無任何破壞性的 `delete` 或硬編碼指令。無論是初次建置或設定更新，皆能透過 K8s 的 Server-Side Apply 平滑地進行 Rolling Update。
3.  **零干擾的自動注入 (Mesh Auto-injection)：** 全面採用 Namespace 級別的 Linkerd 標籤注入，並在 IaC 代碼中精準排除了不相容的組件 (如 Node-Exporter)，確保微服務能 100% 獲得 2/2 的 Sidecar 覆蓋率。
4.  **Kafka 叢集自癒 (Self-Healing)：** 針對 Kafka 重啟時常見的 `InconsistentClusterIdException`，我們在 StatefulSet 中加入了專屬的 `InitContainer`。當偵測到環境重置時，它會自動清空掛載卷中的髒資料，讓 Kafka 完美重生。
5.  **零殘骸環境 (Clean Environment)：** 在 Go 原始碼中直接關閉了 Helm Chart 預設的 Test Hooks 與一次性 Jobs，確保 `kubectl get pod -A` 永遠保持全綠 `Running` 的完美狀態。

---

## 💻 本機開發環境 (Minikube) 使用指南

本專案專為 macOS 環境下的 Minikube (Docker Driver) 進行最佳化。

### 1. 環境前置作業
確保您已建立並設定了 `.env` 檔案，這將被 cdk8s 讀取並轉換為 K8s Secrets：
```bash
# 於 k8s/infra/.env 中建立
DB_PASSWORD=your_secure_password
REDIS_PASSWORD=your_secure_password
ARGOCD_ADMIN_PASSWORD=your_secure_password
```

### 2. 一鍵初始化與部署 (Setup)
進入腳本目錄並執行安裝。此腳本將自動編譯 cdk8s 多檔案模組、安裝 Linkerd、同步宣告式狀態，並自動更新本機 `/etc/hosts`。

```bash
cd k8s/infra
./setup.sh
```

### 3. 開啟網路存取通道 (Tunnel)
在 macOS 環境下，必須透過 Tunnel 將 Ingress 流量導入 Docker 虛擬機。請在**新的終端機視窗**中持續執行：

```bash
sudo minikube tunnel
```

### 4. 執行健康檢查與流量模擬
我們提供了自動化腳本，以驗證所有組件是否正確運作，並可產生真實流量以點亮戰情室：
```bash
# 驗證基礎設施 (全綠燈檢查)
./k8s/infra/tests/verify.sh

# 啟動網格流量模擬器 (產生 TCP/HTTP 流量至 DB/Kafka/Flink)
./k8s/infra/tests/simulate-traffic.sh
```

### 5. 系統存取資訊 (Web UI)
*   **Grafana 雙重戰情室**: [http://grafana.local](http://grafana.local) (預設帳號: `admin`, 密碼: `admin`)
    *   *儀表板 1：Infar - Microservices War Room (Linkerd TCP 流量拓撲)*
    *   *儀表板 2：Infar - K8s Health & Logs (K8s 資源狀態與 Loki 即時日誌)*
*   **Flink 控制台**: [http://flink.local](http://flink.local)
*   **ArgoCD**: [http://argocd.local](http://argocd.local) (預設帳號: `admin`, 密碼為 `.env` 內設定之明文)
*   **Service Mesh 拓撲**: 執行 `linkerd viz dashboard` 觀看微服務實時連線狀態。

### 6. 開發者本機連線指南 (Local Port-Forwarding)
為了讓開發者能在本機使用資料庫工具 (如 DataGrip) 或是撰寫 Go 程式測試，請開啟通道：

```bash
# 取得動態資料庫密碼
kubectl get secret infra-secrets -n infra -o jsonpath="{.data.postgresql-password}" | base64 --decode ; echo
kubectl get secret infra-secrets -n infra -o jsonpath="{.data.redis-password}" | base64 --decode ; echo

# PostgreSQL (連線: 127.0.0.1:5432, db: infar_db, user: admin)
kubectl port-forward svc/postgres 5432:5432 -n infra &

# Redis (連線: 127.0.0.1:6379)
kubectl port-forward svc/redis-master 6379:6379 -n infra &

# Kafka (連線: 127.0.0.1:9092)
kubectl port-forward svc/kafka-service 9092:9092 -n infra &
```

---

## 📂 專案目錄結構

```text
/
├── k8s/
│   └── infra/
│       ├── main.go          # cdk8s 主程式 (將架構拆分為多個 Charts)
│       ├── pkg/             # 基礎設施模組宣告 (Datastore, Streaming, Observability, CICD)
│       ├── tests/           # 健康檢查與流量模擬腳本
│       ├── setup.sh         # 專業冪等自癒版安裝腳本
│       ├── cleanup.sh       # 深度環境清理腳本 (卸載所有資源與 PVC)
│       └── import-dashboard # Grafana 戰情室動態匯入腳本
├── backend/                 # [準備開發] go-zero 微服務後端程式碼
└── frontend/                # [準備開發] 前端應用程式碼
```
*(註：`dist/` 與 `imports/` 為 cdk8s 自動生成目錄，已設定 `.gitignore` 以保持版本庫純淨。)*

---

## ☁️ AWS 生態系無縫部署指南 (Production-Ready)

本架構在設計初期即已考量公有雲的轉移。當您準備部署至 AWS EKS 時，**無需修改基礎 Go 模組邏輯**，僅需針對 AWS 生態系進行以下環境適配：

### 1. Ingress 與負載平衡 (AWS ALB)
*   **變更設定**：將各服務的 `ingressClassName` 從 `nginx` 更改為 **`alb`**。
*   **AWS 行為**：此動作將觸發 AWS Load Balancer Controller，自動為您的服務配置實體 Application Load Balancer，並可透過 Annotations 對接 ACM 實現 HTTPS 加密。

### 2. 持久化儲存 (AWS EBS)
*   **AWS 行為**：PostgreSQL, Redis, Kafka 與 Zookeeper 的 `StatefulSet` 與 `PVC` 將自動對接 EKS 的 EBS CSI Driver，在 AWS 上動態建立對應大小的 gp3 磁碟。

### 3. 巨型基礎設施升級 (Kafka / Flink / Database)
*   **架構建議**：在 AWS 生態系中，強烈建議將 `PostgreSQL`, `Redis`, `Kafka` 從 K8s 叢集中剝離，改為使用 AWS 託管服務 (如 **Amazon RDS**, **ElastiCache**, **Amazon MSK**)。這將大幅降低 EKS 節點的維運成本與 OOM 風險。

---

## 📝 下一階段目標 (Phase 2 Roadmap)
- [ ] **go-zero 微服務建置**：於 `backend/` 目錄建立第一個微服務，並確保其日誌與指標能無縫接入現有 PLG 監控體系。
- [ ] **GitOps 實戰**：將微服務的部署 YAML 與 ArgoCD 結合，實現推播至 Git 即自動部署的 CI/CD 流程。
- [ ] **高可用擴展 (HPA)**：為微服務加入基於 CPU/Memory 負載的 Horizontal Pod Autoscaler 配置。
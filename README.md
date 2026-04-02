# Infar 微服務架構與部署平台 (Phase 1)

本專案旨在提供一個企業級、可觀測且具備高安全性的 Kubernetes (K8s) 微服務開發與部署環境。架構設計嚴格遵循「基礎設施即代碼 (IaC)」與「GitOps」原則，確保本機開發環境與正式雲端環境的高度一致性。

## 🏗 基礎架構總覽 (Infrastructure Architecture)

目前 K8s 叢集內已部署以下核心模組：

*   **資料儲存與快取層 (Data & Cache)**:
    *   `PostgreSQL` (關聯式資料庫，版本 16.2)
    *   `Redis Stack` (具備 RediSearch 全文檢索能力)
*   **事件驅動與大數據層 (Event & Streaming)**:
    *   `Kafka & ZooKeeper` (高吞吐量訊息佇列，單機開發版)
    *   `Apache Flink` (實時串流運算引擎)
*   **持續交付層 (CI/CD)**:
    *   `ArgoCD` (實現 GitOps 自動化部署與狀態同步)
*   **全方位可觀測性 (Observability)**:
    *   `Linkerd` (Service Mesh，提供流量觀測、mTLS 零信任加密)
    *   `Prometheus & Promtail` (系統指標與容器日誌收集)
    *   `Loki & Grafana` (日誌聚合與中央視覺化，內建 **Infar 專屬微服務戰情室**)
*   **網路入口 (Gateway)**:
    *   `Nginx Ingress Controller` (本機開發用的 L7 負載平衡器)

---

## 💻 本機開發環境 (Minikube) 使用指南

本專案已為 macOS 環境下的 Minikube (Docker Driver) 進行一鍵化安裝腳本配置。

### 1. 環境初始化
進入腳本目錄並執行安裝。此腳本將自動安裝必要 CLI 工具 (Helm, Linkerd)、產生 K8s Secrets、部署所有基礎設施，並自動綁定本機 DNS 解析。

```bash
cd k8s/infra
./setup.sh
```

### 2. 開啟網路存取通道 (重要)
在 macOS 環境下，必須透過 Tunnel 將 Ingress 流量導入 Docker 虛擬機。請在**新的終端機視窗**中持續執行：

```bash
sudo minikube tunnel
```

### 3. 系統存取資訊 (Web UI)
*   **Grafana 戰情室**: [http://grafana.local](http://grafana.local) (預設帳號: `admin`, 密碼: `admin`)
    *   *註：請進入 Dashboards > Infar Custom > Infar - Microservices Overview 觀看即時流量。*
*   **Flink 控制台**: [http://flink.local](http://flink.local)
*   **ArgoCD**: [http://argocd.local](http://argocd.local) (預設帳號: `admin`, 密碼: `admin123`)
*   **Service Mesh 拓撲**: 執行 `linkerd viz dashboard` 觀看微服務實時連線狀態。

### 4. 開發者本機連線指南 (Local Port-Forwarding)
為了讓開發者能在本機使用資料庫工具 (如 DataGrip, DBeaver) 或是撰寫 Go 程式測試，請使用以下指令開啟通道：

**A. 取得動態資料庫密碼**
```bash
# PostgreSQL 密碼
kubectl get secret infra-secrets -n infra -o jsonpath="{.data.postgresql-password}" | base64 --decode ; echo
# Redis 密碼
kubectl get secret infra-secrets -n infra -o jsonpath="{.data.redis-password}" | base64 --decode ; echo
```

**B. 開啟資料庫/服務通道 (於獨立終端機背景執行)**
```bash
# PostgreSQL (連線: 127.0.0.1:5432, db: infar_db, user: admin)
kubectl port-forward svc/postgresql 5432:5432 -n infra &

# Redis (連線: 127.0.0.1:6379)
kubectl port-forward svc/redis-master 6379:6379 -n infra &

# Kafka (連線: 127.0.0.1:9092)
# 注意: 請確保本機 /etc/hosts 已加入 `127.0.0.1 kafka-service.infra.svc.cluster.local` 以避免 DNS 解析錯誤
kubectl port-forward svc/kafka-service 9092:9092 -n infra &
```

### 5. 執行健康檢查
提供自動化腳本，以驗證所有組件 (含 Kafka Broker, Flink TaskManager) 是否正確運作：
```bash
./k8s/infra/tests/verify.sh
```

---

## ☁️ AWS 生態系無縫部署指南 (Production-Ready)

本架構在設計初期即已考量公有雲的轉移。當您準備部署至 AWS EKS 時，**無需修改基礎腳本與架構邏輯**，僅需針對 AWS 生態系進行以下環境適配：

### 1. Ingress 與負載平衡 (AWS ALB)
*   **變更設定**：建立一份專屬的 `aws-values.yaml`，將各服務的 `ingressClassName` 從 `nginx` 更改為 **`alb`**。
*   **AWS 行為**：此動作將觸發 AWS Load Balancer Controller，自動為您的服務配置實體 Application Load Balancer。
*   **憑證綁定**：在 Ingress 的 Annotations 中加入 `alb.ingress.kubernetes.io/certificate-arn` 以對接 AWS Certificate Manager (ACM)，實現 HTTPS 加密。

### 2. 持久化儲存 (AWS EBS)
*   **AWS 行為**：PostgreSQL 與 Redis 的 `PersistentVolumeClaim (PVC)` 將自動對接 EKS 的 EBS CSI Driver，在 AWS 上動態建立對應大小的 gp3 磁碟。

### 3. 密鑰與權限管理 (Secrets & IAM)
*   **變更設定**：移除 `setup.sh` 中的隨機密碼生成邏輯。導入 **External Secrets Operator (ESO)**。
*   **AWS 行為**：ESO 將直接從 **AWS Secrets Manager** 抓取正式環境的資料庫密碼，並注入 Kubernetes，實現最高等級的資安隔離。
*   **微服務權限**：使用 IRSA (IAM Roles for Service Accounts) 讓未來的 go-zero 微服務能以最小權限安全存取 AWS 資源。

### 4. 巨型基礎設施升級 (Kafka / Flink / Database)
*   **架構建議**：在 AWS 生態系中，強烈建議將 `PostgreSQL`, `Redis`, `Kafka` 從 K8s 叢集中剝離，改為使用 AWS 託管服務 (如 **Amazon RDS**, **ElastiCache**, **Amazon MSK**)。這將大幅降低 EKS 節點的維運成本與 OOM 風險。

---

## 📂 專案目錄結構

```text
/
├── k8s/
│   └── infra/
│       ├── helm-values/    # 各基礎設施的宣告式 Helm 設定檔 (IaC)
│       ├── manifests/      # 原生 K8s 部署資源 (Kafka, Flink, 戰情室 Dashboard)
│       ├── tests/          # 基礎設施健康檢查腳本 (verify.sh)
│       └── setup.sh        # 一鍵式自動化安裝入口
├── backend/                # [準備開發] go-zero 微服務後端程式碼
└── frontend/               # [準備開發] 前端應用程式碼
```

---
## 📝 下一階段目標 (Phase 2 Roadmap)
- [ ] **go-zero 微服務建置**：於 `backend/` 目錄建立第一個微服務，並確保其日誌與指標能無縫接入現有 PLG 監控體系。
- [ ] **GitOps 實戰**：將微服務的部署 YAML 與 ArgoCD 結合，實現推播至 Git 即自動部署的 CI/CD 流程。
- [ ] **高可用擴展 (HPA)**：為微服務加入基於 CPU/Memory 負載的 Horizontal Pod Autoscaler 配置。

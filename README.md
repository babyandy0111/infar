# Infar 微服務架構與部署平台

本專案提供一個企業級、可觀測且具備高安全性的 Kubernetes (K8s) 微服務開發與部署環境。架構設計嚴格遵循**「基礎設施即代碼 (IaC)」**與**「GitOps」**原則，並採用 **cdk8s (Go)** 與 **Terraform** 進行多環境配置，確保從本機開發到雲端生產環境的一致性。

---

## 🏗 基礎架構總覽 (Infrastructure Architecture)

目前 K8s 叢集內已部署並整合以下核心模組：

*   **資料儲存與快取層 (Data & Cache)**:
    *   `PostgreSQL` (關聯式資料庫)
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

---

## 🚀 核心亮點：專業級自動化與多雲支援

1.  **純淨的命名規則 (Stable Names)：** 徹底移除了 cdk8s 隨機 Hash，所有服務皆擁有穩定名稱（如 `postgres-0`），優化內部 DNS 解析。
2.  **多檔案模組化產出：** cdk8s 產出已按功能拆分為 `01-datastore`, `02-streaming` 等獨立 YAML，提升維護與除錯效率。
3.  **多雲 Serverless 支援：** 內建 **AWS EKS Fargate** 與 **GCP GKE Autopilot** 的 Terraform 模板，實現真正的「零主機管理」K8s 體驗。
4.  **環境自動識別 (Environment Parity)：** `setup.sh` 與 `cleanup.sh` 支援帶入 `local`, `aws`, `gcp` 等參數，自動切換「K8s 內部 Pod」或「對接雲端託管服務 (RDS/MSK)」的連線邏輯，並智慧更新對應的網址與清理機制。
5.  **Kafka & Zookeeper 持久化與自癒：** 修正了 Zookeeper 的持久化漏洞，並在 Kafka 加入 InitContainer 以自動解決重啟後的叢集 ID 衝突。

---

## 💻 本機開發環境 (Minikube) 使用指南

### 1. 環境前置作業
確保 `infra/k8s/.env` 已設定資料庫密碼。可複製 `.env.example` 作為基礎。

### 2. 一鍵初始化與部署 (Setup)
```bash
cd infra/k8s
./setup.sh local  # 或直接執行 ./setup.sh，預設即為 local
```

### 3. 開啟網路存取通道 (Tunnel)
請在**新的終端機視窗**中持續執行：
```bash
sudo minikube tunnel
```

### 4. 執行檢查與模擬
```bash
# 驗證基礎設施 (全綠燈檢查)
./infra/k8s/tests/verify.sh

# 啟動網格流量模擬器 (點亮戰情室)
./infra/k8s/tests/simulate-traffic.sh
```

### 5. 系統存取資訊
*   **Grafana**: [http://grafana.local](http://grafana.local) (admin/admin)
*   **Flink UI**: [http://flink.local](http://flink.local)
*   **ArgoCD**: [http://argocd.local](http://argocd.local) (admin/您的密碼)

### 6. 環境深度清理 (Cleanup)
當需要恢復乾淨環境時，可執行以下腳本：
```bash
cd infra/k8s
./cleanup.sh local
# 將自動卸載所有 K8s 資源、復原 /etc/hosts，並可選擇性清空持久化資料(PVC)
```

---

## 📂 專案目錄結構

```text
/
├── infra/                   # 基礎設施根目錄
│   ├── k8s/                 # Kubernetes 應用層與資源宣告 (cdk8s)
│   │   ├── main.go          # 主程式 (多檔案模組化產出)
│   │   ├── pkg/             # 模組定義 (Datastore, Streaming, Observability, CICD)
│   │   ├── tests/           # verify.sh, simulate-traffic.sh
│   │   ├── setup.sh         # 具備多雲環境感知之冪等安裝腳本
│   │   ├── cleanup.sh       # 具備多雲環境感知之深度清理腳本
│   │   └── dist/            # (Ignored) 產出的多份 K8s YAML
│   └── terraform/           # 雲端底層基礎設施 (IaC)
│       ├── aws/             # EKS Fargate (Serverless) 與 RDS v2 配置
│       └── gcp/             # GKE Autopilot (Serverless) 與 Cloud SQL 配置
├── backend/                 # [準備開發] go-zero 微服務
└── frontend/                # [準備開發] 前端應用
```

---

## ☁️ 多雲部署指南 (Production-Ready)

當準備從本地轉向雲端時，請在 `.env` 設定雲端專案 ID 與區域，並確保已完成雲端 CLI (aws/gcloud) 的本機授權。

### 1. 建立雲端資源 (以 GCP 為例)
```bash
cd infra/terraform/gcp
terraform init
terraform apply -auto-approve
```
*(執行完畢後，GCP 將建立 GKE Autopilot 叢集與 Cloud SQL。)*

### 2. 套用 K8s 配置與自動對接
```bash
cd infra/k8s
./setup.sh gcp  
```
*(腳本將自動抓取 Terraform 輸出的雲端資料庫 Endpoint，將微服務安全對接，並提供 Cloud LoadBalancer 入口網址。)*

### 3. 雲端環境銷毀
```bash
cd infra/k8s
./cleanup.sh gcp 
```
*(腳本將自動執行 terraform destroy 回收所有雲端資源，避免不必要的開銷。)*

---
## 📝 下一階段目標 (Phase 2 Roadmap)
- [ ] **go-zero 微服務建置**：於 `backend/` 建立服務並接入 PLG 監控。
- [ ] **ArgoCD GitOps**：將部署 YAML 與 Git 儲存庫同步。
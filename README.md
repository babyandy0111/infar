# Infar 微服務架構與部署平台

本專案提供一個企業級、可觀測且具備高安全性的 Kubernetes (K8s) 微服務開發與部署環境。架構設計嚴格遵循**「基礎設施即代碼 (IaC)」**與**「GitOps」**原則，並採用 **cdk8s (Go)** 與 **Terraform** 進行多環境配置，確保從本機開發到雲端生產環境的一致性。

---

## 🏗 基礎架構總覽 (Infrastructure Architecture)

為了確保在 Local 開發環境的輕量化與雲端環境 (AWS/GCP) 的高可用性，本專案採用**「環境適應性架構 (Environment Parity)」**，並依據環境自動切換託管與自建模式。

### 🌍 跨環境服務配置矩陣

| 服務模組 | **Local** (Minikube) | **AWS** (EKS Fargate) | **GCP** (GKE Autopilot) | 說明與雲端策略 |
| :--- | :--- | :--- | :--- | :--- |
| **ArgoCD** | K8s Pod | K8s Pod | K8s Pod | CI/CD 核心大腦，所有環境保持一致。雲端使用 ALB/GCE Ingress 對外。 |
| **PostgreSQL** | K8s Pod | **Amazon RDS (v2)** | **Cloud SQL** | 雲端轉為 Serverless 託管，確保資料高可用與免維護。 |
| **Redis** | K8s Pod | **ElastiCache** | **Memorystore** | 雲端轉為託管快取，取代原有的 Kafka 成為主力訊息佇列 (Streams)。 |
| **Kafka & Flink** | (暫停部署) | (暫停部署) | (暫停部署) | **架構減法：** 初期以 Redis Streams 取代，確保叢集輕量化。代碼已保留於 `pkg/streaming/` 供未來擴充。 |
| **Linkerd (Mesh)** | K8s Pod | **(跳過)** | **(跳過)** | 雲端 Serverless 環境對底層網路權限有限制，故雲端模式自動停用。 |
| **PLG 監控堆疊** | K8s Pod | **(跳過)** | **(跳過)** | 包含 Prometheus, Loki, Grafana。雲端環境自動轉向使用原生的 CloudWatch / Cloud Logging。 |
| **跳板機 (Jump)** | (不需要) | K8s Pod | K8s Pod | 雲端專屬。自動將本機流量安全轉發至雲端私有資料庫。 |

---

## 🚀 核心亮點：專業級自動化與多雲支援

1.  **純淨命名規則 (Stable Names)：** 徹底移除了 cdk8s 隨機 Hash，所有服務皆擁有穩定名稱（如 `postgres`），優化內部 DNS 解析。
2.  **多雲 Serverless 支援：** 內建 **AWS EKS Fargate** 與 **GCP GKE Autopilot** 的 Terraform 模板，實現真正的「零主機管理」K8s 體驗。
3.  **智慧環境識別：** `setup.sh` 支援帶入 `local`, `aws`, `gcp` 等參數，自動執行對應的 Terraform 腳本，抓取產出的資料庫 Endpoint，並自動無縫注入到 K8s 部署中。
4.  **全自動開發者通道 (Jump Pod)：** 無論部署於 Local 還是雲端，腳本會在最後自動於背景建立 Port-forward 通道。開發者永遠只需連線 `127.0.0.1:5432` 即可直達資料庫。
5.  **零殘骸環境 (Clean Environment)：** 在 Go 原始碼中直接關閉了 Helm Chart 預設的 Test Hooks (如 Grafana-test)，確保 `kubectl get pod -A` 永遠保持全綠 `Running` 的完美狀態。

---

## 💻 本機開發環境 (Minikube) 使用指南

### 1. 環境前置作業
確保 `infra/k8s/.env` 已正確設定。請複製 `.env.example` 並填寫您的密碼與資料庫名稱：
```bash
# 於 infra/k8s/.env 中建立
DB_PASSWORD=your_secure_password
REDIS_PASSWORD=your_secure_password
DB_USER=admin
DB_NAME=infar_db
ARGOCD_ADMIN_PASSWORD=your_argocd_password
```

### 2. 開啟網路存取通道 (Tunnel)
在 macOS 環境下，必須透過 Tunnel 將 Ingress 流量導入 Docker 虛擬機。請在**新的終端機視窗**中持續執行：
```bash
sudo minikube tunnel
```

### 3. 一鍵初始化與部署 (Setup)
進入腳本目錄並執行安裝。此腳本將自動編譯 cdk8s 模組、安裝 Linkerd、同步狀態，並於背景**自動開啟資料庫的連線通道**。
```bash
cd infra/k8s
./setup.sh local  # 或直接執行 ./setup.sh
```

### 4. 執行深度驗證 (Verify)
提供自動化腳本，以驗證所有組件是否正確運作。該腳本會動態讀取 K8s 狀態，並測試資料庫與 Ingress 連線：
```bash
./tests/verify.sh local
```

### 5. 開發者連線資訊 (Access Guide)
執行 `setup.sh` 後，系統已自動將資料庫通道映射至本機。
*   **PostgreSQL**: `127.0.0.1:5432` (帳號密碼請見 `.env`)
*   **Redis**: `127.0.0.1:6379`
*   **ArgoCD**: [http://argocd.local](http://argocd.local)
*   **Grafana**: [http://grafana.local](http://grafana.local) (預設帳號: admin/admin)
*   **Service Mesh 拓撲**: `linkerd viz dashboard`

💡 *若需手動關閉背景的資料庫通道，請執行：* `pkill -f "port-forward"`

---

## ☁️ 多雲部署指南 (Production-Ready)

當準備從本地轉向雲端時，請確保已完成雲端 CLI (`aws` 或 `gcloud`) 的本機授權，並在 `.env` 中設定了對應的 `PROJECT_ID` 與 `REGION`。

### 步驟 1：一鍵啟動雲端部署
您**不需要**手動執行 Terraform。我們的神兵腳本會自動接管一切：
```bash
cd infra/k8s
./setup.sh gcp  # 或 ./setup.sh aws
```
**這個指令會自動執行以下奇蹟：**
1. 啟動 Terraform 引擎，在雲端建立 VPC、Serverless K8s 叢集與託管資料庫 (RDS/Cloud SQL)。
2. 自動抓取 Terraform 輸出的資料庫 Endpoint，並安全地注入 K8s。
3. 自動將您的 kubectl 焦點切換至剛建好的雲端叢集。
4. 部署 ArgoCD，並建立指向雲端資料庫的 **Jump Pod**，最後自動幫您在背景開啟 Port-forward。

部署完成後，您依然可以透過 `127.0.0.1:5432` 在本機用 IDE 直接存取遠在雲端的私有資料庫！

### 步驟 2：獲取雲端 Ingress 網址
執行完畢後，腳本會提示您如何獲取雲端 LoadBalancer 的真實 IP：
```bash
kubectl get ingress argocd-server -n argocd
```

### 步驟 3：雲端環境深度清理 (Cleanup)
當測試完畢，為避免產生昂貴的雲端帳單，請務必執行清理腳本。它會自動觸發 `terraform destroy` 徹底回收所有資源：
```bash
./cleanup.sh gcp  # 或 ./cleanup.sh aws
```

---

## 📂 專案目錄結構

```text
/
├── infra/                   # 基礎設施根目錄
│   ├── k8s/                 # Kubernetes 應用層與資源宣告 (cdk8s)
│   │   ├── main.go          # 主程式 (多檔案模組化產出)
│   │   ├── pkg/             # 模組定義 (Datastore, Observability, CICD, Platform)
│   │   ├── tests/           # verify.sh (防呆動態驗證)
│   │   ├── setup.sh         # 具備多雲環境感知之總指揮安裝腳本
│   │   └── cleanup.sh       # 具備多雲環境感知之深度清理腳本
│   └── terraform/           # 雲端底層基礎設施 (IaC)
│       ├── aws/             # EKS Fargate (Serverless) 與 RDS v2 配置
│       └── gcp/             # GKE Autopilot (Serverless) 與 Cloud SQL 配置
├── backend/                 # [準備開發] go-zero 微服務
└── frontend/                # [準備開發] 前端應用
```

---
## 📝 下一階段目標 (Phase 2 Roadmap)
- [ ] **go-zero 微服務建置**：於 `backend/` 建立服務，並透過 `127.0.0.1` 統一連線邏輯。
- [ ] **ArgoCD GitOps**：將部署 YAML 與 Git 儲存庫同步。

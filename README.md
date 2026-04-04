# Infar 微服務架構與多雲部署平台

本專案提供一個企業級、可觀測且具備高安全性的 Kubernetes (K8s) 微服務開發與部署環境。架構設計嚴格遵循**「基礎設施即代碼 (IaC)」**與**「GitOps」**原則。

---

## 🏗 專案目錄結構 (Directory Structure)

```text
/
├── infra/                   # 基礎設施根目錄 (Infrastructure)
│   ├── k8s/                 # K8s 資源宣告 (cdk8s) 與管理腳本
│   │   ├── main.go          # cdk8s 主程式 (定義 K8s YAML 生成邏輯)
│   │   ├── pkg/             # 模組化組件 (CICD, Datastore, Observability, Platform)
│   │   ├── dist/            # (Auto-generated) 生成的 K8s YAML 檔案
│   │   ├── setup.sh         # 總指揮：一鍵初始化環境 (Terraform + kubectl + cdk8s)
│   │   └── cleanup.sh       # 總指揮：一鍵清理環境 (含雲端資源銷毀)
│   └── terraform/           # 雲端底層基礎設施 (IaC)
│       ├── aws/             # EKS Fargate (Serverless) + RDS + ElastiCache
│       └── gcp/             # GKE Autopilot (Serverless) + Cloud SQL + Memorystore
├── backend/                 # [開發中] 以 go-zero 驅動的微服務集群
└── frontend/                # [開發中] 前端 Web 應用
```

---

## 🛠 基礎架構技術細節

### 1. Terraform 檔案管理與安全 (Git 規範)
在 `infra/terraform/` 目錄中，您會看到以下檔案，了解其作用對維護至關重要：

*   **`.terraform/` (目錄)**: 存放 Provider (如 AWS/GCP 驅動) 驅動程式。
    *   *處理方式*: **不進入 Git** (已在 .gitignore 排除)。
*   **`terraform.tfstate`**: **最重要的檔案**。它記錄了「雲端真實資源」與「代碼」的對應關係。
    *   *處理方式*: **絕對不可進入 Git**。遺失此檔會導致 Terraform 失去對雲端資源的控制，造成重複扣費。
*   **`.terraform.lock.hcl`**: 鎖定 Provider 版本，確保團隊成員環境一致。
    *   *處理方式*: **應進入 Git**。

### 2. 跨環境服務矩陣
本專案採用 **Environment Parity (環境等價)** 策略，讓開發者在本機與雲端的使用體驗幾乎一致。

| 服務 | Local (Minikube) | Cloud (AWS/GCP) | 說明 |
| :--- | :--- | :--- | :--- |
| **K8s** | Minikube | **EKS Fargate / GKE Autopilot** | 雲端採用全 Serverless 模式，無需管理 Node。 |
| **資料庫** | PostgreSQL (容器) | **RDS / Cloud SQL** | 雲端自動轉為高可用託管服務。 |
| **快取** | Redis (容器) | **ElastiCache / Memorystore** | 雲端自動轉為託管快取。 |
| **連線** | `127.0.0.1` | **Jump Pod (Socat)** | 無論在哪，開發者永遠連線 `127.0.0.1`。 |

---

## 🚀 開發與部署流程 (Workflow)

### 1. 本機開發 (Local Mode)
```bash
cd infra/k8s
./setup.sh local  # 一鍵啟動 Minikube 環境、Linkerd 與資料庫
```
*   **存取**: `http://argocd.local` (ArgoCD), `http://grafana.local` (Grafana)。
*   **資料庫**: 連線 `127.0.0.1:5432` (Postgres) 或 `127.0.0.1:6379` (Redis)。

### 2. 雲端部署 (AWS/GCP Mode)
為了安全，雲端部署流程加入了 **Plan & Confirm** 機制：
```bash
./setup.sh aws   # 或 ./setup.sh gcp
```
**流程說明：**
1.  **自動初始化**: 自動執行 `terraform init`。
2.  **變更預覽 (Plan)**: 腳本會先顯示 `terraform plan` 的結果，列出所有即將在雲端建立、修改或刪除的資源。
3.  **手動確認**: 系統會停下來詢問 `確定要執行這些變更嗎? (yes/no)`。
    *   這防止了誤刪正式資料庫或叢集的風險。
4.  **自動套用**: 輸入 `yes` 後，自動執行 `apply` 並完成 kubectl 認證、cdk8s 部署。

### 3. 環境清理 (Cleanup)
當測試結束，請務必清理環境以節省成本：
```bash
./cleanup.sh aws  # 一鍵刪除雲端所有 VPC, EKS, RDS 等資源
```

---

## 💡 開發注意事項 (Dev Guidelines)

1.  **統一連線地址**: 永遠使用 `127.0.0.1` 作為資料庫 Host。
    *   Local 模式下透過 K8s Service Port-forward。
    *   雲端模式下透過 **Jump Pod** 建立安全隧道。
2.  **密碼管理**: 所有敏感密碼皆定義於 `infra/k8s/.env`。**請勿將含有真實密碼的 .env 提交至 Git**。
3.  **cdk8s 修改**: 若需新增 K8s 服務，請修改 `infra/k8s/pkg/` 下的組件，並執行 `./setup.sh` 重新同步。
4.  **穩定命名 (Stable Names)**: 專案已移除 cdk8s 的隨機 Hash，所有資源名稱皆固定（如 `argocd-server`），方便腳本與監控追蹤。

---
## 📝 目標：打造極致的雲端開發體驗
本專案目標是讓開發者專注於 `backend/` 的業務邏輯，而不需要擔心雲端網路、IAM 權限或資料庫連線的複雜性。

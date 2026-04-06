# Infar：企業級多雲微服務部署與開發平台

本專案是一個集成了 **基礎設施即代碼 (IaC)** 與 **高效能微服務架構** 的現代化平台。我們透過 **cdk8s (Go)**、**Terraform** 與 **go-zero** 打造了一個從本機開發到雲端生產環境（AWS/GCP）全自動化的開發體驗。

---

## 🏗 1. 全域架構總覽

### 1.1 核心技術棧
*   **Infrastructure**: Terraform (雲端資源), cdk8s (K8s 資源物件定義), Helm (組件安裝)。
*   **Backend**: go-zero (微服務框架), gRPC (內部通訊), RESTful (外部網關)。
*   **Database**: PostgreSQL (主資料庫), Redis Stack (快取與訊息佇列)。
*   **Observability**: PLG Stack (Prometheus, Loki, Grafana), Linkerd (Service Mesh)。

### 1.2 專案目錄結構詳解
```text
/
├── infra/                          # 【基礎設施層】
│   ├── k8s/                        # K8s 資源定義與部署
│   │   ├── main.go                 # cdk8s 入口程式：定義 Deployment, Service, Ingress
│   │   ├── pkg/                    # 模組化 K8s 組件 (CICD, Datastore, Observability, Platform)
│   │   ├── dist/                   # 自動生成的 K8s YAML 檔案夾 (由 cdk8s 產出)
│   │   ├── setup.sh                # 🚀 環境部署總指揮：自動切換雲端與本地配置
│   │   ├── cleanup.sh              # 🧹 資源回收總指揮：徹底清理雲端殘留
│   │   ├── .env                    # 環境變數設定檔 (需根據 .env.example 建立)
│   │   └── tests/                  # 驗證腳本：檢查 K8s 元件健康度與 DB 連通性
│   └── terraform/                  # 雲端資源管理
│       ├── aws/                    # EKS Fargate + RDS v2 (Serverless 方案)
│       └── gcp/                    # GKE Autopilot + Cloud SQL (Serverless 方案)
├── backend/                        # 【後端應用層】
│   ├── services/                   # 各個獨立微服務
│   │   └── user/                   # 使用者服務 (包含 api, rpc, model 三層)
│   ├── dev.sh                      # 🛠 開發者神器：一鍵啟動所有服務、自動修復通道
│   ├── init.sql                    # 🗄️ 全域資料庫初始化腳本
│   └── go.mod                      # 後端統一依賴管理 (Module: infar)
└── frontend/                       # 【前端應用層】
```

---

## 🛠 2. 基礎設施部署指南 (Infrastructure Guide)

我們支援三種環境：**Local (Minikube)**、**AWS (EKS)**、**GCP (GKE)**。系統會根據參數自動切換「託管服務」與「自建容器」。

### 2.1 本機開發模式 (Local Mode)
*   **啟動要求**：安裝 Minikube 並執行 `sudo minikube tunnel` (另開視窗)。
*   **一鍵部署**：
    ```bash
    cd infra/k8s
    ./setup.sh local
    ```
*   **特性**：自動安裝 Linkerd Mesh、佈署容器版 Postgres/Redis、匯入 Grafana 戰情室。

### 2.2 雲端生產模式 (AWS/GCP Mode)
*   **部署指令**：`./setup.sh aws` 或 `./setup.sh gcp`。
*   **安全性 (Plan & Confirm)**：
    1.  腳本會先跑 `terraform plan` 讓你預覽雲端變更（例如是否會誤刪資料庫）。
    2.  必須輸入 **`yes`** 才會執行真正的 `terraform apply`。
*   **連線神器 (Jump Pod)**：
    雲端資料庫位於私有網路，腳本會自動在 K8s 內啟動一個 **Jump Pod** 並在本機建立 Tunnel，讓開發者永遠連線 `127.0.0.1:5432` 即可直達雲端 RDS/Cloud SQL。

### 2.3 環境清理 (Cleanup)
測試結束後，請務必執行清理，避免產生高額帳單：
```bash
./cleanup.sh aws   # 會自動銷毀 VPC, EKS, RDS, ElastiCache 等
```

---

## 🐹 3. Backend 微服務開發指南 (go-zero)

### 3.1 微服務三層架構
每個微服務（如 `user`）都必須遵守以下結構：
1.  **`api/` (Gateway 層)**：處理 HTTP/JWT，透過 gRPC 呼叫內層。
2.  **`rpc/` (Logic 層)**：處理核心商業邏輯與資料庫互動。
3.  **`model/` (Data 層)**：對應資料表，具備 Redis 快取機制。

### 3.2 👨‍💻 開發者關注清單 (The Touch List)
開發新功能時，你**只需要**動到以下檔案：

| 檔案類型 | 檔案路徑範例 | 作用 |
| :--- | :--- | :--- |
| **1. API 契約** | `api/desc/*.api` | 定義路由、參數、JWT 規則 |
| **2. RPC 契約** | `rpc/pb/*.proto` | 定義 gRPC 介面與資料結構 |
| **3. 業務大腦** | `rpc/internal/logic/*.go` | **重點：** 寫 SQL 操作與商業規則 |
| **4. 路由轉發** | `api/internal/logic/*.go` | 調用 RPC 客戶端並組裝回傳值 |
| **5. 依賴注入** | `*/internal/svc/servicecontext.go` | 在此實例化 Model 與 RPC Client |
| **6. 客製 SQL** | `model/*model.go` | **Postgres 專屬：** 實作 `RETURNING id` 等語法 |

### 3.3 新增服務標準流程 (SOP)
假設你要新增一個名為 `order` 的服務，請嚴格執行以下步驟：

#### Step 1: 資料庫準備
1.  修改 `backend/init.sql` 加入 `orders` 表定義，並匯入資料庫。
2.  **生成 Model 代碼** (在 `backend/` 目錄執行)：
    ```bash
    goctl model pg datasource \
      -url "postgres://infar_admin:InfarDbPass123@127.0.0.1:5432/infar_db?sslmode=disable" \
      -t "orders" \
      -dir services/order/model -c
    ```

#### Step 2: 定義並生成 RPC 服務
1.  建立 `backend/services/order/rpc/pb/order.proto` 定義介面。
2.  **生成 RPC 代碼** (在 `rpc/` 目錄執行)：
    ```bash
    cd services/order/rpc
    goctl rpc protoc pb/order.proto --go_out=. --go-grpc_out=. --zrpc_out=.
    ```

#### Step 3: 定義並生成 API 網關
1.  建立 `backend/services/order/api/desc/order.api` 定義路由。
2.  **生成 API 代碼** (在 `api/` 目錄執行)：
    ```bash
    cd ../api # 進入 services/order/api
    goctl api go -api desc/order.api -dir .
    ```

#### Step 4: 注入依賴與實作 (關鍵步驟)
1.  **整理依賴**：在 `backend/` 執行 `go mod tidy`。
2.  **注入 Model**：修改 `rpc/internal/svc/servicecontext.go` 注入 `OrdersModel`。
3.  **注入 RPC Client**：修改 `api/internal/svc/servicecontext.go` 注入 `orderclient.Order`。
4.  **寫代碼**：在 `rpc/internal/logic/` 寫入 SQL 邏輯，在 `api/internal/logic/` 呼叫 RPC。
#### Step 5: 納入自動化體系
1.  **修改 `backend/dev.sh`**：加入啟動 `order-rpc` 與 `order-api` 的指令。
2.  **修改 `infra/k8s/main.go`**：加入 cdk8s 部署定義，確保雲端與 Local K8s 都能跑起來。

#### Step 6: 生成 API 文檔
1.  **自動生成 Swagger** (在 `api/` 目錄執行)：
    ```bash
    goctl api swagger -api desc/order.api -dir doc
    ```
2.  **預覽文件**：將 `doc/*.json` 內容貼至 [Swagger Editor](https://editor.swagger.io/) 或使用 VS Code 插件查看。

---

## 🚀 4. 日常開發運維指令

### 4.1 極速啟動開發環境
...
### 4.2 深度驗證與檢測
...
### 4.3 API 文檔管理
*   **生成最新文檔**：進入各服務 `api/` 目錄執行 `goctl api swagger ...`。
*   **全域文檔匯總**：建議未來可導入 Swagger UI 整合至網關中。

```bash
./dev.sh
```
*   **它會幫你做什麼？**
    *   自動偵測並恢復 Postgres/Redis 的 K8s 通道。
    *   並行啟動所有 RPC 與 API 服務。
    *   日誌即時噴發在控制台，方便除錯。
    *   **按下 Ctrl+C** 時，自動殺掉所有子程序，絕不佔用 Port。

### 4.2 深度驗證與檢測
```bash
cd infra/k8s
./tests/verify.sh local
```
*   此腳本會檢測所有 Pod 狀態、測試 Ingress 是否通暢、測試資料庫是否可寫入。

---

## 💡 5. 開發注意事項與陷阱 (Tips)

1.  **統一連線地址**：程式碼中資料庫 Host 永遠寫 `127.0.0.1`，其餘由 `setup.sh` 或 `dev.sh` 處理。
2.  **Postgres ID 回傳**：Postgres 不支援 `LastInsertId()`，必須在 `model` 裡手動實作 `RETURNING id` 方法。
3.  **密碼安全**：`.env` 檔案內含敏感資訊，**禁止提交至 Git**。
4.  **環境變數格式**：Terraform 變數在 Shell 中需以 `TF_VAR_` 開頭。

---
## 📝 目標：打造極致的雲端開發體驗
本專案目標是讓開發者專注於 `backend/` 的業務邏輯，而不需要擔心雲端網路、IAM 權限或資料庫連線的複雜性。

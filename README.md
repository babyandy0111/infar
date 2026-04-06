# Infar：企業級多雲微服務部署與開發平台

本專案提供一個從底層雲端基礎設施（Terraform + cdk8s）到上層微服務應用（go-zero + gRPC）的完整解決方案。我們致力於實現「本機開發與雲端生產環境的一致性」，並透過高度自動化提升開發體驗。

---

## 🏗 1. 全域架構與目錄結構 (Architecture & Structure)

### 1.1 技術棧 (Tech Stack)
*   **基礎設施 (IaC)**: Terraform (雲資源), cdk8s (Go 語言定義 K8s), Helm。
*   **後端框架 (Backend)**: go-zero (微服務大腦), gRPC (內部通訊), JWT (授權)。
*   **資料儲存 (Storage)**: PostgreSQL (主庫), Redis Stack (快取/MQ)。
*   **可觀測性 (Observability)**: Prometheus, Loki, Grafana (PLG Stack), Linkerd Service Mesh。

### 1.2 專案目錄樹
```text
/
├── infra/                          # 【基礎設施層】
│   ├── k8s/                        # K8s 資源定義與部署中心
│   │   ├── main.go                 # cdk8s 入口：定義 Deployment, Service, Ingress 邏輯
│   │   ├── pkg/                    # 模組化組件 (CICD, Datastore, Observability, Platform)
│   │   ├── dist/                   # (Auto-gen) 由 cdk8s 產出的最終 K8s YAML
│   │   ├── setup.sh                # 🚀 部署總指揮：自動切換雲端與本地配置 (含 Terraform)
│   │   ├── cleanup.sh              # 🧹 清理總指揮：徹底銷毀雲端資源避免計費
│   │   ├── .env                    # 環境變數 (需手動從 .env.example 複製並修改)
│   │   └── tests/                  # 驗證腳本：檢查 Pods 健康度與資料庫連通性
│   └── terraform/                  # 雲端 IaC 定義 (IaC)
│       ├── aws/                    # EKS Fargate + RDS v2 + ElastiCache (Serverless)
│       └── gcp/                    # GKE Autopilot + Cloud SQL + Memorystore
├── backend/                        # 【後端應用層】
│   ├── services/                   # 微服務叢集 (如 user, order 等)
│   │   └── user/                   # 使用者服務
│   │       ├── api/                # 對外 RESTful Gateway (含 Swagger docs)
│   │       ├── rpc/                # 對內 gRPC 業務邏輯
│   │       └── model/              # 資料庫對應層 (含客製化 Postgres 邏輯)
│   ├── dev.sh                      # 🛠 開發者神器：一鍵啟動所有服務、自動清理 Port
│   ├── init.sql                    # 🗄️ 全域資料庫初始化定義 (含 RBAC 預設資料)
│   ├── go.mod                      # 後端統一依賴管理 (Module: infar)
│   └── go.sum                      # 依賴版本鎖定
└── frontend/                       # 【前端應用層 - 開發中】
```

---

## 🛠 2. 基礎設施部署指南 (Infrastructure Guide)

我們支援 **Local**, **AWS**, **GCP** 三種環境，透過 `setup.sh` 實現環境對接。

### 2.1 本機開發環境 (Local Mode)
*   **叢集工具**: Minikube。
*   **重要前置**: 在獨立視窗執行 `sudo minikube tunnel` 以處理 Ingress 流量。
*   **一鍵初始化**:
    ```bash
    cd infra/k8s
    ./setup.sh local
    ```
*   **功能特性**: 自動安裝 Linkerd Mesh、佈署容器版 DB/Redis、匯入 7 大 Grafana 戰情室。

### 2.2 雲端生產環境 (AWS/GCP Mode)
*   **部署指令**: `./setup.sh aws` 或 `./setup.sh gcp`。
*   **安全預覽機制 (Plan & Confirm)**:
    1. 腳本會自動執行 `terraform plan` 並列出變更。
    2. **強制手動確認**: 必須輸入 `yes` 才會執行 `apply`，防止誤刪正式環境資料。
*   **資料庫存取 (Jump Pod)**:
    雲端資料庫位於私有網路。`setup.sh` 會自動佈署一個 **Jump Pod** 並建立隧道。開發者無論在本地還是雲端，Host 統一連線 `127.0.0.1:5432` 即可。

### 2.3 環境驗證與清理
*   **驗證**: `./tests/verify.sh local` (檢查 Pod 狀態、資料庫讀寫、Ingress 連通性)。
*   **清理**: `./cleanup.sh aws` (強制銷毀所有 VPC, EKS, RDS, EIP 資源)。

---

## 🐹 3. Backend 微服務開發指南 (go-zero)

### 3.1 👨‍💻 開發者關注清單 (The Touch List)
開發新功能時，你 **只需要** 關注以下檔案，其餘由工具生成：

| 檔案類型 | 範例路徑 | 作用 |
| :--- | :--- | :--- |
| **1. API 契約** | `api/desc/*.api` | 定義路由、參數、JWT 規則 |
| **2. RPC 契約** | `rpc/pb/*.proto` | 定義 gRPC 介面與資料編號 |
| **3. 業務大腦** | `rpc/internal/logic/*.go` | **核心：** 實作 SQL 操作與商業規則 |
| **4. 網關轉發** | `api/internal/logic/*.go` | 解析 JWT、呼叫 RPC 並組裝回傳值 |
| **5. 依賴注入** | `*/internal/svc/servicecontext.go` | 實例化 Model 與 RPC 客戶端 |
| **6. 客製 SQL** | `model/*model.go` | **重點：** 實作 Postgres 專用語法 (如 Returning ID) |

### 3.2 新增服務標準 SOP (以 `order` 服務為例)

#### Step 1: 資料庫與 Model
1. 修改 `backend/init.sql` 加表，匯入 DB：
   ```bash
   kubectl exec -i postgres-0 -c postgresql -n infra -- env PGPASSWORD=InfarDbPass123 psql -U infar_admin -d infar_db < backend/init.sql
   ```
2. 生成 Model (在 `backend/` 目錄)：
   ```bash
   goctl model pg datasource -url "postgres://..." -t "orders" -dir services/order/model -c
   ```

#### Step 2: 定義並生成 RPC 服務 (於 `services/your_service/rpc` 目錄執行)
1.  **快速產出模版**: 執行 `goctl rpc template -o pb/order.proto`。
2.  **修改定義**: 編輯 `pb/order.proto`。
3.  **生成 Go 代碼**: `goctl rpc protoc pb/order.proto --go_out=. --go-grpc_out=. --zrpc_out=.`。
4.  **⚠️ 習慣性清理**: 執行 `rm pb.go etc/pb.yaml` 以免編譯報錯。

#### Step 3: 定義並生成 API 網關 (於 `services/your_service/api` 目錄執行)
1.  **快速產出模版**: 執行 `goctl api template -o desc/order.api`。
2.  **修改定義**: 編輯 `desc/order.api`。
3.  **生成 Go 代碼**: `goctl api go -api desc/order.api -dir .`。

#### Step 4: 實作邏輯
1. 在 `rpc/internal/svc/servicecontext.go` 初始化 Model。
2. 在 `logic/` 目錄撰寫你的業務程式碼。

### 3.4 打包與發佈 (GitOps SOP)
本專案採組件化管理，每個服務皆具備獨立的 `docker/` 與 `k8s/` 資料夾。發佈時請統一在 `backend/` 目錄下執行指令。

#### Step 1: 容器化與推送 (於 `backend/` 目錄執行)
此步驟將程式打包成 Docker 鏡像並推送到 Docker Hub 倉庫。
1.  **打包與推送 User RPC**:
    ```bash
    docker build -t babyandy0111/infar-user-rpc:v1 -f services/user/rpc/docker/Dockerfile .
    docker push babyandy0111/infar-user-rpc:v1
    ```
2.  **打包與推送 User API**:
    ```bash
    docker build -t babyandy0111/infar-user-api:v1 -f services/user/api/docker/Dockerfile .
    docker push babyandy0111/infar-user-api:v1
    ```

#### Step 2: 產生 K8s 部署清單 (於 `backend/` 目錄執行)
使用 `goctl` 產出 K8s 部署 YAML，並存放在該服務的 `k8s/` 資料夾中。
1.  **產生 RPC 部署檔**:
    ```bash
    goctl kube deploy \
      -name user-rpc \
      -namespace app \
      -image babyandy0111/infar-user-rpc:v1 \
      -port 9090 \
      -o services/user/rpc/k8s/user-rpc.yaml
    ```
2.  **產生 API 部署檔**:
    ```bash
    goctl kube deploy \
      -name user-api \
      -namespace app \
      -image babyandy0111/infar-user-api:v1 \
      -port 8888 \
      -o services/user/api/k8s/user-api.yaml
    ```

#### Step 3: GitOps 同步 (ArgoCD)
1.  **提交變更**: `git add . && git commit -m "deploy: update user service" && git push`。
2.  **ArgoCD 自動化**: ArgoCD 偵測到 Git 倉庫內的 `k8s/*.yaml` 變更後，會自動將新版鏡像應用到 K8s 叢集。

---

## 🚀 4. 日常開發運維指令 (DevX)

### 4.1 智慧啟動神器 (`dev.sh`)
進入 `backend/` 目錄執行：
```bash
./dev.sh
```
*   **自動化流程**: 
    1. **暴力清場**: 自動殺掉佔用 8888, 9090 的舊程序，解決 `Address already in use`。
    2. **通道修復**: 自動檢查並恢復 K8s 內的 Postgres/Redis 連線。
    3. **文檔同步**: 自動掃描 Go 註解並產生 Swagger JSON。
    4. **並行啟動**: 同時跑起所有的 RPC 與 API 服務。
    5. **秒殺終止**: 按下 **一次 Ctrl+C**，透過 **PGID (Process Group)** 機制瞬間清空所有子程序，絕不殘留。

### 4.2 API 文檔中心 (Swagger UI)
啟動 `./dev.sh` 後，直接存取：
👉 **http://127.0.0.1:8888/swagger**
*   **Authorize**: 直接貼入 JWT Token 即可進行線上調試。
*   **Tags**: 支援自定義分組（在 Handler 使用 `@Tags` 註解）。

---

## 💡 5. 開發陷阱與注意事項 (Tips)

1.  **Postgres ID 回傳**: Postgres 不支援 `LastInsertId()`。我們已在 `model` 層實作 `InsertWithId` 並使用 `RETURNING id` 語法，請以此為標準。
2.  **Nullable 欄位處理**: 
    *   資料庫設定為 `NULL` 的欄位，在 Go 中會映射為 `sql.NullString` 等。
    *   **讀取**: 使用 `profile.Nickname.String`。
    *   **判斷**: 使用 `profile.Nickname.Valid`。
3.  **變數重複宣告**: 若遇到 `configFile redeclared` 錯誤，通常是 `goctl` 在 `rpc/` 目錄多生了一個 `pb.go`，直接刪除該檔即可。
4.  **JWT Secret 安全**: 所有密鑰皆定義於 `etc/*.yaml`，生產環境將透過 K8s Secret 注入。

---
## 📝 目標：打造極致的雲端開發體驗
本專案目標是讓開發者專注於 `backend/` 的業務邏輯，而不需要擔心雲端網路、IAM 權限或資料庫連線的複雜性。

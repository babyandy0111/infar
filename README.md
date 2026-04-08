# Infar：企業級多雲微服務部署與開發平台

本專案提供一個從底層雲端基礎設施（Terraform + cdk8s）到上層微服務應用（go-zero + gRPC）的完整解決方案。我們致力於實現「本機開發與雲端生產環境的一致性」，並透過高度自動化提升開發體驗。

> **👋 歡迎加入 Infar 後端團隊！**
> 如果你是剛接觸 `go-zero` 或是微服務的新手，請不用擔心。本專案已經將繁瑣的 K8s 部署、編譯、目錄結構全部「腳本化」。你只需要專注於閱讀這份文件的 **第 3 節 (開發指南)**，跟著指令貼上，就能輕鬆寫出你的第一個微服務！

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
├── infra/                          # 【基礎設施層】(DevOps/架構師專區)
│   ├── k8s/                        # K8s 資源定義與部署中心
│   │   ├── main.go                 # cdk8s 入口：定義 Deployment, Service, Ingress 邏輯
│   │   ├── pkg/                    # 模組化組件 (CICD, Datastore, Observability, Platform)
│   │   ├── dist/                   # (Auto-gen) 由 cdk8s 產出的最終 K8s YAML
│   │   ├── setup.sh                # 🚀 部署總指揮：自動切換雲端與本地配置 (含 Terraform)
│   │   ├── cleanup.sh              # 🧹 清理總指揮：徹底銷毀雲端資源避免計費
│   │   ├── .env                    # 環境變數 (需手動從 .env.example 複製並修改)
│   │   └── tests/                  # 驗證腳本：檢查 Pods 健康度與資料庫連通性
│   └── terraform/                  # 雲端 IaC 定義 (IaC)
│       ├── aws/                    # EKS Fargate + RDS v2 + ElastiCache (Serverless 方案)
│       └── gcp/                    # GKE Autopilot + Cloud SQL + Memorystore
├── backend/                        # 【後端應用層】(🔥 後端開發者專區)
│   ├── services/                   # 微服務叢集 (如 user, order 等)
│   │   └── user/                   # 使用者服務
│   │       ├── api/                # 對外 RESTful Gateway (含 Swagger docs)
│   │       ├── rpc/                # 對內 gRPC 業務邏輯
│   │       └── model/              # 資料庫對應層 (含客製化 Postgres 邏輯)
│   ├── dev.sh                      # 🛠 開發者神器：一鍵啟動所有服務、自動清理 Port
│   ├── gen_service.sh              # 🪄 服務生產線：一鍵產出微服務全套代碼
│   ├── apihub.go                   # 🌐 統一文檔中心：整合所有微服務的 Swagger
│   ├── init.sql                    # 🗄️ 全域資料庫初始化定義 (含 RBAC 預設資料)
│   └── go.mod                      # 後端統一依賴管理 (Module: infar)
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

## 🐹 3. Backend 微服務開發指南 (手把手教學篇)

> 💡 **為什麼要分 API 和 RPC 兩層？**
> *   **API 層 (對外)**：就像餐廳的「服務生」。負責接收 HTTP 請求、檢查 JWT Token、處理參數驗證，然後把單子交給內場。
> *   **RPC 層 (對內)**：就像餐廳的「廚師」。專注於商業邏輯與資料庫 (Model) 存取，不直接接觸外部網路，最為安全。

### 3.1 👨‍💻 核心關注清單 (你只需要改這些檔案)
建立好服務後，你 **只需要** 在以下檔案寫 code，其他的配置檔腳本都會幫你處理好：

| 檔案類型 | 檔案路徑範例 | 作用 (你要做什麼) |
| :--- | :--- | :--- |
| **1. 路由定義** | `api/desc/*.api` | 定義對外的網址 (URL)、傳入參數與回傳格式。 |
| **2. 內部介面** | `rpc/pb/*.proto` | 定義 RPC 的函數名稱與資料結構。 |
| **3. 業務大腦** | `rpc/internal/logic/*.go` | **核心：** 這裡寫主要的判斷邏輯、呼叫資料庫 (Model)。 |
| **4. 網關轉發** | `api/internal/logic/*.go` | 這裡只做一件事：呼叫 RPC，並把結果轉成 JSON 回傳。 |
| **5. 客製 SQL** | `model/*model.go` | (非必改) 如果自動產生的 CRUD 不夠用，來這裡寫複雜的 SQL 關聯查詢。 |

### 3.2 🚀 【極速版】新增服務 SOP (使用 `gen_service.sh`)
這是本專案推薦的開發方式，腳本會幫你搞定一切雜活！以建立 `order` (訂單) 服務為例：

#### Step 1: 建立資料表
1. 打開 `backend/init.sql`，加上你的 `orders` 資料表定義。
2. 將表匯入本地資料庫：
   ```bash
   kubectl exec -i postgres-0 -c postgresql -n infra -- env PGPASSWORD=InfarDbPass123 psql -U infar_admin -d infar_db < backend/init.sql
   ```

#### Step 2: 執行一鍵生產腳本
進入 `backend/` 目錄，執行我們專屬的生產腳本：
```bash
# 用法: ./gen_service.sh <服務名> <資料表名> <API埠號> <RPC埠號>
./gen_service.sh order orders 8889 9091
```
> **腳本會自動幫你：**
> 1. 自動拉取 DB 產生 Model 代碼。
> 2. 自動產生 RPC 和 API 的骨架 (包含基礎的 `.api` 和 `.proto`)。
> 3. **自動完成依賴注入 (DI)**：幫你把 Config 寫好，確保編譯能過。
> 4. 自動產生 Dockerfile 與 K8s YAML 部署檔。

#### Step 3: 開始寫你的商業邏輯！
1. 去修改 `api/desc/order.api` 和 `rpc/pb/order.proto`，加上你要的功能。
2. 執行 `goctl` 更新代碼（詳見下方 3.3 節）。
3. 到 `logic` 目錄下寫代碼。完成！

---

### 3.3 🛠️ 【手動/進階版】更新與生成代碼 (底層原理)
如果你修改了 `.api` 或是 `.proto`，你需要「手動」告訴 `goctl` 幫你更新 Go 程式碼。
*(這也是腳本 `gen_service.sh` 內部在做的事情)*

**1. 更新 RPC 服務 (改了 `.proto` 之後)：**
於 `services/你的服務/rpc` 目錄執行：
```bash
goctl rpc protoc pb/你的服務.proto --go_out=. --go-grpc_out=. --zrpc_out=.
```
**⚠️ 習慣性清理**：執行完後，請**務必**手動執行 `rm pb.go etc/pb.yaml`！`goctl` 會產生多餘的進入點檔案，不刪掉會導致編譯報錯 (`redeclared in this package`)。

**2. 更新 API 網關 (改了 `.api` 之後)：**
於 `services/你的服務/api` 目錄執行：
```bash
goctl api go -api desc/你的服務.api -dir .
```

**3. 更新 Model (改了 DB 之後)：**
於 `backend/` 目錄執行：
```bash
goctl model pg datasource -url "postgres://infar_admin:InfarDbPass123@127.0.0.1:5432/infar_db?sslmode=disable" -t "你的表名" -dir services/你的服務/model -c
```

---

### 3.4 📦 打包與發佈 (GitOps SOP)
本專案採組件化管理，每個服務皆具備獨立的 `docker/` 與 `k8s/` 資料夾。發佈時請統一在 `backend/` 目錄下執行。

#### Step 1: 容器化與推送 (生產貨物)
1.  **打包與推送 RPC**:
    ```bash
    docker build -t 你的Docker帳號/infar-user-rpc:v1 -f services/user/rpc/docker/Dockerfile .
    docker push 你的Docker帳號/infar-user-rpc:v1
    ```
2.  **打包與推送 API**:
    ```bash
    docker build -t 你的Docker帳號/infar-user-api:v1 -f services/user/api/docker/Dockerfile .
    docker push 你的Docker帳號/infar-user-api:v1
    ```

#### Step 2: 產生 K8s 部署清單 (更新清單)
使用 `goctl` 產出 K8s 部署 YAML，並存放在該服務的 `k8s/` 資料夾中。*(如果用 gen_service.sh，這步已自動完成)*
```bash
# 產生範例
goctl kube deploy -name user-rpc -namespace app -image 你的Docker帳號/infar-user-rpc:v1 -port 9090 -o services/user/rpc/k8s/user-rpc.yaml
```

#### Step 3: GitOps 同步 (ArgoCD 送貨)
1.  **提交變更**: `git add . && git commit -m "deploy: update service" && git push`。
2.  **ArgoCD 自動化**: ArgoCD 偵測到 Git 倉庫內的 `k8s/*.yaml` 變更後，會自動將新版鏡像應用到 K8s 叢集。

---

## 🚀 4. 日常開發運維指令 (DevX)

### 4.1 🛠️ 智慧啟動神器 (`dev.sh`)
進入 `backend/` 目錄執行：
```bash
./dev.sh
```
*   **暴力清場**: 自動殺掉佔用 8888, 9090 的舊程序，解決 `Address already in use` 錯誤。
*   **通道修復**: 自動檢查並恢復 K8s 內的 Postgres/Redis Port-forward 連線。
*   **並行啟動**: 同時跑起所有的 RPC 與 API 服務。
*   **秒殺終止**: 按下 **一次 Ctrl+C**，透過 **PGID (Process Group)** 機制瞬間清空所有子程序，絕不殘留！

### 4.2 🌐 統一 API 文檔中心 (Swagger Hub)
執行 `./dev.sh` 後，系統會自動收集所有微服務的 API 文件，請用瀏覽器開啟：
👉 **http://127.0.0.1:8000**
*   **下拉選單切換**：在網頁上方可自由切換 `User Service`, `Order Service` 等。
*   **JWT 測試**：點擊右上方 **Authorize** 按鈕，直接貼入 Token 即可進行實機連線測試。
*   (註：各服務獨立的 Swagger 依然可以透過對應的 Port 存取，如 `8888/swagger`)

---

## 💡 5. 開發陷阱與注意事項 (避坑指南)

請新手務必閱讀此區塊，這裡記錄了團隊踩過的血淚史：

1.  **Postgres ID 回傳問題**: 
    Postgres 的原生驅動不支援 `LastInsertId()`。如果你需要拿到新增後的 ID，請不要用預設的 `Insert`，務必在 `model` 裡實作 `RETURNING id` 語法（參考 `usersmodel.go`）。
2.  **Nullable 欄位 (可為空值) 的坑**: 
    資料庫設定為 `NULL` 的欄位，在 Go 中會變成 `sql.NullString` 或 `sql.NullInt64`。
    *   **不要直接取值**！請使用 `.String` 或 `.Int64` 來讀取。
    *   **判斷是否為空**：使用 `.Valid` 屬性判斷。
3.  **變數重複宣告 (`redeclared in this package`)**: 
    如果在 `rpc` 目錄下發生這個編譯錯誤，絕對是因為 `goctl` 又幫你生了一個多餘的 `pb.go`，請直接把它刪掉。
4.  **改了 `.api` 後編譯報錯 (`assignment mismatch`)**: 
    如果你在 `.api` 檔案裡將某個路由加上了 `returns (Response)`，請記得去對應的 `logic/*.go` 檔案中，把函數的**回傳值簽名補上** (加上 `resp *types.Response`)，否則 Go 編譯器會因為回傳數量不對而報錯。
5.  **依賴注入找不到變數 (`Unresolved reference`)**:
    如果 `ServiceContext` 報錯說找不到 `OrderRpc` 或 `DataSource`，請先檢查你的 `internal/config/config.go`，確認你是否有把該變數定義在 Struct 裡面。
6.  **K8s 內部 Redis 密碼 (`NOAUTH` 錯誤)**: 
    本專案 K8s 環境內的 Redis 預設密碼為 **`InfarDbPass123`**。在填寫 `.yaml` 設定檔（或 K8s ConfigMap）時，必須正確填寫 `Pass` 欄位，否則 RPC 會報錯。
7.  **ArgoCD 改了 ConfigMap 卻沒生效？**: 
    K8s 預設只監控 Deployment 本身的變動。若只改 ConfigMap，Pod 不會重啟。**請務必隨手修改 Deployment 裡的 `annotations: infar.io/config-last-updated` 戳記**，以觸發自動滾動更新。

---
## 📝 目標：打造極致的雲端開發體驗
本專案目標是讓開發者專注於 `backend/` 的業務邏輯，而不需要擔心雲端網路、IAM 權限或資料庫連線的複雜性。

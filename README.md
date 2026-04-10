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
│   │   └── tests/                  # 驗證腳本：檢查 Pods 健康度與資料庫連通性
│   └── terraform/                  # 雲端 IaC 定義 (IaC)
│       ├── aws/                    # EKS Fargate + RDS v2 + ElastiCache (Serverless 方案)
│       └── gcp/                    # GKE Autopilot + Cloud SQL + Memorystore
├── backend/                        # 【後端應用層】(🔥 後端開發者專區)
│   ├── services/                   # 微服務叢集 (如 user, order 等)
│   │   └── user/                   # 使用者服務
│   ├── dev.sh                      # 🛠 開發者神器：一鍵啟動所有服務、自動清理 Port
│   ├── gen_service.sh              # 🪄 服務生產線：一鍵產出微服務全套代碼 (DB-First)
│   ├── apihub.go                   # 🌐 統一文檔中心：整合所有微服務的 Swagger
│   ├── init.sql                    # 🗄️ 全域資料庫初始化定義
│   └── go.mod                      # 後端統一依賴管理
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
> *   **API 層 (對外)**：接收 HTTP 請求、檢查 JWT Token、處理參數驗證，然後把單子交給內場。
> *   **RPC 層 (對內)**：專注於商業邏輯與資料庫 (Model) 存取，不直接接觸外部網路，最為安全。

在 Infar 中，我們採用 **DB-First (資料庫驅動)** 的開發模式。只要有資料表，腳本就能幫你寫出 90% 的代碼。

### 3.1 🚀 第一步：使用 `gen_service.sh` 產出服務

當你需要建立一個新服務（例如 `product`）時，請依照以下步驟：

#### 1. 建立資料表
打開 `backend/init.sql`，加上你的資料表定義。並將表匯入本地資料庫：
```bash
kubectl exec -i postgres-0 -c postgresql -n infra -- env PGPASSWORD=InfarDbPass123 psql -U infar_admin -d infar_db < backend/init.sql
```

#### 2. 執行一鍵生產腳本
進入 `backend/` 目錄，執行腳本。只需給予 **服務名**、**表名** 與 **Port後三碼** (API 會分配 8xxx, RPC 分配 9xxx)：
```bash
cd backend
./gen_service.sh product products 890
```
> **🛡️ 防呆機制 (Safety First)**：
> 若該服務（如 `product`）已存在，腳本會**拒絕執行**，以保護您已撰寫的業務邏輯不被洗掉。
> * **局部更新**：若您只是加了資料表欄位，請參考下方的「手動更新代碼」流程。
> * **強制重建**：若您確信要徹底覆蓋重建，請加上 `--force` 參數：
>   `./gen_service.sh --force product products 890`

> **🪄 腳本會展現什麼魔法？**
> 1. 自動讀取 DB 欄位，產生帶有 Redis 快取機制的 `Model`。
> 2. 自動將 DB 欄位轉換成 `.api` 與 `.proto` 的請求結構。
> 3. 自動產生 RPC (9890) 和 API (8890) 的 Go 程式碼，並修復設定檔路徑。
> 4. 自動完成 `ServiceContext` 的依賴注入。

---

### 3.2 📝 第二步：開發 CRUD 商業邏輯

腳本已經幫你建好了所有的「管線」，你只需要在 **Logic 層** 填入真正的商業邏輯。

#### 1. RPC 層實作 (與資料庫互動)
打開 `services/{name}/rpc/internal/logic/createlogic.go`，解除註解並實作：
```go
// 呼叫 Model 寫入資料庫
_, err := l.svcCtx.ProductsModel.Insert(l.ctx, &model.Products{
    Name:  in.Name,
    Price: in.Price,
})
```

#### 2. API 層實作 (轉發請求給 RPC)
打開 `services/{name}/api/internal/logic/createlogic.go`：
```go
// 呼叫 RPC Client
rpcResp, err := l.svcCtx.ProductRpc.Create(l.ctx, &product.CreateReq{
    Name:  req.Name,
})
```

---

### 3.3 ⚡ 第三步：如何使用快取 (Redis Cache)

`gen_service.sh` 預設會為你產生 **帶有 Cache 機制** 的 Model。
*   **自動化**: 你只需呼叫 `l.svcCtx.XXXModel.FindOne(ctx, id)`，系統會自動先查 Redis，沒中才查 DB 並回填 Redis。
*   **一致性**: 當你呼叫 `Update` 或 `Delete` 時，系統會自動清除對應的 Redis Key (Cache Aside 策略)。

---

### 3.4 🤝 第四步：跨服務溝通 (Service-to-Service)

微服務之間互相呼叫的標準流程 (以 `order-api` 呼叫 `user-rpc` 為例)：

1.  **YAML**: 在 `order-api.yaml` 加入 `UserRpc` 的 `Endpoints`。
2.  **Config**: 在 `api/internal/config/config.go` 加入 `UserRpc zrpc.RpcClientConf`。
3.  **SvcCtx**: 在 `api/internal/svc/servicecontext.go` 引入 `userclient` 並初始化 `UserRpc`。

---

### 3.5 📖 第五步：自動化 Swagger API 文件

本專案內建強大的動態 API Hub。
1.  執行 `./dev.sh` 啟動所有服務。
2.  開啟：👉 **http://127.0.0.1:8000**
3.  **自動收錄**：只要服務成功啟動，API Hub 會自動掃描並在選單中呈現。
4.  **手動更新**: 若修改了 `.api` 檔案，請在該服務 api 目錄執行 `swag init -q -g 服務名.go`。

---

## 🚀 4. 日常開發運維指令 (DevX)

### 4.1 🛠️ 智慧啟動神器 (`dev.sh`)
進入 `backend/` 目錄執行 `./dev.sh`：
*   **動態清場**: 自動清理 Port 佔用。
*   **通道修復**: 自動修復 K8s 隧道。
*   **秒殺終止**: 按下一次 Ctrl+C 即可清空所有子程序。

### 4.2 🔄 手動更新代碼 (局部更新)
當服務已存在，且您只是修改了 `.api`, `.proto` 或資料庫結構時，為了避免 `--force` 覆蓋掉自定義設定，請進行「局部手動更新」（請在 `backend/` 根目錄下執行，務必帶上 `--home .goctl`）：

*   **更新 RPC (改了 `.proto` 後)**:
    ```bash
    goctl rpc protoc services/xxx/rpc/pb/xxx.proto --proto_path=services/xxx/rpc/pb --go_out=services/xxx/rpc --go-grpc_out=services/xxx/rpc --zrpc_out=services/xxx/rpc -c --home .goctl
    ```
*   **更新 API (改了 `.api` 後)**:
    ```bash
    goctl api go -api services/xxx/api/desc/xxx.api -dir services/xxx/api --home .goctl
    ```
*   **更新 Model (改了 DB 後)**:
    ```bash
    goctl model pg datasource -url "postgres://infar_admin:InfarDbPass123@127.0.0.1:5432/infar_db?sslmode=disable" -t "您的表名" -dir services/xxx/model -c
    ```

---

## 💡 5. 開發陷阱與注意事項 (避坑指南)

1.  **Postgres ID 回傳**: 務必在 `model` 實作 `RETURNING id` (參考 `usersmodel.go`)。
2.  **Nullable 欄位**: 資料庫的 `NULL` 在 Go 中會變成 `sql.NullString`，請使用 `.String` 取值。
3.  **變數重複宣告**: 若 RPC 噴出此錯誤，請檢查是否有殘留的 `pb.go`。
4.  **ArgoCD 更新**: 修改 ConfigMap 後，請務必手動微調 Deployment 裡的 `config-last-updated` 戳記以觸發 Pod 重啟。

---
## 📝 目標：打造極致的雲端開發體驗
本專案目標是讓開發者專注於 `backend/` 的業務邏輯，而不需擔心基礎設施的複雜性。

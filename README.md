# Infar 微服務基礎設施專案 (Phase 1)

本專案旨在建立一個基於 **Kubernetes (K8s)** 的現代化微服務開發與部署環境。第一階段已完成核心基礎設施的建置，包含資料庫、快取、GitOps 部署工具及日誌監控系統。

## 🏗 第一階段：核心組件 (Core Components)

| 組件 | 服務內容 | 部署方式 | 特色 |
| :--- | :--- | :--- | :--- |
| **PostgreSQL** | 基礎關聯式資料庫 | Helm (Bitnami) | Standalone 模式，資源優化，密碼使用 K8s Native Secret 動態生成 |
| **Redis Stack** | 快取與搜尋引擎 | K8s Manifest | 內建 RediSearch 模組，密碼使用 K8s Native Secret |
| **ArgoCD** | GitOps 自動化部署 | Helm (Argo) | 預設管理員: `admin`, 密碼: `admin123` |
| **PLG Stack** | 日誌與監控系統 | Helm (Grafana) | 包含 Loki, Promtail, Grafana 以及 Prometheus |
| **Ingress** | 統一入口網關 | Nginx Ingress | 支援 `.local` 虛擬域名存取 |
| **Linkerd** | 服務網格 (Service Mesh) | CLI 部署 | `infra` 空間已開啟自動注入，支援流量觀測與 mTLS |

---

## 💻 本機開發環境 (Minikube) 部署指南

本專案針對 macOS + Minikube (Docker Driver) 環境進行了極致優化，實現「一鍵啟動」。

### 1. 快速安裝
進入 `k8s/infra` 目錄並執行安裝腳本：
```bash
cd k8s/infra
./setup.sh
```
*腳本會自動檢查依賴、安裝 Helm、動態生成 ArgoCD 加密密碼，並自動將網域寫入 `/etc/hosts`。*

### 2. 網路存取 (Networking)
由於 macOS Docker 網路隔離，請在**另一個終端機視窗**持續執行：
```bash
sudo minikube tunnel
```
現在您可以直接存取以下網址：
*   **ArgoCD**: [http://argocd.local](http://argocd.local)
*   **Grafana**: [http://grafana.local](http://grafana.local)

### 3. 環境驗證
執行自動化測試腳本，確保所有服務與模組 (如 RediSearch) 正常運作：
```bash
./tests/verify.sh
```

---

## ☁️ AWS 生態系部署重點 (Production-Ready)

當您準備將此架構推向 AWS EKS 時，請參考以下轉移重點：

### 1. 基礎設施對接 (Infrastructure Mapping)
*   **Ingress**: 在 AWS 上，`ingressClassName` 應由 `nginx` 改為 `alb`。這會觸發 AWS Load Balancer Controller 自動建立 AWS ALB。
*   **Storage**: PostgreSQL 與 Redis 的 `PersistentVolumeClaim` 會自動觸發 AWS EBS CSI Driver，在 AWS 建立 EBS 磁碟。
*   **Domain**: 將 `*.local` 替換為您在 Route53 託管的真實網域。

### 2. 關鍵配置變更 (Values YAML)
針對 AWS 環境，只需建立新的 `aws-values.yaml` 覆蓋以下區塊：
```yaml
# 以 ArgoCD 為例
server:
  ingress:
    ingressClassName: alb
    annotations:
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
    hostname: argocd.your-domain.com
```

### 3. 安全強化 (Security)
*   **TLS/SSL**: 在 AWS 上建議使用 **ACM (AWS Certificate Manager)**，並在 Ingress Annotations 中引用憑證 ARN。
*   **IAM**: 透過 **IRSA (IAM Roles for Service Accounts)** 為 Pods 賦予最低權限的 AWS 存取能力。

---

## 📂 目錄結構
```text
k8s/
└── infra/
    ├── helm-values/    # 各服務的 Helm 設定檔
    ├── manifests/      # 原生 K8s 部署檔
    ├── tests/          # 自動化驗證腳本
    └── setup.sh        # 一鍵安裝腳本 (含 Linkerd 與 Secrets)
```

---
## 📝 未來擴展計畫 (Phase 2 & Beyond)
- [ ] **Horizontal Pod Autoscaler (HPA)**：為後端微服務與基礎設施 (如 PostgreSQL Replicas) 加入基於 CPU/Memory 的自動擴縮容配置，模擬真實雙 11 流量尖峰的高可用性架構。
- [ ] **go-zero 微服務開發**：啟動 `backend/` 下的微服務實作，結合 ArgoCD 實現 CI/CD。


# Infar 微服務基礎設施專案 (Phase 1)

本專案旨在建立一個基於 **Kubernetes (K8s)** 的現代化微服務開發與部署環境。第一階段已完成核心基礎設施的建置，包含資料庫、快取、GitOps 部署工具、日誌監控及服務網格。

## 🏗 第一階段：核心組件 (Core Components)

| 組件 | 服務內容 | 部署方式 | 特色 |
| :--- | :--- | :--- | :--- |
| **PostgreSQL** | 基礎關聯式資料庫 | Helm (Bitnami) | Standalone 模式，密碼由 K8s Secret 動態隨機生成 |
| **Redis Stack** | 快取與搜尋引擎 | K8s Manifest | 內建 RediSearch 模組，密碼使用 K8s Secret 安全管理 |
| **ArgoCD** | GitOps 自動化部署 | Helm (Argo) | 預設管理員: `admin`, 密碼: `admin123` |
| **PLG Stack+** | 日誌與指標監控 | Helm (Grafana) | Loki, Promtail, Grafana 以及 **Prometheus** 指標收集 |
| **Ingress** | 統一入口網關 | Nginx Ingress | 支援 `.local` 虛擬域名存取 |
| **Linkerd** | 服務網格 (Service Mesh) | CLI 部署 | 開啟 mTLS 自動加密與流量觀測，`infra` 空間已自動注入 |

---

## 💻 本機開發環境 (Minikube) 部署指南

本專案針對 macOS + Minikube (Docker Driver) 環境進行了極致優化，實現「一鍵啟動」。

### 1. 快速安裝
進入 `k8s/infra` 目錄並執行安裝腳本：
```bash
cd k8s/infra
./setup.sh
```
*腳本會自動安裝 Helm/Linkerd、產生動態 Secrets、並自動將網域寫入 `/etc/hosts` 指向 `127.0.0.1`。*

### 2. 網路存取 (Networking)
由於 macOS Docker 網路隔離，必須在**另一個終端機視窗**持續執行隧道：
```bash
sudo minikube tunnel
```
現在您可以直接存取以下網址：
*   **ArgoCD**: [http://argocd.local](http://argocd.local) (密碼: `admin123`)
*   **Grafana**: [http://grafana.local](http://grafana.local) (密碼: `admin`)

### 3. 可觀測性工具 (Observability)
*   **查看日誌/指標**: 存取 Grafana 即可看到 Loki 與 Prometheus 數據。
*   **查看流量拓撲**: 執行 `linkerd viz dashboard` 開啟 Service Mesh 視覺化介面。

---

## ☁️ AWS 生態系部署重點 (Production-Ready)

當您準備將此架構推向 AWS EKS 時，請參考以下轉移重點：

### 1. 基礎設施對接 (Infrastructure Mapping)
*   **Ingress**: 於 AWS 上將 `ingressClassName` 設為 `alb`，對接 AWS ALB。
*   **Storage**: PVC 會自動觸發 AWS EBS CSI Driver 建立磁碟。
*   **Secrets**: 建議將 `setup.sh` 中的 Secret 生成邏輯對接到 **AWS Secrets Manager**。

### 2. 關鍵配置變更 (Values YAML)
針對 AWS 環境，只需建立新的 `aws-values.yaml` 覆蓋 `ingressClassName: alb` 與真實網域設定。

---

## 📂 目錄結構
```text
k8s/
└── infra/
    ├── helm-values/    # 各服務的 Helm 設定檔
    ├── manifests/      # 原生 K8s 部署檔 (如 Redis Stack)
    ├── tests/          # 自動化驗證腳本 (verify.sh)
    └── setup.sh        # 一鍵安裝腳本 (含 Linkerd 與 Secrets)
```

---
## 📝 未來擴展計畫 (Phase 2 & Beyond)
- [ ] **Horizontal Pod Autoscaler (HPA)**：為微服務加入自動擴縮容配置。
- [ ] **go-zero 微服務開發**：啟動 `backend/` 下的微服務實作，結合 ArgoCD 實現 CI/CD。

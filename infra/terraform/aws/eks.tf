module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31" # 使用最新的穩定版本

  # 叢集存取設定
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # ---------------------------------------------------------
  # 🏆 Fargate 核心配置 (Serverless)
  # ---------------------------------------------------------
  # 🚀 關鍵修復：強制 CoreDNS 相容 Fargate
  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        computeType = "Fargate"
      })
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  fargate_profiles = {
    # 基礎設施層 (我們的 Postgres, Redis, Kafka 等)
    infra = {
      name = "infra-profile"
      selectors = [{ namespace = "infra" }]
    }
    # CI/CD 層
    argocd = {
      name = "argocd-profile"
      selectors = [{ namespace = "argocd" }]
    }
    # 監控層
    observability = {
      name = "observability-profile"
      selectors = [{ namespace = "observability" }]
    }
    # 預設系統層
    kube_system = {
      name = "kube-system-profile"
      selectors = [{ namespace = "kube-system" }]
    }
  }

  # 賦予目前執行者管理權限 (方便您在本機控制)
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = "production"
    Project     = "infar"
  }
}

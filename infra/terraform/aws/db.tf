# 建立 RDS 子網組
resource "aws_db_subnet_group" "postgres" {
  name       = "infar-db-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

# 建立 RDS 安全群組 (允許 VPC 內部連線)
resource "aws_security_group" "rds" {
  name   = "infar-rds-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

# 建立 RDS Instance (PostgreSQL)
resource "aws_db_instance" "postgres" {
  identifier           = "infar-db-instance"
  engine               = "postgres"
  engine_version       = "16"
  instance_class       = "db.t4g.micro" # 測試環境使用微型實例
  allocated_storage     = 20
  db_name              = var.db_name
  username             = var.db_user
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot  = true
  publicly_accessible  = false
}

# 建立 ElastiCache 子網組
resource "aws_elasticache_subnet_group" "redis" {
  name       = "infar-redis-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

# 建立 Redis 安全群組
resource "aws_security_group" "redis" {
  name   = "infar-redis-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

# 建立 ElastiCache Redis
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "infar-redis"
  engine               = "redis"
  node_type            = "cache.t4g.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]
}

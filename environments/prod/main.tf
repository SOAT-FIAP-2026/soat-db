# ==============================================================================
# Main — Ambiente PROD
# ==============================================================================
# Configurações de produção com parâmetros adequados para carga real:
#   - Instância maior (db.t3.medium)
#   - Mais armazenamento (50 GB gp3)
#   - Backups habilitados (7 dias)
#   - Proteção contra exclusão acidental
#   - Recursos de rede completos (Security Group + Subnet Group)
# ==============================================================================

# --- Remote State: dados de rede do cluster EKS -------------------------------
# Quando use_remote_state = true, os IDs de VPC, Subnets e Security Group são
# lidos diretamente do estado do tech-challenge-infra-k8s armazenado no S3.
data "terraform_remote_state" "k8s" {
  count   = var.use_remote_state ? 1 : 0
  backend = "s3"
  config = {
    bucket = "fiap-soat-techchallenge-backend"
    key    = "k8s/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  vpc_id                = var.use_remote_state ? data.terraform_remote_state.k8s[0].outputs.vpc_id : var.vpc_id
  vpc_cidr_block        = var.use_remote_state ? data.terraform_remote_state.k8s[0].outputs.vpc_cidr_block : var.vpc_cidr_block
  subnet_ids            = var.use_remote_state ? data.terraform_remote_state.k8s[0].outputs.subnet_ids : var.subnet_ids
  eks_security_group_id = var.use_remote_state ? data.terraform_remote_state.k8s[0].outputs.security_group_id : var.eks_security_group_id
}

module "rds" {
  source = "../../modules/rds"

  # Identificação
  project_name = var.project_name
  environment  = "prod"
  identifier   = "${var.project_name}-prod-db"

  # Compute & Storage — ajustado para limites da conta Free Tier (db.t3.micro / 20 GB)
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp3"
  engine_version    = "16.14"
  multi_az          = false # Habilitar para alta disponibilidade (custo adicional)

  # Credenciais — injetadas via variáveis (nunca hardcoded)
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  # Rede — obtida automaticamente do Remote State do EKS
  create_network_resources = true
  vpc_id                   = local.vpc_id
  vpc_cidr_block           = local.vpc_cidr_block
  subnet_ids               = local.subnet_ids
  eks_security_group_id    = local.eks_security_group_id

  # Backup & proteção — configurações de produção (1 dia para contas com restrição de Free Tier)
  backup_retention_period = 1     # Máximo permitido para contas AWS Free Tier
  skip_final_snapshot     = true  # Permitir destruir sem snapshot em ambiente de aprendizado
  deletion_protection     = false # Propositalmente falso pois é ambiente de de aprendizado

  # Monitoramento — alarmes CloudWatch (sem custo relevante) ligados em produção.
  # Enhanced Monitoring e Performance Insights ficam desligados por sairem do Free Tier.
  enable_cloudwatch_alarms        = true
  alarm_actions                   = var.alarm_sns_topic_arns
  monitoring_interval             = 0
  performance_insights_enabled    = false
  enabled_cloudwatch_logs_exports = ["postgresql"]
}

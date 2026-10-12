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
# lidos diretamente do estado do soat-infra armazenado no S3.
data "terraform_remote_state" "k8s" {
  count   = var.use_remote_state ? 1 : 0
  backend = "s3"
  config = {
    bucket = "soat-fiap-backend-tfstate"
    key    = "k8s/terraform.tfstate"
    region = var.aws_region
  }
}

# --- SSM: Leitura de credenciais do bootstrap ---------------------------------
# Permite que o apply funcione sem passar db_username/db_password via CLI
# quando os valores já existem no SSM Parameter Store.
data "aws_ssm_parameter" "db_username" {
  name = "/techchallenge/prod/db_username"
}

data "aws_ssm_parameter" "db_password" {
  name            = "/techchallenge/prod/db_password"
  with_decryption = true
}

locals {
  vpc_id                = var.use_remote_state ? data.terraform_remote_state.k8s[0].outputs.vpc_id : var.vpc_id
  vpc_cidr_block        = var.use_remote_state ? data.terraform_remote_state.k8s[0].outputs.vpc_cidr_block : var.vpc_cidr_block
  subnet_ids            = var.use_remote_state ? data.terraform_remote_state.k8s[0].outputs.subnet_ids : var.subnet_ids
  eks_security_group_id = var.use_remote_state ? data.terraform_remote_state.k8s[0].outputs.security_group_id : var.eks_security_group_id

  # Credenciais: usa a variável se fornecida via CLI, senão lê do SSM
  effective_db_username = coalesce(var.db_username, data.aws_ssm_parameter.db_username.value)
  effective_db_password = coalesce(var.db_password, data.aws_ssm_parameter.db_password.value)
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

  # Credenciais — lidas do SSM ou injetadas via variáveis (nunca hardcoded)
  db_name     = var.db_name
  db_username = local.effective_db_username
  db_password = local.effective_db_password

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

# --- SSM: Publicação do endpoint e connection string --------------------------
# Após a criação do RDS, grava os dados no SSM para que o soat-infra (Lambda)
# consuma automaticamente sem precisar copiar strings manualmente.
resource "aws_ssm_parameter" "db_endpoint" {
  name      = "/techchallenge/prod/db_endpoint"
  type      = "String"
  value     = module.rds.endpoint
  overwrite = true
}

resource "aws_ssm_parameter" "db_connection_string" {
  name      = "/techchallenge/prod/db_connection_string"
  type      = "SecureString"
  value     = "Host=${module.rds.host};Port=5432;Database=${var.db_name};Username=${local.effective_db_username};Password=${local.effective_db_password};"
  overwrite = true
}

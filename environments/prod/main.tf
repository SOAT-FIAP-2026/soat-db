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

module "rds" {
  source = "../../modules/rds"

  # Identificação
  project_name = var.project_name
  environment  = "prod"
  identifier   = "${var.project_name}-prod-db"

  # Compute & Storage — configurações de produção
  instance_class    = "db.t3.medium"
  allocated_storage = 50
  storage_type      = "gp3"
  engine_version    = "16.14"
  multi_az          = false # Habilitar para alta disponibilidade (custo adicional)

  # Credenciais — injetadas via variáveis (nunca hardcoded)
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  # Rede — recursos completos em produção
  create_network_resources = true
  vpc_id                   = var.vpc_id
  vpc_cidr_block           = var.vpc_cidr_block
  subnet_ids               = var.subnet_ids
  eks_security_group_id    = var.eks_security_group_id

  # Backup & proteção — configurações de produção
  backup_retention_period = 7     # 7 dias de backup automático
  skip_final_snapshot     = false # Exigir snapshot antes de destruir
  deletion_protection     = true  # Proteger contra exclusão acidental
}

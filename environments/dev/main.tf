# ==============================================================================
# Main — Ambiente DEV
# ==============================================================================
# Configurações de baixo custo para desenvolvimento e testes locais (Floci).
# Recursos de rede (SG, Subnet Group) não são criados — o emulador local
# não os utiliza.
# ==============================================================================

module "rds" {
  source = "../../modules/rds"

  # Identificação
  project_name = var.project_name
  environment  = "dev"
  identifier   = "${var.project_name}-dev-db"

  # Compute & Storage — configurações mínimas de baixo custo
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"
  engine_version    = "16.14"
  multi_az          = false

  # Credenciais — injetadas via variáveis
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  # Rede — desabilitada em dev (Floci não emula SG/Subnet Group)
  create_network_resources = false
  vpc_id                   = var.vpc_id
  vpc_cidr_block           = var.vpc_cidr_block
  subnet_ids               = var.subnet_ids
  eks_security_group_id    = var.eks_security_group_id

  # Backup & proteção — relaxados para dev
  backup_retention_period = 0     # Sem backup automático em dev
  skip_final_snapshot     = true  # Permitir destruir sem snapshot
  deletion_protection     = false # Sem proteção contra exclusão
}

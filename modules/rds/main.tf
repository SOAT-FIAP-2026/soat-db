# ==============================================================================
# RDS PostgreSQL - Módulo Reutilizável
# ==============================================================================
#
# Este módulo provisiona uma instância AWS RDS PostgreSQL com configurações
# parametrizáveis para atender diferentes ambientes (dev, staging, prod).
#
# Uso:
#   module "rds" {
#     source         = "../../modules/rds"
#     identifier     = "meuapp-dev-db"
#     instance_class = "db.t3.micro"
#     ...
#   }
#
# Segurança de credenciais:
#   As variáveis db_username e db_password são marcadas como 'sensitive'
#   e NUNCA devem ser comitadas no repositório. Injete-as via:
#     - TF_VAR_db_password="..." terraform apply
#     - Um arquivo terraform.tfvars (listado no .gitignore)
#     - Secrets do CI/CD (GitHub Actions Secrets, etc.)
# ==============================================================================

# --- Security Group: acesso apenas via nodes do EKS ---------------------------
resource "aws_security_group" "rds" {
  count       = var.create_network_resources ? 1 : 0
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Permite acesso PostgreSQL apenas a partir dos nodes EKS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes (SG declarado no Terraform)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_security_group_id]
  }

  ingress {
    description = "PostgreSQL from EKS managed node SG (criado automaticamente pelo EKS)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-sg"
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- Subnet Group: RDS exige pelo menos 2 AZs (mesmo em single-AZ) -----------
resource "aws_db_subnet_group" "main" {
  count       = var.create_network_resources ? 1 : 0
  name        = "${var.project_name}-${var.environment}-rds-subnet-group"
  description = "Subnet group para o RDS PostgreSQL — ${var.environment}"
  subnet_ids  = var.subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-subnet-group"
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- RDS Instance -------------------------------------------------------------
resource "aws_db_instance" "postgres" {
  identifier = var.identifier

  # Engine
  engine         = "postgres"
  engine_version = var.engine_version

  # Compute & Storage — parametrizado por ambiente
  instance_class      = var.instance_class
  allocated_storage   = var.allocated_storage
  storage_type        = var.storage_type
  multi_az            = var.multi_az
  publicly_accessible = var.publicly_accessible

  # Banco de dados inicial + credenciais
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Rede (condicional — não criada em ambientes locais como Floci)
  db_subnet_group_name   = var.create_network_resources ? aws_db_subnet_group.main[0].name : null
  vpc_security_group_ids = var.create_network_resources ? [aws_security_group.rds[0].id] : null

  # Backup e proteção — parametrizado por ambiente
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection

  # Performance Insights desativado (não é free tier)
  performance_insights_enabled = false

  # Evitar downtime em atualizações de maintenance
  auto_minor_version_upgrade = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-db"
    Project     = var.project_name
    Environment = var.environment
  }
}

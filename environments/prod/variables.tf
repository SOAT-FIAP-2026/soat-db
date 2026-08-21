# ==============================================================================
# Variáveis — Ambiente PROD
# ==============================================================================
# Em produção, NENHUMA variável sensível deve ter valor default.
# Todas devem ser injetadas via:
#   - terraform.tfvars (arquivo NÃO versionado — .gitignore)
#   - Variáveis de ambiente: export TF_VAR_db_password="..."
#   - GitHub Actions Secrets → env no workflow
#   - AWS Secrets Manager / SSM Parameter Store (recomendado)
# ==============================================================================

variable "aws_region" {
  description = "Região da AWS para o provisionamento"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "techchallenge"
}

# --- Credenciais (sem default — obrigatório injetar de forma segura) ----------

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "techchallengedb"
}

variable "db_username" {
  description = "Usuário master do RDS PostgreSQL"
  type        = string
  sensitive   = true
  # Sem default! Injete via TF_VAR_db_username ou terraform.tfvars
}

variable "db_password" {
  description = "Senha master do RDS PostgreSQL"
  type        = string
  sensitive   = true
  # Sem default! Injete via TF_VAR_db_password ou terraform.tfvars
}

# --- Rede (obrigatório — valores reais da infraestrutura AWS) -----------------

variable "vpc_id" {
  description = "ID da VPC (preencher via tfvars ou data source / Remote State)"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block da VPC"
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets privadas para o DB Subnet Group (mínimo 2 AZs)"
  type        = list(string)
}

variable "eks_security_group_id" {
  description = "ID do Security Group do cluster EKS"
  type        = string
}

# ==============================================================================
# Variáveis — Ambiente DEV
# ==============================================================================
# Em dev, usamos valores padrão seguros para testes locais com Floci.
# Credenciais não são reais — são aceitas pelo emulador local.
# ==============================================================================

variable "aws_region" {
  description = "Região da AWS (ignorada pelo Floci, mas necessária para o provider)"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "techchallenge"
}

# --- Credenciais (seguras via variáveis, não hardcoded em produção) -----------
# Em dev, valores default são aceitáveis pois o Floci não valida credenciais.

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "techchallengedb"
}

variable "db_username" {
  description = "Usuário master do banco"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Senha master do banco"
  type        = string
  sensitive   = true
  default     = "postgres"
}

# --- Rede (valores fictícios para Floci — não são validados) ------------------

variable "vpc_id" {
  description = "ID da VPC (fictício em dev)"
  type        = string
  default     = "vpc-local"
}

variable "vpc_cidr_block" {
  description = "CIDR block da VPC (fictício em dev)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_ids" {
  description = "IDs das subnets (fictícios em dev)"
  type        = list(string)
  default     = ["subnet-local1", "subnet-local2"]
}

variable "eks_security_group_id" {
  description = "ID do Security Group do EKS (fictício em dev)"
  type        = string
  default     = "sg-local"
}

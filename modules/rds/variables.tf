# ==============================================================================
# Variáveis do Módulo RDS PostgreSQL
#
# Este módulo é reutilizável para qualquer ambiente (dev, staging, prod).
# Credenciais (db_username, db_password) devem ser injetadas de forma segura:
#   - Via terraform.tfvars (arquivo NÃO versionado — está no .gitignore)
#   - Via variáveis de ambiente: TF_VAR_db_password, TF_VAR_db_username
#   - Via GitHub Actions Secrets ou outro sistema de CI/CD
#   - Via AWS Secrets Manager / SSM Parameter Store (recomendado para produção)
# ==============================================================================

# --- Configurações gerais do projeto -----------------------------------------

variable "project_name" {
  description = "Nome do projeto — usado como prefixo em todos os recursos"
  type        = string
}

variable "environment" {
  description = "Nome do ambiente (dev, staging, prod) — usado em tags e identificação"
  type        = string
  default     = "dev"
}

# --- Configurações da instância RDS ------------------------------------------

variable "identifier" {
  description = "Identificador único da instância RDS (deve ser único na conta/região)"
  type        = string
}

variable "instance_class" {
  description = "Classe da instância RDS (e.g., db.t3.micro para dev, db.t3.medium para prod)"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Tamanho do armazenamento em GB"
  type        = number
  default     = 20
}

variable "storage_type" {
  description = "Tipo de armazenamento (gp2, gp3, io1)"
  type        = string
  default     = "gp2"
}

variable "engine_version" {
  description = "Versão do PostgreSQL engine"
  type        = string
  default     = "16.14"
}

variable "multi_az" {
  description = "Habilitar Multi-AZ para alta disponibilidade (recomendado para prod)"
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Se a instância deve ser acessível publicamente (false para ambientes em VPC)"
  type        = bool
  default     = false
}

# --- Credenciais do banco de dados -------------------------------------------
# IMPORTANTE: Nunca versione credenciais no repositório!
# Injete via TF_VAR_*, terraform.tfvars (não versionado), ou secrets manager.

variable "db_name" {
  description = "Nome do banco de dados inicial"
  type        = string
  default     = "techchallengedb"
}

variable "db_username" {
  description = "Usuário master do RDS PostgreSQL"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Senha master do RDS PostgreSQL — NUNCA versione este valor"
  type        = string
  sensitive   = true
}

# --- Configurações de backup e proteção --------------------------------------

variable "backup_retention_period" {
  description = "Número de dias de retenção de backups automáticos (0 = desabilitar)"
  type        = number
  default     = 1
}

variable "skip_final_snapshot" {
  description = "Pular snapshot final ao destruir a instância (true apenas para dev/test)"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Habilitar proteção contra exclusão acidental (recomendado para prod)"
  type        = bool
  default     = false
}

# --- Configurações de rede ---------------------------------------------------

variable "create_network_resources" {
  description = "Define se os recursos de rede (SG, Subnet Group) devem ser criados. False para ambientes locais (Floci/LocalStack)"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "ID da VPC onde o RDS será provisionado"
  type        = string
  default     = ""
}

variable "vpc_cidr_block" {
  description = "CIDR block da VPC — usado na regra de ingress do SG do RDS"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_ids" {
  description = "IDs das subnets para o DB Subnet Group (mínimo 2 AZs)"
  type        = list(string)
  default     = []
}

variable "eks_security_group_id" {
  description = "ID do Security Group do EKS — permite acesso ao RDS na porta 5432"
  type        = string
  default     = ""
}

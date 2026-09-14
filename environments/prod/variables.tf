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
  default     = "sa-east-1" # deve acompanhar a VPC/EKS provisionada em soat-infra
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

# --- Rede ---------------------------------------------------------------------

variable "use_remote_state" {
  description = "Define se os dados de rede devem ser obtidos automaticamente do Remote State do EKS no S3"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "ID da VPC (opcional se use_remote_state = true)"
  type        = string
  default     = ""
}

variable "vpc_cidr_block" {
  description = "CIDR block da VPC (opcional se use_remote_state = true)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "IDs das subnets para o DB Subnet Group (opcional se use_remote_state = true)"
  type        = list(string)
  default     = []
}

variable "eks_security_group_id" {
  description = "ID do Security Group do cluster EKS (opcional se use_remote_state = true)"
  type        = string
  default     = ""
}

variable "alarm_sns_topic_arns" {
  description = "ARNs de tópicos SNS que recebem os alarmes do RDS. Vazio mantém os alarmes visíveis no console, sem notificação."
  type        = list(string)
  default     = []
}

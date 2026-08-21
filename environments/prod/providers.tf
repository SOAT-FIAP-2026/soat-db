# ==============================================================================
# Provider — Ambiente PROD
# ==============================================================================
#
# ⚠️  ISOLAMENTO DE ESTADO:
#   O estado de produção é armazenado REMOTAMENTE em um bucket S3, com
#   locking via DynamoDB. Isso garante:
#     1. Isolamento total do estado de dev (que é local).
#     2. Acesso compartilhado e seguro pela equipe e CI/CD.
#     3. Locking para evitar applies concorrentes.
#
#   - Dev:  estado LOCAL  → environments/dev/terraform.tfstate
#   - Prod: estado REMOTO → s3://<bucket>/prod/rds/terraform.tfstate
#
#   Cada ambiente tem seu próprio 'terraform init' e 'terraform apply',
#   executados DENTRO da sua respectiva pasta.
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # =========================================================================
  # Backend remoto para estado de produção (S3 + DynamoDB Locking)
  # =========================================================================
  # Pré-requisitos (criar manualmente ou via outro Terraform antes do init):
  #   1. Bucket S3 com versionamento habilitado
  #   2. Tabela DynamoDB com partition key "LockID" (tipo String)
  #
  # Descomente e ajuste os valores abaixo antes do primeiro 'terraform init':
  #
  # backend "s3" {
  #   bucket         = "techchallenge-terraform-state-prod"
  #   key            = "prod/rds/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "techchallenge-terraform-lock-prod"
  #
  #   # Recomendado: habilitar versionamento no bucket S3 para rollback de estado
  #   # aws s3api put-bucket-versioning \
  #   #   --bucket techchallenge-terraform-state-prod \
  #   #   --versioning-configuration Status=Enabled
  # }
  # =========================================================================
}

# Provider padrão da AWS — credenciais via ~/.aws/credentials, env vars,
# IAM Role, ou GitHub Actions OIDC.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "techchallenge"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

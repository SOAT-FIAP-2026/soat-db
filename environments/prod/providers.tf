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
  # Backend remoto — estado armazenado no bucket S3 criado pelo bootstrap
  # com locking via DynamoDB para evitar applies concorrentes.
  # =========================================================================
  backend "s3" {
    bucket         = "soat-fiap-backend-tfstate"
    key            = "db/terraform.tfstate"
    region         = "sa-east-1"
    dynamodb_table = "soat-fiap-terraform-locks"
    encrypt        = true
  }
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

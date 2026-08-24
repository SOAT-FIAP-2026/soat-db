# Agente Especialista — Infraestrutura de Banco de Dados (RDS)

Você é o **agente especialista em infraestrutura de banco de dados** para o projeto Tech Challenge (FIAP SOAT).
Este repositório gerencia a infraestrutura AWS RDS PostgreSQL usando Terraform.

---

## Contexto do Projeto

- **Fase:** Fase 3 do Tech Challenge
- **Ecossistema:** 3 repositórios independentes
  - `tech-challenge-infra-k8s` — VPC, IAM, EKS
  - `tech-challenge-infra-db` (ESTE REPO) — RDS PostgreSQL
  - `fase1-tech-challenge` — Aplicação .NET + Kubernetes manifests
- **IaC:** Terraform >= 1.5.0, AWS Provider ~> 5.0
- **CI/CD:** GitHub Actions

---

## Estrutura que você deve conhecer

```
tech-challenge-infra-db/
├── modules/
│   └── rds/                # Módulo reutilizável de RDS PostgreSQL
│       ├── main.tf          # SG (condicional), Subnet Group (condicional), RDS Instance
│       ├── variables.tf     # 18 variáveis: compute, rede, credenciais, backup
│       └── outputs.tf       # endpoint, host, port, db_name, identifier
├── environments/
│   ├── dev/                 # Floci/LocalStack (porta 4566, UI 4500)
│   │   ├── docker-compose.yml
│   │   ├── providers.tf     # fake creds → localhost:4566
│   │   ├── main.tf          # RDS mínimo, create_network_resources = false
│   │   ├── variables.tf     # defaults seguros (postgres/postgres)
│   │   └── outputs.tf
│   └── prod/                # AWS real
│       ├── providers.tf     # Backend S3 (comentado), default_tags
│       ├── main.tf          # RDS completo, create_network_resources = true
│       ├── variables.tf     # Sem defaults sensíveis
│       └── outputs.tf
└── .github/workflows/
    ├── pr.yml               # CI: fmt, validate, plan
    └── deploy.yml           # CD: apply
```

---

## Regras e Convenções

### Terraform

1. **Módulos são reutilizáveis** — o módulo `rds` aceita configurações para dev, staging e prod via variáveis.
2. **Ambientes são isolados** — `environments/dev/` e `environments/prod/` NUNCA compartilham estado.
   - Dev: estado **local** (`terraform.tfstate` na pasta dev)
   - Prod: estado **remoto** no S3 (quando backend habilitado)
3. **Comentários em português** — todo o código Terraform usa comentários em português (pt-BR).
4. **Estilo de código:**
   - Headers de seção: `# ==============================================================================`
   - Separadores inline: `# --- Descrição -------`
   - Todas as variáveis têm `description`
   - Tags sempre incluem `Name`, `Project` e `Environment`
5. **Recursos de rede condicionais** — controlados pela variável `create_network_resources`:
   - `true` em prod (cria SG + Subnet Group reais)
   - `false` em dev (Floci não emula SG/Subnet Group de forma confiável)

### Módulo RDS — Padrão de Design

O módulo `modules/rds/` usa o padrão **conditional resource creation** via `count`:
```hcl
resource "aws_security_group" "rds" {
  count = var.create_network_resources ? 1 : 0
  ...
}
```
E referencia condicionalmente:
```hcl
vpc_security_group_ids = var.create_network_resources ? [aws_security_group.rds[0].id] : null
```
**Sempre seguir este padrão** ao adicionar novos recursos que dependem de rede.

### Segurança de Credenciais

⚠️ **NUNCA hardcode credenciais em código Terraform.**

- Dev: valores default são aceitáveis (`postgres` / `postgres`) — Floci não valida.
- Prod: variáveis `db_username` e `db_password` são `sensitive` e **sem default**.
- Injetar via: `TF_VAR_*`, `terraform.tfvars` (gitignored), GitHub Secrets, ou AWS Secrets Manager.

### Ambiente Dev (Floci — instância compartilhada)

1. **Floci compartilhado:** instância ÚNICA na raiz do workspace (`FIAP - TC/docker-compose.yml`)
   - API: `localhost:4566`, UI: `localhost:4500`
   - Subir via: `cd "FIAP - TC/" && docker compose up -d`
2. **Credenciais fake:** `access_key = "test"`, `secret_key = "test"`
3. **Endpoints:** `rds`, `ec2`, `sts` apontam para `http://localhost:4566`
4. **Rede desabilitada:** `create_network_resources = false`, valores fictícios de VPC/subnet
5. **Backup desabilitado:** `backup_retention_period = 0`
6. **Sem proteção:** `skip_final_snapshot = true`, `deletion_protection = false`

### Ambiente Prod (AWS)

1. **Região:** `us-east-1`
2. **Backend S3:** comentado no `providers.tf` (descomentar e configurar antes do primeiro uso)
3. **RDS:** `db.t3.medium`, 50GB gp3, backup 7 dias, deletion_protection = true
4. **Rede completa:** SG + Subnet Group criados pelo módulo
5. **Dependência do infra-k8s:** precisa de `vpc_id`, `vpc_cidr_block`, `subnet_ids`, `eks_security_group_id`

### Dependências Inter-Repositório

Este repo **depende** do `tech-challenge-infra-k8s` em produção para:

| Variável (prod) | Fonte (infra-k8s output) |
|---|---|
| `vpc_id` | `output.vpc_id` |
| `vpc_cidr_block` | `output.vpc_cidr_block` |
| `subnet_ids` | `output.subnet_ids` |
| `eks_security_group_id` | `output.security_group_id` |

Pode-se injetar via `terraform.tfvars` ou via `terraform_remote_state` data source.

---

## Fluxo de Trabalho

### Desenvolvimento Local
```bash
# Subir Floci compartilhado (se não estiver rodando)
cd "FIAP - TC/"
docker compose up -d

# Rodar Terraform
cd tech-challenge-infra-db/environments/dev
terraform init
terraform plan              # Valida módulos
terraform apply             # Cria RDS emulado
terraform output            # Verifica endpoint
terraform destroy           # Limpa
```

### Deploy em Produção
```bash
cd environments/prod
# Primeiro, garantir que infra-k8s já foi aplicado (VPC/EKS existem)
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### CI/CD (GitHub Actions)
- **PR → main:** `fmt -check` → `validate` → `plan`
- **Merge → main:** `apply -auto-approve`

---

## Ao modificar o módulo RDS

1. Novas variáveis devem ter `description` e, se sensíveis, `sensitive = true`
2. Se depende de rede, use o padrão `count = var.create_network_resources ? 1 : 0`
3. Teste no ambiente dev antes de aplicar em prod
4. Exporte novos outputs em `modules/rds/outputs.tf` E nos `outputs.tf` de ambos os ambientes
5. Atualize o README.md com a nova estrutura

## Floci Compartilhado

O Floci roda como instância única na raiz do workspace (`FIAP - TC/docker-compose.yml`).
Ambos os repos (`infra-db` e `infra-k8s`) apontam para `localhost:4566`.

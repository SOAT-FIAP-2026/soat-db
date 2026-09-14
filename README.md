# Tech Challenge - Infraestrutura do Banco de Dados (Terraform)

Consulte o arquivo de [validação](docs/validation.md) para entender os resultados dos checks,
problemas identificados no CI/CD e pendências de deploy.

Repositório responsável pelo provisionamento da infraestrutura de banco de dados (RDS PostgreSQL) na AWS utilizando **Terraform**.
Faz parte da Fase 3 do Tech Challenge — repositório dedicado ao desacoplamento da infraestrutura de dados.

## Tecnologias

- [Terraform](https://www.terraform.io/)
- [AWS (Amazon Web Services)](https://aws.amazon.com/)
- [Amazon RDS](https://aws.amazon.com/rds/) (PostgreSQL 16.14)
- [Floci / LocalStack](https://github.com/floci/floci) (emulação local)
- [Docker Compose](https://docs.docker.com/compose/)
- [GitHub Actions](https://github.com/features/actions)
- [Amazon CloudWatch](https://aws.amazon.com/cloudwatch/) — alarmes do banco e exportação de logs do PostgreSQL
- RDS Enhanced Monitoring e Performance Insights: suportados pelo módulo, desligados por padrão (fora do Free Tier)

## Arquitetura

O Terraform neste repositório provisiona:

- **RDS PostgreSQL** (engine 16.14) com configurações parametrizáveis por ambiente.
- **Security Group** dedicado para o RDS, liberando tráfego apenas na porta `5432` a partir do EKS.
- **DB Subnet Group** associado às subnets da VPC (mínimo 2 AZs).

### Diagrama de Componentes

```
┌─────────────────────────────────────────────────────────┐
│                      AWS (sa-east-1)                     │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │                 VPC (do repo infra-k8s)            │  │
│  │                                                   │  │
│  │  ┌──────────────┐    ┌──────────────┐            │  │
│  │  │ Subnet AZ-1  │    │ Subnet AZ-2  │            │  │
│  │  └──────┬───────┘    └──────┬───────┘            │  │
│  │         │                   │                     │  │
│  │  ┌──────┴───────────────────┴──────────────────┐  │  │
│  │  │             DB Subnet Group                 │  │  │
│  │  │                                             │  │  │
│  │  │  ┌────────────────────────────────────────┐ │  │  │
│  │  │  │   RDS PostgreSQL 16.14                 │ │  │  │
│  │  │  │   db.t3.micro (dev) / db.t3.medium (p) │ │  │  │
│  │  │  │   porta: 5432                          │ │  │  │
│  │  │  └────────────────────────────────────────┘ │  │  │
│  │  │                                             │  │  │
│  │  │  ┌──────────────────────┐                   │  │  │
│  │  │  │  Security Group RDS  │                   │  │  │
│  │  │  │  ingress: EKS SG     │                   │  │  │
│  │  │  │  ingress: VPC CIDR   │                   │  │  │
│  │  │  └──────────────────────┘                   │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                                                   │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Estrutura do Repositório

```
tech-challenge-infra-db/
├── modules/
│   └── rds/               # Módulo reutilizável de RDS PostgreSQL
│       ├── main.tf         # RDS Instance, Security Group, Subnet Group
│       ├── monitoring.tf   # Alarmes CloudWatch e role de Enhanced Monitoring
│       ├── variables.tf    # Variáveis parametrizáveis (rede, backup, alarmes)
│       └── outputs.tf      # endpoint, host, port, db_name, identifier, alarmes
├── environments/
│   ├── dev/                # Desenvolvimento local (Floci compartilhado)
│   │   ├── docker-compose.yml   # Referência → usar o Floci da raiz do workspace
│   │   ├── providers.tf         # Endpoints apontam para localhost:4566
│   │   ├── main.tf              # RDS mínimo, sem rede (Floci não emula SG)
│   │   ├── variables.tf         # Defaults seguros para teste local
│   │   └── outputs.tf
│   └── prod/               # Produção na AWS
│       ├── providers.tf         # Backend S3 (comentado), provider AWS real
│       ├── main.tf              # RDS completo com rede, backup e proteção
│       ├── variables.tf         # Sem defaults sensíveis (injete via tfvars)
│       └── outputs.tf
└── .github/workflows/
    ├── pr.yml              # CI: fmt recursivo, init, validate e plan em environments/prod
    └── deploy.yml          # CD: apply em environments/prod a cada push na main
```

## Monitoramento do banco

O caminho local usa PostgreSQL em container e healthcheck de conexão na API
(`AddDbContextCheck` no `/health/ready`). O consumo de CPU e memória do Kubernetes é
responsabilidade do repositório soat-infra, que configura Prometheus e Grafana. O Compose
da aplicação não coleta métricas Kubernetes.

Para o RDS na AWS, o módulo provisiona alarmes CloudWatch em [`modules/rds/monitoring.tf`](modules/rds/monitoring.tf):

| Alarme | Métrica | Condição padrão |
|---|---|---|
| `<projeto>-<env>-rds-cpu-high` | `CPUUtilization` | acima de 80% por 10 minutos |
| `<projeto>-<env>-rds-freeable-memory-low` | `FreeableMemory` | abaixo de 100 MB por 10 minutos |
| `<projeto>-<env>-rds-free-storage-low` | `FreeStorageSpace` | abaixo de 2 GB |
| `<projeto>-<env>-rds-connections-high` | `DatabaseConnections` | acima de 60 conexões por 10 minutos |
| `<projeto>-<env>-rds-unavailable` | ausência de `CPUUtilization` | sem métricas por 10 minutos |

Variáveis de controle:

| Variável | Padrão | Efeito |
|---|---|---|
| `enable_cloudwatch_alarms` | `false` (dev) / `true` (prod) | cria os cinco alarmes acima |
| `alarm_actions` | `[]` | ARNs de tópicos SNS notificados no disparo e na normalização |
| `monitoring_interval` | `0` | Enhanced Monitoring em segundos; `0` desativa. Acima de `0` cria a IAM role e **sai do Free Tier** |
| `performance_insights_enabled` | `false` | Performance Insights; **fora do Free Tier** em `db.t3.micro` |
| `enabled_cloudwatch_logs_exports` | `[]` (dev) / `["postgresql"]` (prod) | exporta os logs do PostgreSQL para o CloudWatch Logs |
| `alarm_cpu_threshold`, `alarm_freeable_memory_bytes`, `alarm_free_storage_bytes`, `alarm_connections_threshold` | 80 / 100 MB / 2 GB / 60 | limiares dos alarmes |

Os alarmes ficam desligados por padrão para não quebrar o ambiente local emulado
(Floci/LocalStack) e para manter a conta dentro do Free Tier. Para receber notificação,
crie um tópico SNS e passe o ARN:

```bash
terraform apply -var='alarm_sns_topic_arns=["arn:aws:sns:sa-east-1:<conta>:techchallenge-alertas"]'
```

Sem tópico configurado, os alarmes continuam sendo avaliados e visíveis no console e em
`aws cloudwatch describe-alarms`, apenas sem envio de notificação. O nome dos alarmes
criados sai no output `cloudwatch_alarm_names`.

## API relacionada

Este repositório não expõe uma API. A documentação Swagger da aplicação está em https://github.com/SOAT-FIAP-2026/fase1-tech-challenge e, localmente, em http://localhost:8080/swagger.

## Ambientes

### Dev (Local com Floci)

O ambiente de desenvolvimento emula o RDS PostgreSQL localmente usando [Floci](https://github.com/floci/floci).
O estado do Terraform é armazenado **localmente** (`terraform.tfstate`).

> **Nota:** O Floci é uma instância **compartilhada** entre todos os repos de infra.
> Suba-o uma única vez na raiz do workspace (`FIAP - TC/`).

```bash
# 1. Subir o Floci compartilhado (se ainda não estiver rodando)
cd "FIAP - TC/"
docker compose up -d

# 2. Rodar Terraform
cd tech-challenge-infra-db/environments/dev
terraform init
terraform plan
terraform apply

# 3. Verificar outputs
terraform output

# Para destruir recursos emulados
terraform destroy
```

**Características do dev:**
- `instance_class = db.t3.micro`, `storage = 20GB gp2`
- Sem backup automático (`backup_retention_period = 0`)
- Sem proteção contra exclusão (`deletion_protection = false`)
- Recursos de rede **desabilitados** (`create_network_resources = false`)
- Credenciais default: `postgres` / `postgres`

### Prod (AWS)

O ambiente de produção provisiona um RDS PostgreSQL real na AWS.
O estado é armazenado **remotamente** em S3 (quando o backend for habilitado).

```bash
cd environments/prod

# Inicializar o Terraform
terraform init

# Verificar o plano de execução
terraform plan

# Aplicar a infraestrutura
terraform apply
```

**Características da prod:**
- `instance_class = db.t3.medium`, `storage = 50GB gp3`
- Backup automático de 7 dias
- Proteção contra exclusão habilitada
- Recursos de rede **completos** (Security Group + Subnet Group)
- Credenciais **sem default** — injetar via `TF_VAR_*` ou `terraform.tfvars`

## Isolamento de Estado

```
environments/
├── dev/
│   └── terraform.tfstate    ← Estado LOCAL (nunca comitado)
└── prod/
    └── (S3 remoto)          ← Configurar backend S3 no providers.tf
```

## Segurança de Credenciais

⚠️ **NUNCA versione credenciais no repositório!**

| Método | Quando Usar |
|---|---|
| `terraform.tfvars` (não versionado) | Desenvolvimento local |
| `TF_VAR_db_password="..."` | Linha de comando |
| GitHub Actions Secrets | CI/CD |
| AWS Secrets Manager / SSM | Produção (recomendado) |

## CI/CD e Deploy Automático

Os dois workflows rodam com `working-directory: environments/prod` — a raiz do
repositório não tem arquivos `.tf`, então executar o Terraform nela não fazia nada.

- **Pull Request para main** → `terraform fmt -check -recursive` na raiz, `init`,
  `validate` e `plan` em `environments/prod`
- **Push na main** tocando `environments/prod/**`, `modules/**` ou o próprio workflow
  → `terraform apply -auto-approve`, serializado por `concurrency: terraform-prod`

Secrets e variables necessários no repositório:

| Nome | Tipo | Conteúdo |
|---|---|---|
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | secret | credenciais de deploy |
| `DB_USERNAME`, `DB_PASSWORD` | secret | credenciais do banco — sem elas o apply falha com mensagem explícita |
| `VPC_ID`, `VPC_CIDR_BLOCK`, `EKS_SECURITY_GROUP_ID` | variable | outputs de soat-infra |
| `SUBNET_IDS` | variable | lista JSON, ex.: `["subnet-aaa","subnet-bbb"]` |
| `AWS_REGION` | variable | padrão `sa-east-1`, a mesma da VPC |
| `ALARM_SNS_TOPIC_ARNS` | variable | opcional, lista JSON de tópicos SNS dos alarmes |

A região padrão passou de `us-east-1` para `sa-east-1`: o RDS precisa ficar na mesma
região da VPC e do EKS provisionados em soat-infra.

## Outputs Disponíveis

| Output | Descrição |
|---|---|
| `endpoint` | Endpoint do RDS (host:port) |
| `host` | Hostname do RDS (sem porta) |
| `port` | Porta do PostgreSQL (5432) |
| `db_name` | Nome do banco de dados |
| `identifier` | Identificador da instância RDS |

## Dependência Inter-Repositório

Este repositório depende dos outputs do `tech-challenge-infra-k8s` em produção:

| Variável (prod) | Fonte (infra-k8s) |
|---|---|
| `vpc_id` | `output.vpc_id` |
| `vpc_cidr_block` | `output.vpc_cidr_block` |
| `subnet_ids` | `output.subnet_ids` |
| `eks_security_group_id` | `output.security_group_id` |

## Pré-Requisitos

### Dev (Local)
- Docker e Docker Compose instalados
- Terraform >= 1.5.0

### Prod (AWS)
- Conta ativa na AWS
- Chaves de acesso configuradas (`~/.aws/credentials` ou GitHub Secrets)
- Terraform >= 1.5.0
- VPC e EKS já provisionados (via `tech-challenge-infra-k8s`)

## Repositórios Relacionados

| Repositório | Descrição |
|---|---|
| [fase1-tech-challenge](https://github.com/SOAT-FIAP-2026/fase1-tech-challenge) | Aplicação principal (.NET) executando em Kubernetes |
| [tech-challenge-infra-k8s](https://github.com/SOAT-FIAP-2026/tech-challenge-infra-k8s) | Infraestrutura Kubernetes (VPC, IAM, EKS) |

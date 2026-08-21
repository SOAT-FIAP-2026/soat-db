# Tech Challenge - Infraestrutura do Banco de Dados Gerenciado

Repositório responsável pelo provisionamento da infraestrutura de banco de dados (RDS PostgreSQL) utilizando **Terraform**.
Faz parte da Fase 3 do Tech Challenge, especificamente para atender a necessidade de desacoplamento do repositório de dados.

## Tecnologias

- [Terraform](https://www.terraform.io/)
- [AWS (Amazon Web Services)](https://aws.amazon.com/)
- [PostgreSQL](https://www.postgresql.org/)
- [GitHub Actions](https://github.com/features/actions)

## Arquitetura

O Terraform neste repositório provisiona:
- 1 Instância AWS RDS PostgreSQL (`db.t3.micro`, 20GB `gp2`, Single-AZ).
- Security Group dedicado para o RDS, liberando tráfego apenas na porta `5432` para IPs e SGs provenientes da VPC/EKS.
- DB Subnet Group associado às subnets privadas da VPC.

## Pré-Requisitos

- Conta ativa na AWS
- Chaves de acesso AWS configuradas localmente (`~/.aws/credentials`) ou no GitHub Secrets (`AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY`)
- Terraform instalado (versão recomendada `~> 5.0` do provider AWS)

## Execução Local (Testes)

Para validar e executar localmente:

1. Clone o repositório
2. Crie um arquivo `terraform.tfvars` preenchendo as variáveis requeridas (ver `variables.tf`)
3. Execute a inicialização e os testes:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## CI/CD e Deploy Automático

A infraestrutura é automaticamente validada (Terraform Plan) quando há um **Pull Request** para as branches `main`/`master` ou `homolog`/`develop`. 
Após o *merge*, o pipeline de deploy (Terraform Apply) é disparado para atualizar os recursos na nuvem.

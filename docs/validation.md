# Validação — 07/09/2026

O módulo de banco existe, mas o pipeline atual não está validado para provisioná-lo.
Esta revisão registra pendências sem executar apply nem alterar GitHub/pipelines.

## Verificações

- terraform fmt -check -recursive passou.
- terraform validate não foi concluído em dev/prod: init com backend desabilitado e
  lockfile readonly instalou o provider, mas validate reportou checksums incompatíveis
  com os locks no Windows. Preparar locks multiplataforma e repetir antes do deploy.
- Workflows pr.yml e deploy.yml executam Terraform na raiz sem arquivos .tf;
  os root modules estão em environments/dev e environments/prod.
- Backend S3 de produção está comentado em environments/prod/providers.tf.
- Variáveis obrigatórias de credenciais e rede não são injetadas nos workflows atuais.
- GitHub: main sem proteção; soat-architecture com permissão write.
- Último [Terraform Deploy consultado](https://github.com/SOAT-FIAP-2026/soat-db/actions/runs/32792194330)
  falhou na etapa Configure AWS Credentials, antes da execução do Terraform.

## Pendências

1. Corrigir diretório de execução em ambos os workflows, com seleção explícita de
   ambiente e estado separado para homologação/produção. Não direcionar todas as branches
   ao mesmo estado de produção.
2. Proteger main e exigir PR antes do merge.
3. Preparar backend remoto, variáveis obrigatórias e credenciais de deploy.
4. Alinhar região do banco e rede do Kubernetes: defaults atuais us-east-1 e sa-east-1.
5. Preparar dependências e repetir validate; realizar plan com entradas do ambiente.
6. Implementar alarmes/Enhanced Monitoring se utilizados: não existem no módulo atual.
7. Corrigir instrução do Floci compartilhado: não há Compose na raiz deste workspace.
8. Atualizar links antigos tech-challenge-infra-k8s para o repositório real soat-infra.

PostgreSQL local é um container e não substitui o banco gerenciado exigido para cloud.
O healthcheck de conexão é implementado na aplicação; CPU/memória Kubernetes pertencem
ao stack local Grafana/Prometheus de soat-infra. Este repo não expõe API própria:
o Swagger da aplicação está em http://localhost:8080/swagger quando ela estiver em execução.

O relatório integrado está em docs/validation-report.md no repositório fase1-tech-challenge.

# ==============================================================================
# Outputs — Ambiente PROD
# ==============================================================================

output "endpoint" {
  description = "Endpoint do RDS PostgreSQL de Prod (host:port)"
  value       = module.rds.endpoint
}

output "host" {
  description = "Hostname do RDS PostgreSQL de Prod"
  value       = module.rds.host
}

output "port" {
  description = "Porta do RDS PostgreSQL de Prod"
  value       = module.rds.port
}

output "db_name" {
  description = "Nome do banco de dados de Prod"
  value       = module.rds.db_name
}

output "identifier" {
  description = "Identificador da instância RDS de Prod"
  value       = module.rds.identifier
}

output "cloudwatch_alarm_names" {
  description = "Alarmes CloudWatch criados para o RDS de produção"
  value       = module.rds.cloudwatch_alarm_names
}

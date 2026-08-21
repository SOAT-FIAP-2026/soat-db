# ==============================================================================
# Outputs — Ambiente DEV
# ==============================================================================

output "endpoint" {
  description = "Endpoint do RDS PostgreSQL de Dev (host:port)"
  value       = module.rds.endpoint
}

output "host" {
  description = "Hostname do RDS PostgreSQL de Dev"
  value       = module.rds.host
}

output "port" {
  description = "Porta do RDS PostgreSQL de Dev"
  value       = module.rds.port
}

output "db_name" {
  description = "Nome do banco de dados de Dev"
  value       = module.rds.db_name
}

output "identifier" {
  description = "Identificador da instância RDS de Dev"
  value       = module.rds.identifier
}

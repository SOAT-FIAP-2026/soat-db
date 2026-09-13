# ==============================================================================
# Outputs do Módulo RDS PostgreSQL
# ==============================================================================

output "endpoint" {
  description = "Endpoint do RDS PostgreSQL (host:port)"
  value       = aws_db_instance.postgres.endpoint
}

output "host" {
  description = "Hostname do RDS PostgreSQL (sem porta)"
  value       = aws_db_instance.postgres.address
}

output "port" {
  description = "Porta do RDS PostgreSQL"
  value       = aws_db_instance.postgres.port
}

output "db_name" {
  description = "Nome do banco de dados criado"
  value       = aws_db_instance.postgres.db_name
}

output "identifier" {
  description = "Identificador da instância RDS"
  value       = aws_db_instance.postgres.identifier
}

output "cloudwatch_alarm_names" {
  description = "Nomes dos alarmes CloudWatch criados para o banco (vazio quando enable_cloudwatch_alarms = false)"
  value = var.enable_cloudwatch_alarms ? [
    aws_cloudwatch_metric_alarm.cpu_high[0].alarm_name,
    aws_cloudwatch_metric_alarm.memory_low[0].alarm_name,
    aws_cloudwatch_metric_alarm.storage_low[0].alarm_name,
    aws_cloudwatch_metric_alarm.connections_high[0].alarm_name,
    aws_cloudwatch_metric_alarm.instance_unavailable[0].alarm_name,
  ] : []
}

output "enhanced_monitoring_role_arn" {
  description = "ARN da role de Enhanced Monitoring (vazio quando monitoring_interval = 0)"
  value       = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : ""
}

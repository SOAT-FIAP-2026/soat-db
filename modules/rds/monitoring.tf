# ==============================================================================
# Monitoramento do RDS PostgreSQL
# ==============================================================================
#
# Cobre o requisito de monitoramento do banco com três camadas:
#   1. Enhanced Monitoring  — métricas do SO em alta resolução (opcional, tem custo)
#   2. Logs no CloudWatch   — exportação dos logs do PostgreSQL (opcional)
#   3. Alarmes CloudWatch   — CPU, memória, conexões, armazenamento e disponibilidade
#
# Todos os recursos são condicionais e ficam DESLIGADOS por padrão, para não gerar
# custo em conta Free Tier nem quebrar o ambiente local emulado (Floci/LocalStack).
# Em produção, ative com enable_cloudwatch_alarms = true.
#
# Os alarmes notificam os tópicos SNS informados em alarm_actions. Sem tópico o
# alarme continua sendo avaliado e fica visível no console/CLI, apenas sem envio.
# ==============================================================================

locals {
  create_alarms = var.enable_cloudwatch_alarms
  alarm_prefix  = "${var.project_name}-${var.environment}-rds"
}

# --- IAM Role para Enhanced Monitoring ----------------------------------------
data "aws_iam_policy_document" "rds_monitoring_assume" {
  count = var.monitoring_interval > 0 ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  count              = var.monitoring_interval > 0 ? 1 : 0
  name               = "${local.alarm_prefix}-monitoring-role"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume[0].json

  tags = {
    Name        = "${local.alarm_prefix}-monitoring-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# --- Alarme: CPU alta ---------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = local.create_alarms ? 1 : 0

  alarm_name          = "${local.alarm_prefix}-cpu-high"
  alarm_description   = "CPU do RDS acima de ${var.alarm_cpu_threshold}% por 10 minutos."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.alarm_cpu_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.identifier
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- Alarme: memória livre baixa ----------------------------------------------
resource "aws_cloudwatch_metric_alarm" "memory_low" {
  count = local.create_alarms ? 1 : 0

  alarm_name          = "${local.alarm_prefix}-freeable-memory-low"
  alarm_description   = "Memória livre do RDS abaixo de ${var.alarm_freeable_memory_bytes} bytes."
  namespace           = "AWS/RDS"
  metric_name         = "FreeableMemory"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.alarm_freeable_memory_bytes
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.identifier
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- Alarme: armazenamento livre baixo ----------------------------------------
resource "aws_cloudwatch_metric_alarm" "storage_low" {
  count = local.create_alarms ? 1 : 0

  alarm_name          = "${local.alarm_prefix}-free-storage-low"
  alarm_description   = "Armazenamento livre do RDS abaixo de ${var.alarm_free_storage_bytes} bytes."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.alarm_free_storage_bytes
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.identifier
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- Alarme: excesso de conexões ----------------------------------------------
resource "aws_cloudwatch_metric_alarm" "connections_high" {
  count = local.create_alarms ? 1 : 0

  alarm_name          = "${local.alarm_prefix}-connections-high"
  alarm_description   = "Conexões simultâneas acima de ${var.alarm_connections_threshold}."
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.alarm_connections_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.identifier
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- Alarme: instância sem métricas (indisponível) ----------------------------
# A ausência de CPUUtilization por 10 minutos indica instância parada, reiniciando
# ou em failover. treat_missing_data = "breaching" é intencional neste alarme.
resource "aws_cloudwatch_metric_alarm" "instance_unavailable" {
  count = local.create_alarms ? 1 : 0

  alarm_name          = "${local.alarm_prefix}-unavailable"
  alarm_description   = "RDS sem métricas por 10 minutos — possível indisponibilidade."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "SampleCount"
  period              = 300
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.identifier
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Hedronite lab 21 reference: a two-period, missing-data-breaching alarm wired to a
# create-before-destroy topic; the legacy alarm is forgotten, not destroyed.

resource "aws_sns_topic" "alerts" {
  name = "hx-lab21-canary-alerts"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "canary_errors" {
  alarm_name          = "hx-lab21-canary-errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 60
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  evaluation_periods  = 2
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

removed {
  from = aws_cloudwatch_metric_alarm.legacy_latency

  lifecycle {
    destroy = false
  }
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

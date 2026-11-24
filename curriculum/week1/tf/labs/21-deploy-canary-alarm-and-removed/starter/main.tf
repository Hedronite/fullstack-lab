# Hedronite lab 21 starter: a canary error alarm and its notification topic. Valid HCL, wrong
# behaviour on purpose. See ../README.md for the tasks.

# TODO(task 2): replacing this topic (for example after a rename of its name) destroys it before
#               the new one exists, and the alarm briefly has nowhere to notify. Make the
#               replacement build the new topic first.
resource "aws_sns_topic" "alerts" {
  name = "hx-lab21-canary-alerts"
}

resource "aws_cloudwatch_metric_alarm" "canary_errors" {
  alarm_name          = "hx-lab21-canary-errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 60
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0

  # TODO(task 1a): one bad minute should not roll back a release. Require at least 2 periods.
  evaluation_periods = 1

  # TODO(task 1b): a canary that stops reporting is not healthy. Treat missing data as breaching.
  treat_missing_data = "notBreaching"

  # TODO(task 1c): the alarm notifies nobody. Send the ALARM state to the topic above.
  alarm_actions = []
}

# TODO(task 3): this old alarm is being handed to another team's configuration. Stop managing
#               it WITHOUT deleting it from AWS: replace this resource with a removed block
#               whose lifecycle sets destroy = false.
resource "aws_cloudwatch_metric_alarm" "legacy_latency" {
  alarm_name          = "hx-lab21-legacy-latency"
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 5000
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

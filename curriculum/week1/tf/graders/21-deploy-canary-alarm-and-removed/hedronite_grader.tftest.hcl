# Hedronite lab 21 (deploy canary alarm and removed block) grader.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.7 for mock_provider; the lab pins 1.10.5 (the lab image).
#
# The run applies the configuration against the mock provider and checks the alarm's evaluation
# periods (task 1a), missing-data handling (task 1b) and notification target (task 1c).
# create_before_destroy (task 2) and the removed block (task 3) are not observable in a mock
# apply, so check.sh checks them statically on the .tf text.

mock_provider "aws" {}

# The mock provider generates a random string for computed attributes, which the alarm's ARN
# validation rejects, so the topic gets a fixed, valid ARN.
override_resource {
  target = aws_sns_topic.alerts
  values = {
    arn = "arn:aws:sns:us-east-1:123456789012:hx-lab21-canary-alerts"
  }
}

run "canary_alarm_is_patient_strict_and_wired" {
  command = apply

  assert {
    condition     = aws_cloudwatch_metric_alarm.canary_errors.evaluation_periods >= 2
    error_message = "Task 1a: evaluation_periods must be at least 2, so one bad minute does not trip the alarm."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.canary_errors.treat_missing_data == "breaching"
    error_message = "Task 1b: treat_missing_data must be \"breaching\", so a silent canary counts as unhealthy."
  }

  assert {
    condition     = contains(aws_cloudwatch_metric_alarm.canary_errors.alarm_actions, aws_sns_topic.alerts.arn)
    error_message = "Task 1c: alarm_actions must contain the alerts topic ARN."
  }
}

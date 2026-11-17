# Hedronite lab 19 (queue retry and dead letters) grader.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.7 for mock_provider; the lab pins 1.10.5 (the lab image).
#
# The run applies the configuration against the mock provider and checks the retention period
# (task 1a) and the redrive limit (task 1b). The import block (task 2) and the version bounds
# (task 3) are not observable in a mock apply, so check.sh checks them statically on the .tf text.

mock_provider "aws" {}

# A mock provider cannot import, so the adopted dead-letter queue is overridden with fixed values.
override_resource {
  target = aws_sqs_queue.dlq
  values = {
    arn = "arn:aws:sqs:us-east-1:123456789012:hx-lab19-events-dlq"
  }
}

run "queue_keeps_messages_and_gives_up_on_poison" {
  command = apply

  assert {
    condition     = aws_sqs_queue.events.message_retention_seconds >= 345600
    error_message = "Task 1a: message_retention_seconds must be at least 345600 (4 days), or messages expire during a long outage."
  }

  assert {
    condition     = jsondecode(aws_sqs_queue.events.redrive_policy).maxReceiveCount <= 5
    error_message = "Task 1b: maxReceiveCount must be 5 or less, so a poison message reaches the dead-letter queue quickly."
  }
}

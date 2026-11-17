# Hedronite lab 19 starter: a work queue and its dead-letter queue. Valid HCL, wrong
# behaviour on purpose. See ../README.md for the tasks.

# TODO(task 2): this dead-letter queue already exists in the real account (it was created by
#               hand, id = its queue URL below). Adopt it with an import block instead of
#               letting the next apply fail on "queue already exists".
resource "aws_sqs_queue" "dlq" {
  name = "hx-lab19-events-dlq"
}

resource "aws_sqs_queue" "events" {
  name = "hx-lab19-events"

  # TODO(task 1a): a message that waits one minute is gone before a weekend outage ends.
  #                Keep messages at least 4 days (345600 seconds).
  message_retention_seconds = 60

  # TODO(task 1b): fifty receives before a poison message reaches the dead-letter queue
  #                keeps it blocking the worker. Allow at most 5.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 50
  })
}

output "events_queue_url" {
  value = aws_sqs_queue.events.url
}

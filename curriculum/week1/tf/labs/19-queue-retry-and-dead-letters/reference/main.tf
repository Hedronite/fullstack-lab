# Hedronite lab 19 reference: 4-day retention, redrive after 5 receives, DLQ adopted by import.

import {
  to = aws_sqs_queue.dlq
  id = "https://sqs.us-east-1.amazonaws.com/123456789012/hx-lab19-events-dlq"
}

resource "aws_sqs_queue" "dlq" {
  name = "hx-lab19-events-dlq"
}

resource "aws_sqs_queue" "events" {
  name = "hx-lab19-events"

  message_retention_seconds = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })
}

output "events_queue_url" {
  value = aws_sqs_queue.events.url
}

# Hedronite lab 12 (sensitive values and credentials) grader.
# Staged as tests/hedronite_grader.tftest.hcl by curriculum/week1/tf/stage.sh.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.8 for issensitive() and >= 1.7 for mock_provider; the lab pins 1.10.5.
#
# What it sees: the plan graph after a mock apply. It can ask whether a value carries the
# sensitive mark (issensitive), so tasks 1, 2 and 3 are graded here. The provider block is
# replaced by the mock provider, so task 4 (no credentials in configuration) and the "no default
# on the password" half of task 1 are checked statically by check.sh.

mock_provider "aws" {
  mock_resource "aws_db_instance" {
    defaults = {
      address = "hx-lab12-edge.mock.internal"
    }
  }
}

variables {
  db_password = "hx-test-password-1"
}

run "secret_stays_secret" {
  command = apply

  assert {
    condition     = issensitive(var.db_password)
    error_message = "Task 1: var.db_password is not marked sensitive, so plan and apply would print it."
  }

  assert {
    condition     = issensitive(output.db_connection_string)
    error_message = "Task 2: output.db_connection_string contains the password but is not marked sensitive."
  }

  assert {
    condition     = alltrue([for v in values(aws_db_instance.edge.tags) : nonsensitive(v) != nonsensitive(var.db_password)])
    error_message = "Task 3: a tag on aws_db_instance.edge carries the password in plain text."
  }
}

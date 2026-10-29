terraform {
  required_version = ">= 1.9.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

variable "greeting" {
  type    = string
  default = "Hello from the lab"
}

resource "local_file" "hello" {
  filename = "${path.module}/hello.txt"
  content  = "${var.greeting}\n"
}

output "hello_path" {
  value = local_file.hello.filename
}

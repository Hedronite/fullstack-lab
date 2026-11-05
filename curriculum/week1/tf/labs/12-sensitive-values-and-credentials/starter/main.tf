# Hedronite lab 12 starter: the edge service's database as the on-call engineer found it.
# Valid HCL, wrong behaviour on purpose. See ../README.md for the tasks.

resource "aws_db_instance" "edge" {
  identifier          = "hx-lab12-edge"
  engine              = "postgres"
  instance_class      = "db.t4g.micro"
  allocated_storage   = 20
  username            = "edge_admin"
  password            = var.db_password
  skip_final_snapshot = true

  tags = {
    Service = "edge"

    # TODO(task 3): a tag is plain text in the console, in the billing export and in every
    #               plan. Do not copy the password into one.
    BootstrapPassword = var.db_password
  }
}

# TODO(task 2): this value contains the password. Once the variable is sensitive, Terraform
#               refuses to plan an output that uses it unless the output says so too.
output "db_connection_string" {
  value = "postgres://edge_admin:${var.db_password}@${aws_db_instance.edge.address}:5432/edge"
}

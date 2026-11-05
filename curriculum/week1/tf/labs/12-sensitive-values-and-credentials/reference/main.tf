# Hedronite lab 12 reference: the worked answer. Do not open it until you are done.

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
  }
}

output "db_connection_string" {
  value     = "postgres://edge_admin:${var.db_password}@${aws_db_instance.edge.address}:5432/edge"
  sensitive = true
}

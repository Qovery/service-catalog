resource "aws_db_instance" "this" {
  identifier = replace(lower(var.db_name), "_", "-")

  engine         = "postgres"
  engine_version = "17"
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  multi_az            = var.multi_az
  publicly_accessible = false
  skip_final_snapshot = true

  backup_retention_period = 7

  tags = {
    Name        = var.db_name
    ManagedBy   = "qovery-blueprint"
    Blueprint   = "aws-rds-postgresql"
  }
}

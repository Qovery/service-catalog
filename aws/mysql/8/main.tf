resource "aws_db_instance" "this" {
  identifier = "${var.qovery_cluster_name}-${var.db_name}"

  engine         = "mysql"
  engine_version = "8.4"
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
    Name        = "${var.qovery_cluster_name}-${var.db_name}"
    ManagedBy   = "qovery-blueprint"
    Blueprint   = "aws-rds-mysql"
  }
}

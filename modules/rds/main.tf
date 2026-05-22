resource "aws_db_subnet_group" "main" {
  name       = "voting-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "voting-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  name        = "voting-rds-sg"
  description = "Allow Postgres inbound traffic from VPC"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "voting-rds-sg"
  }
}

resource "aws_db_instance" "main" {
  identifier             = "voting-app-db"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  username               = "postgres"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Name = "voting-app-db"
  }
}

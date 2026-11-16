resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Public HTTPS ingress to the application ALB."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP redirect"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidrs
  }

  egress {
    description = "Application traffic and health checks to private VPC targets."
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${var.name}-alb" }
}

resource "aws_security_group" "tasks" {
  name        = "${var.name}-tasks"
  description = "Only the ALB may reach the application tasks."
  vpc_id      = var.vpc_id

  ingress {
    description     = "Application traffic from the ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "HTTPS egress for Fargate image pulls, logs, and Secrets Manager."
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-tasks" }
}


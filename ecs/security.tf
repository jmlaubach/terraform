# ALB Security Group

resource "aws_security_group" "lb-sg" {
  name        = "apptest-load-balancer-security-group"
  description = "controls access to the ALB"
  vpc_id      = aws_vpc.main-vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = var.app_port
    to_port     = var.app_port
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = var.app_manage_port
    to_port     = var.app_manage_port
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Traffic to the ECS cluster should only come from the ALB
resource "aws_security_group" "ecs-task-sg" {
  name        = "apptest-ecs-task-sg"
  description = "allow inbound access from the ALB only"
  vpc_id      = aws_vpc.main-vpc.id

  ingress {
    protocol        = "tcp"
    from_port       = var.app_port
    to_port         = var.app_port
    security_groups = [aws_security_group.lb-sg.id]
  }

  ingress {
    protocol    = "tcp"
    from_port   = var.app_manage_port
    to_port     = var.app_manage_port
    security_groups = [aws_security_group.lb-sg.id]
  }


  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
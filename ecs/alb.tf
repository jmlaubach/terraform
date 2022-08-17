resource "aws_alb" "main-alb" {
  name            = "myapp-load-balancer"
  subnets         = aws_subnet.public-sub.*.id
  security_groups = [aws_security_group.lb-sg.id]
}

resource "aws_alb_target_group" "app-tg" {
  name        = "myapp-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main-vpc.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.health_check_path
    unhealthy_threshold = "2"
  }
}

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.main-alb.id
  port              = var.app_port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.app-tg.id
    type             = "forward"
  }
}
provider "aws" {
    region= "us-east-1"
    profile = "default"
    shared_credentials_file = "/Users/jlaubach/.aws/credentials"
}

# # Variables

variable "webserver-ami" {
    type = string
}

# # Create launch configuration

resource "aws_launch_configuration" "webserver-test" {
    name_prefix = "webserver-lc-test-"
    image_id = var.webserver-ami
    instance_type = "t2.micro"
    security_groups = [aws_security_group.webserver-instance-sg.id]
    user_data = <<-EOF
                  #!/bin/bash
                  sudo apt update -y
                  sudo apt install apache2 -y
                  sudo systemctl start apache2
                  sudo bash -c 'This is a test webserver. > /var/www/html/index.html'
                  EOF
    lifecycle {
        create_before_destroy = true
    }
}

# # Create vpc

resource "aws_vpc" "prod-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
      Name = "production"
    }
}

# # Create Internet Gateway

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.prod-vpc.id
}

# # Create Custom Route Tables

resource "aws_route_table" "prod-route-table" {
    vpc_id = aws_vpc.prod-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    route {
        ipv6_cidr_block = "::/0"
        gateway_id      = aws_internet_gateway.gw.id
    }

    tags = {
        Name = "Prod"
    }
}

resource "aws_route_table" "web-route-table" {
    vpc_id = aws_vpc.prod-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    route {
        ipv6_cidr_block = "::/0"
        gateway_id      = aws_internet_gateway.gw.id
    }

    tags = {
        Name = "Prod"
    }
}

# # Create Subnets

resource "aws_subnet" "webserver-subnet" {
    vpc_id            = aws_vpc.prod-vpc.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = "us-east-1a"

    tags = {
        Name = "webserver-subnet-1"
    }
}

# # Associate subnet with Route Table
resource "aws_route_table_association" "sub_one" {
    subnet_id      = aws_subnet.webserver-subnet.id
    route_table_id = aws_route_table.prod-route-table.id
}

# # Create an Autoscaling Group

resource "aws_autoscaling_group" "webserver-asg" {
    name = "webserver-asg"
    min_size = 1
    max_size = 3
    desired_capacity = 1
    launch_configuration = aws_launch_configuration.webserver-test.id
    vpc_zone_identifier = [aws_subnet.webserver-subnet-1.id, aws_subnet.webserver-subnet-2.id]
    tag {
        key = "Name"
        value = "Webserver Test ASG"
        propagate_at_launch = true
  }
}

# # Create a Load Balancer, Listener, and Target Group

resource "aws_lb" "webserver-lb" {
    name = "webserver-lb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.webserver-lb-sg.id]
    subnets = [aws_subnet.webserver-subnet-1.id, aws_subnet.webserver-subnet-2.id]
}

resource "aws_lb_listener" "webserver-lb-listener" {
    load_balancer_arn = aws_lb.webserver-lb.id
    port = "80"
    protocol = "HTTP"

    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.webserver-tg.id
    }
}

resource "aws_lb_target_group" "webserver-tg" {
    name = "webserver-tg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.prod-vpc.id
}

resource "aws_autoscaling_attachment" "webserver-ag-to-tg" {
    autoscaling_group_name = aws_autoscaling_group.webserver-asg.id
    alb_target_group_arn = aws_lb_target_group.webserver-tg.id
}

# # Create a network interface with an ip in the subnet

/* resource "aws_network_interface" "web-server-nic" {
    subnet_id       = aws_subnet.subnet-1.id
    private_ips     = ["10.0.1.50"]
    security_groups = [aws_security_group.allow_web.id]
} */

# # Assign an elastic IP to the network interface

/* resource "aws_eip" "one" {
    vpc                       = true
    network_interface         = aws_network_interface.web-server-nic.id
    associate_with_private_ip = "10.0.1.50"
    depends_on                = [aws_internet_gateway.gw]
} */

# # Create Security Groups

resource "aws_security_group" "webserver-instance-sg" {
  name = "webserver-instance-sg"
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.webserver-lb-sg.id]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.webserver-lb-sg.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.webserver-lb-sg.id]
  }

  vpc_id = aws_vpc.prod-vpc.id
}

resource "aws_security_group" "webserver-lb-sg" {
  name = "webserver-lb-sg"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.prod-vpc.id
}
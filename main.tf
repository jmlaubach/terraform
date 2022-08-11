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

resource "aws_vpc" "webserver-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
      Name = "webserver-vpc"
    }
}

# # Create Internet Gateway

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.webserver-vpc.id
}

# # Create Custom Route Tables

resource "aws_route_table" "web-route-table-1" {
    vpc_id = aws_vpc.webserver-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    route {
        ipv6_cidr_block = "::/0"
        gateway_id      = aws_internet_gateway.gw.id
    }

    tags = {
        Name = "web-route-table-1"
    }
}

resource "aws_route_table" "web-route-table-2" {
    vpc_id = aws_vpc.webserver-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    route {
        ipv6_cidr_block = "::/0"
        gateway_id      = aws_internet_gateway.gw.id
    }

    tags = {
        Name = "web-route-table-2"
    }
}

# # Create Subnets

resource "aws_subnet" "webserver-subnet-1" {
    vpc_id            = aws_vpc.webserver-vpc.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = "us-east-1a"

    tags = {
        Name = "webserver-subnet-1"
    }
}

resource "aws_subnet" "webserver-subnet-2" {
    vpc_id            = aws_vpc.webserver-vpc.id
    cidr_block        = "10.0.2.0/24"
    availability_zone = "us-east-1b"

    tags = {
        Name = "webserver-subnet-2"
    }
}

# # Associate subnets with Route Tables

resource "aws_route_table_association" "web-sub-1" {
    subnet_id      = aws_subnet.webserver-subnet-1.id
    route_table_id = aws_route_table.web-route-table-1.id
}

resource "aws_route_table_association" "web-sub-2" {
    subnet_id      = aws_subnet.webserver-subnet-2.id
    route_table_id = aws_route_table.web-route-table-2.id
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
    vpc_id = aws_vpc.webserver-vpc.id
}

resource "aws_autoscaling_attachment" "webserver-ag-to-tg" {
    autoscaling_group_name = aws_autoscaling_group.webserver-asg.id
    alb_target_group_arn = aws_lb_target_group.webserver-tg.id
}

# # Create Security Groups

resource "aws_security_group" "ssh-traffic-sg" {
    name = "ssh-traffic-sg"
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.webserver-vpc.id

  tags = {
        Name = "ssh-traffic-sg"
    }
}

resource "aws_security_group" "webserver-instance-sg" {
  name = "webserver-instance-sg"
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["10.0.1.22/32"]
    security_groups = [aws_security_group.ssh-traffic-sg.id]
  }
  
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

  vpc_id = aws_vpc.webserver-vpc.id

  tags = {
        Name = "webserver-instance-sg"
    }
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

  vpc_id = aws_vpc.webserver-vpc.id

  tags = {
        Name = "webserver-lb-sg"
    }
}

# # Create network interface and EIP for ssh host

resource "aws_network_interface" "ssh-host-nic" {
    subnet_id = aws_subnet.webserver-subnet-1.id
    private_ips = ["10.0.1.22"]
    security_groups = [aws_security_group.ssh-traffic-sg.id]
}

resource "aws_eip" "ssh-host-eip" {
    vpc = true
    network_interface = aws_network_interface.ssh-host-nic.id
    associate_with_private_ip = "10.0.1.22"
    depends_on = [aws_internet_gateway.gw]
}

# # Create ssh host instance

resource "aws_instance" "ssh-host" {
    ami = "ami-052efd3df9dad4825"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "ssh-host"

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.ssh-host-nic.id
    }

    tags = {
    Name = "ssh-host"
    }
}
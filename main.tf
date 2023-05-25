provider "aws" {
  region = "ap-south-1"
  access_key = "AKIATROT5PYJ4BYGGEI5"
  secret_key = "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"
}


#VPC
resource "aws_vpc" "arch-vpc" {
  cidr_block = "13.13.0.0/16"
  tags = {
    Name = "arch-vpc"
  }
}

# SUBNETS

resource "aws_subnet" "arch-pub-sub-1" {
  vpc_id     = aws_vpc.arch-vpc.id
  cidr_block = "13.13.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "arch-pub-sub-1"
  }
}
resource "aws_subnet" "arch-pub-sub-2" {
  vpc_id     = aws_vpc.arch-vpc.id
  cidr_block = "13.13.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "arch-pub-sub-2"
  }
}
resource "aws_subnet" "arch-pri-sub-1" {
  vpc_id     = aws_vpc.arch-vpc.id
  cidr_block = "13.13.3.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "arch-pri-sub-1"
  }
}
resource "aws_subnet" "arch-pri-sub-2" {
  vpc_id     = aws_vpc.arch-vpc.id
  cidr_block = "13.13.4.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "arch-pri-sub-2"
  }
}

# SECURITY GROUP

resource "aws_security_group" "arch-sg" {
  name        = "arch-sg"
  description = "Allow ALL inbound traffic"
  vpc_id      = aws_vpc.arch-vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "arch-sg"
  }
}

# Internet Gateway

resource "aws_internet_gateway" "arch-igw" {
  vpc_id = aws_vpc.arch-vpc.id

  tags = {
    Name = "arch-igw"
  }
}

# Create elastic AP address
resource "aws_eip" "nat_ip-1" {
  depends_on = [aws_internet_gateway.arch-igw]
  tags = {
    "Name" = "nat_ip-1"
  }
}

# Create elastic AP address
resource "aws_eip" "nat_ip-2" {
  depends_on = [aws_internet_gateway.arch-igw]
  tags = {
    "Name" = "nat_ip-2"
  }
}

# Create nat gateways
resource "aws_nat_gateway" "nat-gw-1" {
  allocation_id = aws_eip.nat_ip-1.id
  subnet_id     = aws_subnet.arch-pub-sub-1.id
  depends_on    = [aws_internet_gateway.arch-igw]
  tags = {
    "Name" = "nat-gw-1"
  }
}

resource "aws_nat_gateway" "nat-gw-2" {
  allocation_id = aws_eip.nat_ip-2.id
  subnet_id     = aws_subnet.arch-pub-sub-2.id
  depends_on    = [aws_internet_gateway.arch-igw]
  tags = {
    "Name" = "nat-gw-2"
  }
}

# Create route tables and route table associations
resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.arch-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.arch-igw.id
  }

  tags = {
    Name = "public_route"
  }
}

resource "aws_route_table_association" "public_route_association-1" {
  subnet_id      = aws_subnet.arch-pub-sub-1.id
  route_table_id = aws_route_table.public_route.id
}
resource "aws_route_table_association" "public_route_association-2" {
  subnet_id      = aws_subnet.arch-pub-sub-2.id
  route_table_id = aws_route_table.public_route.id
}

resource "aws_route_table" "private_route-1" {
  vpc_id = aws_vpc.arch-vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw-1.id
  }
  tags = {
    Name = "private_route_1"
  }
}

resource "aws_route_table_association" "private-route-1" {
  subnet_id      = aws_subnet.arch-pri-sub-1.id
  route_table_id = aws_route_table.private_route-1.id
}

resource "aws_route_table" "private_route-2" {
  vpc_id = aws_vpc.arch-vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw-2.id
  }
  tags = {
    Name = "private_route_2"
  }
}

resource "aws_route_table_association" "private-route-2" {
  subnet_id      = aws_subnet.arch-pri-sub-2.id
  route_table_id = aws_route_table.private_route-2.id
}



# Create a load balancer, listener, and target group for presentation tier
resource "aws_lb" "front_end" {
  name               = "front-end-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.arch-sg.id]
  subnets            = [aws_subnet.arch-pub-sub-1.id, aws_subnet.arch-pub-sub-2.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "front_end" {
  name     = "front-end-lb-tg"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = aws_vpc.arch-vpc.id
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.front_end.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_end.arn
  }
}



# Create a load balancer, listener, and target group for application tier

resource "aws_lb" "application_tier" {
  name               = "application-tier-lb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.arch-sg.id]
  subnets            = [aws_subnet.arch-pub-sub-1.id, aws_subnet.arch-pub-sub-2.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "application_tier" {
  name     = "application-tier-lb-tg"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = aws_vpc.arch-vpc.id
}

resource "aws_lb_listener" "application_tier" {
  load_balancer_arn = aws_lb.application_tier.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application_tier.arn
  }
}





# Create a launch template for presentation tier
data "template_file" "userdata" {
  template = <<-EOF
              #!/bin/bash
              sudo yum install nginx -y
              sudo systemctl enable nginx
              sudo systemctl start nginx
              EOF
}

resource "aws_launch_template" "presentation_tier" {
  name = "presentation_tier"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 8
    }
  }
  
  user_data = "${base64encode(data.template_file.userdata.rendered)}"
  instance_type = "t2.micro"
  image_id      = "ami-0b08bfc6ff7069aff"
  key_name = "dellhoak-ec2key"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.arch-sg.id]
  }


  depends_on = [
    aws_lb.application_tier
  ]
}

# Create a launch template for application tier
resource "aws_launch_template" "application_tier" {
  name = "application_tier"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 8
    }
  }


  instance_type = "t2.micro"
  image_id      = "ami-0b08bfc6ff7069aff"
  key_name = "dellhoak-ec2key"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.arch-sg.id]
  }

    user_data = "${base64encode(data.template_file.userdata.rendered)}"

  depends_on = [
    aws_nat_gateway.nat-gw-1 , aws_nat_gateway.nat-gw-2

  ]
}


# Create autoscaling group for presentation tier
resource "aws_autoscaling_group" "presentation_tier" {
  name                      = "ASG-Presentation-Tier"
  max_size                  = 4
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.arch-pub-sub-1.id, aws_subnet.arch-pub-sub-2.id]

  launch_template {
    id      = aws_launch_template.presentation_tier.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.front_end.arn]

#   lifecycle {
#     ignore_changes = [load_balancers, target_group_arns]
#   }

  tag {
    key                 = "Name"
    value               = "presentation_app"
    propagate_at_launch = true
  }
}

# Create autoscaling group for application tier
resource "aws_autoscaling_group" "application_tier" {
  name                      = "ASG-Application-Tier"
  max_size                  = 4
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.arch-pri-sub-1.id, aws_subnet.arch-pri-sub-2.id]

  launch_template {
    id      = aws_launch_template.application_tier.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.application_tier.arn]


#   lifecycle {
#     ignore_changes = [load_balancers, target_group_arns]
#   }

  tag {
    key                 = "Name"
    value               = "application_app"
    propagate_at_launch = true
  }
}

# Create a new ALB Target Group attachment
# resource "aws_autoscaling_attachment" "presentation_tier" {
#   autoscaling_group_name = aws_autoscaling_group.presentation_tier.id
#   lb_target_group_arn    = aws_lb_target_group.front_end.arn
# }

# resource "aws_autoscaling_attachment" "application_tier" {
#   autoscaling_group_name = aws_autoscaling_group.application_tier.id
#   lb_target_group_arn    = aws_lb_target_group.application_tier.arn
# }
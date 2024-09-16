# Create VPC
resource "aws_vpc" "VPC-test" {
  cidr_block = var.cidr
}


# Create two subnets public subnet
resource "aws_subnet" "subnet_01" {
  vpc_id                  = aws_vpc.VPC-test.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_02" {
  vpc_id                  = aws_vpc.VPC-test.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}


# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.VPC-test.id
}


# Create route table 
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.VPC-test.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Subnet association
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.subnet_01.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.subnet_02.id
  route_table_id = aws_route_table.RT.id
}

# Create security group for EC2
resource "aws_security_group" "SG-for-ec2" {
  name_prefix = "web-sg"
  vpc_id      = aws_vpc.VPC-test.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-for-ec2"
  }
}

# Create s3 bucket
resource "aws_s3_bucket" "example" {
  bucket = "ishaqahmadbuckettest"
}

# resource "aws_s3_bucket_public_access_block" "example1" {
#   bucket = aws_s3_bucket.example.id

#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

# resource "aws_s3_bucket_acl" "example2" {
#   bucket = aws_s3_bucket.example.id
#   acl    = "public-read"
# }

#  Create EC2 Instance
resource "aws_instance" "test-ec2" {
  ami                    = "ami-0e86e20dae9224db8"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.SG-for-ec2.id]
  subnet_id              = aws_subnet.subnet_01.id
  user_data              = file("userdata.sh")
}

# Create LoadBalancer
resource "aws_lb" "myalb" {
  name               = "myalb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.SG-for-ec2.id]
  subnets         = [aws_subnet.subnet_01.id, aws_subnet.subnet_02.id]

  tags = {
    Name = "web"
  }
}

# Create Target group 
resource "aws_lb_target_group" "tg" {
  name     = "TG-for-lb"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = aws_vpc.VPC-test.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

# Attach target group to alb
resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.test-ec2.id
  port             = 80
}

# Add listner
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }
}

# Output from loadbalancer
output "loadbalancer" {
  value = aws_lb.myalb.dns_name

}
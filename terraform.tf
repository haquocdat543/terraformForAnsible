provider "aws" {
  region     = "ap-northeast-1"
}

# Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Production"
  }
}
# Create Internet Gateway
resource "aws_internet_gateway" "prod_gw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    "Name" = "VpcIGW"
  }
}
# Create Custom Route Table
resource "aws_route_table" "ProdRouteTable" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_gw.id
  }
  tags = {
    Name = "Prod_RouteTable"
  }
}
# Create a Subnet
resource "aws_subnet" "ProdSubnet" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "ProdSubnet"
  }
}
# Create Associate Subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.ProdSubnet.id
  route_table_id = aws_route_table.ProdRouteTable.id
}
# Create Security Group to allow port 22, 80, 443
resource "aws_security_group" "ProdSecurityGroup" {
  name        = "ProdSecurityGroup"
  description = "Allow SSH HTTP HTTPS"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_apache2_web"
  }
}
# Create a network interface with an ip in the subnet that was created step 4
resource "aws_network_interface" "AnsibleServer" {
  subnet_id       = aws_subnet.ProdSubnet.id
  private_ips     = ["10.0.0.50"]
  security_groups = [aws_security_group.ProdSecurityGroup.id]
}
resource "aws_network_interface" "ENI1" {
  subnet_id       = aws_subnet.ProdSubnet.id
  private_ips     = ["10.0.0.51"]
  security_groups = [aws_security_group.ProdSecurityGroup.id]
}
resource "aws_network_interface" "ENI2" {
  subnet_id       = aws_subnet.ProdSubnet.id
  private_ips     = ["10.0.0.52"]
  security_groups = [aws_security_group.ProdSecurityGroup.id]
}
# Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "ProdEIP" {
  vpc                       = true
  network_interface         = aws_network_interface.AnsibleServer.id
  associate_with_private_ip = "10.0.0.50"
  depends_on                = [aws_internet_gateway.prod_gw]

}
resource "aws_eip" "EIP1" {
  vpc                       = true
  network_interface         = aws_network_interface.ENI1.id
  associate_with_private_ip = "10.0.0.51"
  depends_on                = [aws_internet_gateway.prod_gw]

}
resource "aws_eip" "EIP2" {
  vpc                       = true
  network_interface         = aws_network_interface.ENI2.id
  associate_with_private_ip = "10.0.0.52"
  depends_on                = [aws_internet_gateway.prod_gw]

}
# Create Ubuntu server and install/ enable apache2
resource "aws_instance" "ProdInstance" {
  ami               = "ami-06ee4e2261a4dc5c3"
  instance_type     = "t2.micro"
  availability_zone = "ap-northeast-1a"
  key_name          = "dat"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.AnsibleServer.id
  }
  user_data = <<-EOF
                #!/bin/bash
                yum update -y
                sudo amazon-linux-extras install epel
                sudo amazon-linux-extras install ansible2
                # Use this for your user data (script from top to bottom)
                # install httpd (Linux 2 version)
                yum update -y
                yum install -y httpd
                systemctl start httpd
                systemctl enable httpd
                echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
                EOF
  tags = {
    "Name" = "ProdInstance"
  }
}
resource "aws_instance" "Instance1" {
  ami               = "ami-06ee4e2261a4dc5c3"
  instance_type     = "t2.micro"
  availability_zone = "ap-northeast-1a"
  key_name          = "dat"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.ENI1.id
  }
  user_data = <<-EOF
                #!/bin/bash
                # Use this for your user data (script from top to bottom)
                # install httpd (Linux 2 version)
                yum update -y
                yum install -y httpd
                systemctl start httpd
                systemctl enable httpd
                echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
                EOF
  tags = {
    "Name" = "1"
  }
}
resource "aws_instance" "Instance2" {
  ami               = "ami-06ee4e2261a4dc5c3"
  instance_type     = "t2.micro"
  availability_zone = "ap-northeast-1a"
  key_name          = "dat"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.ENI2.id
  }
  user_data = <<-EOF
                #!/bin/bash
                # Use this for your user data (script from top to bottom)
                # install httpd (Linux 2 version)
                yum update -y
                yum install -y httpd
                systemctl start httpd
                systemctl enable httpd
                echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
                EOF
  tags = {
    "Name" = "2"
  }
}

#Output
output "AnsibleServer" {
  value = aws_eip.ProdEIP.public_ip
}
output "Instance1" {
  value = aws_eip.EIP1.public_ip
}
output "Instance2" {
  value = aws_eip.EIP2.public_ip
}
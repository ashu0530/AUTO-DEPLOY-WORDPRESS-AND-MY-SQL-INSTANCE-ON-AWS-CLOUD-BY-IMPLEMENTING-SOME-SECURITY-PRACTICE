#Declare provider to tell terraform which cloud we need to contact

provider "aws" {
  profile = "ashu"     
  region  =   "ap-south-1"    
}

#Creating Variable For Our Resources
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default = "10.0.0.0/16"
}
variable "subnet_cidr_public" {
  description = "CIDR block for the subnet"
  default = "10.0.0.0/24"
}
variable "availability_zone_public" {
  description = "availability zone for wordpress"
  default = "ap-south-1a"
}

variable "subnet_cidr_private" {
  description = "CIDR block for the subnet"
  default = "10.0.1.0/24"
}
variable "availability_zone_private" {
  description = "availability zone for mysql"
  default = "ap-south-1b"  
}
variable "wordpress_ami_id" {
  description = "wordpress ami id"
  default = "ami-000cbce3e1b899ebd"
}

variable "mysql_ami_id" {
  description = "mysql ami id"
  default = "ami-0019ac6129392a0f2"
}

variable "instance_type" {
  description = "Type for AWS EC2 instance"
  default = "t2.micro"
}

#Create VPC
resource "aws_vpc" "project4_vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default" 
  tags= {
     Name = "project4-vpc"
   }
}

#Create a public Subnet for wordpress
resource "aws_subnet" "project4_public_subnet" {
  
  availability_zone = "${var.availability_zone_public}"
  vpc_id            = "${aws_vpc.project4_vpc.id}"
  cidr_block        = "${var.subnet_cidr_public}"
  tags= {
     Name = "wp_public_subnet"
}
  depends_on = [
    aws_vpc.project4_vpc,
  ] 
}

#Create a private Subnet for mysql
resource "aws_subnet" "project4_private_subnet" {
  
  availability_zone = "${var.availability_zone_private}"
  vpc_id            = "${aws_vpc.project4_vpc.id}"
  cidr_block        = "${var.subnet_cidr_private}"
  tags= {
     Name = "mysql_private_subnet"
}
  depends_on = [
    aws_vpc.project4_vpc,
  ] 
}

#Create Internet Gateway
resource "aws_internet_gateway" "project4_internet_gateway" {
  vpc_id = "${aws_vpc.project4_vpc.id}"
  tags = {
    Name = "project4-ig"
  }
  depends_on = [
    aws_vpc.project4_vpc, aws_subnet.project4_public_subnet
  ]
}

#Create Route Table
resource "aws_route_table" "project4_route_table" {
  vpc_id = "${aws_vpc.project4_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.project4_internet_gateway.id}"
  }
  tags = {
    Name = "project4-route-table"
  }
  depends_on = [
    aws_vpc.project4_vpc, aws_internet_gateway.project4_internet_gateway,
  ]
}

#Create Route Table Association
resource "aws_route_table_association" "project4_rta" {
  subnet_id      = "${aws_subnet.project4_public_subnet.id}"
  route_table_id = "${aws_route_table.project4_route_table.id}"
  depends_on = [
    aws_subnet.project4_public_subnet, aws_route_table.project4_route_table,

  ]
}

#For elastic IP aka Static ip for nat gateway
resource "aws_eip" "project4_eip" {
  vpc = true
}

#Create Nat Gateway
resource "aws_nat_gateway" "project4_ngw" {
  allocation_id = "${aws_eip.project4_eip.id}"
  subnet_id     = "${aws_subnet.project4_public_subnet.id}"
  tags = { 
      Name = "project4_nat_gw"
  }
  depends_on = [
    aws_eip.project4_eip,
  ]
}


#Create Route Table for NAT gateway
resource "aws_route_table" "project4_nat_rt" {
  vpc_id = "${aws_vpc.project4_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.project4_ngw.id}"
  }
  tags = {
    Name = "project4-nat-route-table"
  }
  depends_on = [
    aws_vpc.project4_vpc, aws_nat_gateway.project4_ngw,
  ]
}


#Create Route Table Association 
resource "aws_route_table_association" "project4_nat_rta" {
  subnet_id      = "${aws_subnet.project4_private_subnet.id}"
  route_table_id = "${aws_route_table.project4_nat_rt.id}"
  depends_on = [
    aws_subnet.project4_private_subnet, aws_route_table.project4_nat_rt,

  ]
}



#Create Security Group for wordpress
resource "aws_security_group" "project4_first_sg" {
  name        = "sg1_wp_project4"
  description = "allow ssh and http, https traffic, ICMP for wordpress"
  vpc_id      =  "${aws_vpc.project4_vpc.id}"

  ingress {
    description = "inbound_ssh_configuration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http_configuration"  
    from_port         = 80
    to_port           = 80
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]  
}

  ingress {
    description = "https_configuration"  
    from_port         = 443
    to_port           = 443
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }   

  egress {
    description = "all_traffic_outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "project4_wp_sg"
  }
}

output "firewall_sg1_info" {
  value = aws_security_group.project4_first_sg.name
}


#Create Security Group for mysql
resource "aws_security_group" "project4_second_sg" {
  name        = "sg2_for_project4"
  description = "allow ssh and mysql 3306 default port for "
  vpc_id      =  "${aws_vpc.project4_vpc.id}"

  ingress {
    description = "mysql_port"
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    description = "all_traffic_outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "project4_mysql_sg"
  }
}

output "firewall_sg2_info" {
  value = aws_security_group.project4_second_sg.name
}



# Create a key-pair for aws instance for login

#Generate a key using RSA algo
resource "tls_private_key" "instance_key4" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#create a key-pair 
resource "aws_key_pair" "key_pair4" {
  key_name   = "project4_key1"
  public_key = "${tls_private_key.instance_key4.public_key_openssh}"
  depends_on = [  tls_private_key.instance_key4 ]
}

#save the key file locally inside workspace in .pem extension file
resource "local_file" "save_project4_key1" {
  content = "${tls_private_key.instance_key4.private_key_pem}"
  filename = "project4_key1.pem"
  depends_on = [
   tls_private_key.instance_key4, aws_key_pair.key_pair4 ]
}




#Instance creation of wordpress
resource "aws_instance" "project4_instance_wp" {
	ami				= "${var.wordpress_ami_id}"
	instance_type			= "${var.instance_type}"
	associate_public_ip_address	= true
	subnet_id			= "${aws_subnet.project4_public_subnet.id}"
	vpc_security_group_ids		= ["${aws_security_group.project4_first_sg.id}"]
	key_name			= aws_key_pair.key_pair4.key_name
	tags = {
		Name = "wordpress_inst"
	}
}

#Instance creation of mysql
resource "aws_instance" "project4_instance_mysql" {
	ami				= "${var.mysql_ami_id}"
	instance_type			= "${var.instance_type}"
	vpc_security_group_ids		= ["${aws_security_group.project4_second_sg.id}"]
	subnet_id			= "${aws_subnet.project4_private_subnet.id}"
	key_name			= aws_key_pair.key_pair4.key_name
	tags = {
		Name = "mysql_inst"
	}
}

#Output of wordpress public dns
output "wordpress_dns" {
  	value = aws_instance.project4_instance_wp.public_dns
}

#launching chrome browser for opening my website
 resource "null_resource" "ChromeOpen"  { 
     provisioner "local-exec" { 
           command = "start chrome ${aws_instance.project4_instance_wp.public_dns}"  
     }
     depends_on = [ aws_instance.project4_instance_mysql, aws_instance.project4_instance_wp
     ]         
}
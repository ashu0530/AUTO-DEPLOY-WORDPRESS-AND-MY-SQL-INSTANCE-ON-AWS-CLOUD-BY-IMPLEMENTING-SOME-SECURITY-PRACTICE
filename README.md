# cloud4
## Problem Statement:
1.  Write an Infrastructure as code using terraform, which automatically create a VPC.
2.  In that VPC we have to create 2 subnets:
    1.   public  subnet [ Accessible for Public World! ] 
    2.   private subnet [ Restricted for Public World! ]
3. Create a public facing internet gateway for connect our VPC/Network to the internet world and attach this gateway to our VPC.
4. Create  a routing table for Internet gateway so that instance can connect to outside world, update and associate it with public subnet.
5.  Create a NAT gateway for connect our VPC/Network to the internet world and attach this gateway to our VPC in the public network
6.  Update the routing table of the private subnet, so that to access the internet it uses the nat gateway created in the public subnet
7.  Launch an ec2 instance which has Wordpress setup already having the security group allowing  port 80 so that our client can connect to our wordpress site. Also attach the key to instance for further login into it.
8.  Launch an ec2 instance which has MYSQL setup already with security group allowing  port 3306 in private subnet so that our wordpress vm can connect with the same. Also attach the key with the same.

## Prerequisites:
- So we have to create an account on AWS and create IAM user in AWS management console
- Download terraform and install it as per your OS, also add in your environment path as per your OS
- Download and install AWS CLI v2, also add in your environment path as per your OS
- Configure your AWS IAM profile on aws cli

## AWS VPC
Amazon Virtual Private Cloud (Amazon VPC) lets you provision a logically isolated section of the AWS Cloud where you can launch AWS resources in a virtual network for secure and 
easy access to resources and applications. Amazon Web Services provides us private, virtualized network environment where we can launch our AWS resources within a virtual network 
means here we can control all the parts which is needed to configure a network like we can configure our own VPC's IP address space from ranges you select, subnets, route tables, 
security groups and subnet level and network gateways etc. Keep in mind that VPC is not a data-center network it is a software-defined network (SDN). It also helpful to organize 
our EC2 instances and configure their network connectivity and network access control list to enable inbound and outbound filtering at the instance.

## Subnet
Subnet is “part of the network”, in other words, part of entire availability zone. Subnet is the segment/subset of VPC CIDR block inside given availability zone, Each subnet has its own CIDR block where we can accommodate group of our resources. Each subnet is equal to one Availability Zone.

- Public Subnet :-If a subnet’s traffic is routed to an internet gateway, the subnet is known as a public subnet.
- Private Subnet :-If a subnet doesn’t have a route to the internet gateway, the subnet is known as a private subnet.

## Internet Gateway
Internet Gateway is the router that will take our network packets from our EC2 instance inside the network/subnets and forward them to the public internet, If a subnet’s traffic is routed to an internet gateway using route table, the subnet is known as a public subnet. so all the resources, instances inside a public subnet can access the internet using internet gateway.

## Route Table 
A route table contains a set of rules, called routes, Route table routing information base or a data table stored in a router or a network host that lists the routes to particular network destinations. It has entries that tell the router to route the traffic to desired destination. Route tables to control where network traffic is directed. Each subnet in your VPC must be associated with a route table, which controls the routing for the subnet (subnet route table).

## Nat Gateway
NAT Gateway, also known as Network Address Translation Gateway, is used to enable instances present in a private subnet to help connect to the internet or AWS services. In addition to this, the gateway makes sure that the internet doesn’t initiate a connection with the instances. NAT Gateway service is a fully managed service by Amazon, that doesn’t require any efforts from the administrator.
Here we have to give a range of IP Address that is known as “CIDR” . 

# Implementation:

## Declare provider to tell terraform which cloud we need to contact
``` html
provider "aws" {
  profile = "ashu"     
  region  =   "ap-south-1"    
}
```
## Creating Variable For Our Resources
``` html
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
```

## Step 1 : Infrastructure as code using terraform, which automatically create a VPC.
``` html
resource "aws_vpc" "project4_vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default" 
  tags= {
     Name = "project4-vpc"
   }
}
```

## Step 2 : Create a public Subnet for wordpress
``` html
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
```

## Step 3 : Create a private Subnet for mysql
``` html
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
```

## Step 4 : Create Internet Gateway
``` html
resource "aws_internet_gateway" "project4_internet_gateway" {
  vpc_id = "${aws_vpc.project4_vpc.id}"
  tags = {
    Name = "project4-ig"
  }
  depends_on = [
    aws_vpc.project4_vpc, aws_subnet.project4_public_subnet
  ]
}
```

## Step 5 : Create Route Table
``` html
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
```

## Step 6 : Create Route Table Association
``` html
resource "aws_route_table_association" "project4_rta" {
  subnet_id      = "${aws_subnet.project4_public_subnet.id}"
  route_table_id = "${aws_route_table.project4_route_table.id}"
  depends_on = [
    aws_subnet.project4_public_subnet, aws_route_table.project4_route_table,

  ]
}
```

## Step 7 : For elastic IP aka Static ip for nat gateway
``` html
resource "aws_eip" "project4_eip" {
  vpc = true
}
```

## Step 8 : Create Nat Gateway
``` html
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
```

## Step 9 : Create Route Table for NAT gateway
``` html
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
```

## Step 10 : Create Route Table Association 
``` html
resource "aws_route_table_association" "project4_nat_rta" {
  subnet_id      = "${aws_subnet.project4_private_subnet.id}"
  route_table_id = "${aws_route_table.project4_nat_rt.id}"
  depends_on = [
    aws_subnet.project4_private_subnet, aws_route_table.project4_nat_rt,

  ]
}
```


## Step 11 : Create Security Group for wordpress
``` html
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
```

## Step 12 : Create Security Group for mysql
``` html
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
```


## Step 13 : Create a key-pair for aws instance for login
``` html
###Generate a key using RSA algo
resource "tls_private_key" "instance_key4" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

###create a key-pair 
resource "aws_key_pair" "key_pair4" {
  key_name   = "project4_key1"
  public_key = "${tls_private_key.instance_key4.public_key_openssh}"
  depends_on = [  tls_private_key.instance_key4 ]
}

###save the key file locally inside workspace in .pem extension file
resource "local_file" "save_project4_key1" {
  content = "${tls_private_key.instance_key4.private_key_pem}"
  filename = "project4_key1.pem"
  depends_on = [
   tls_private_key.instance_key4, aws_key_pair.key_pair4 ]
}
```



## Step : 14 : Instance creation of wordpress
``` html
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
```

## Step : 15 Instance creation of mysql
``` html 
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
```

## Step : 16 launching chrome browser for opening my website
``` html
resource "null_resource" "ChromeOpen"  { 
     provisioner "local-exec" { 
           command = "start chrome ${aws_instance.project4_instance_wp.public_dns}"  
     }
     depends_on = [ aws_instance.project4_instance_mysql, aws_instance.project4_instance_wp
     ]         
}
```

# Run the following Terraform Code via Terraform command.

``` html
terraform init
```

## Now, we need is just to apply this code "terraform apply "

```html
terraform apply -auto-approve
```

# - And at the end delete or destroy the complete process.

``` html
terraform destroy -auto-approve
```

## Thank You!!!

Author: [Ashutosh Pandey :))](https://www.linkedin.com/pulse/cloud-computing-part-3-ashutosh-pandey/)

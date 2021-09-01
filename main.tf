#creating the vpc 
resource"aws_vpc" "anji" {
  cidr_block           = var.cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = "true"


  tags = {
    Name = var.envname
  }
}

# subnets

resource "aws_subnet" "pubsubnet" {
 count = length(var.azs)
  vpc_id     = aws_vpc.anji.id
  cidr_block = element(var.pubsubnets,count.index)
  availability_zone = element(var.azs,count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.envname}-pubsunet-${count.index+1}"
  }
}


resource "aws_subnet" "privatesubnet" {
 count = length(var.azs)
  vpc_id     = aws_vpc.anji.id
  cidr_block = element(var.privatesubnets,count.index)
  availability_zone = element(var.azs,count.index)
  

  tags = {
    Name = "${var.envname}-privatesunet-${count.index+1}"
  }
}

resource "aws_subnet" "datasubnet" {
 count = length(var.azs)
  vpc_id     = aws_vpc.anji.id
  cidr_block = element(var.datasubnets,count.index)
  availability_zone = element(var.azs,count.index)
  

  tags = {
    Name = "${var.envname}-datasubnets t-${count.index+1}"
  }
}


#igw and vpc 
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.anji.id

  tags = {
    Name = "${var.envname}-igw"
  }
}

#eip 
resource "aws_eip" "natIp" {
  vpc      = true
  tags = {
    Name = "${var.envname}-natIp"
  }

}

#nat in the pubsubnet 
resource "aws_nat_gateway" "natGw" {
  allocation_id = aws_eip.natIp.id
  subnet_id     = aws_subnet.pubsubnet[0].id
tags = {
    Name = "${var.envname}-natGw"
  }
}


#route table
resource "aws_route_table" "publicroute" {
  vpc_id = aws_vpc.anji.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
 tags = {
    Name = "${var.envname}-publicroute"
  }
}

resource "aws_route_table" "privateroute" {
  vpc_id = aws_vpc.anji.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natGw.id
  }
 tags = {
    Name = "${var.envname}-privateroute"
  }
}

resource "aws_route_table" "dataeroute" {
  vpc_id = aws_vpc.anji.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natGw.id
  }
 tags = {
    Name = "${var.envname}-dataroute"
  }
}


#associate
resource "aws_route_table_association" "pubsubassocation" {
  count = length(var.pubsubnets)
  subnet_id      = element(aws_subnet.pubsubnet.*.id,count.index)
  route_table_id = aws_route_table.publicroute.id
}
resource "aws_route_table_association" "prisubassocation" {
  count = length(var.privatesubnets)
  subnet_id      = element(aws_subnet.privatesubnet.*.id,count.index)
  route_table_id = aws_route_table.privateroute.id
}

resource "aws_route_table_association" "datasubassocation" {
  count = length(var.datasubnets)
  subnet_id      = element(aws_subnet.datasubnet.*.id,count.index)
  route_table_id = aws_route_table.dataeroute.id
}



resource "aws_security_group" "bastion" {
  name        = "bastion"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.anji.id

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
 
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.envname}-bastion-sg"
  }
  
}

# ec2 

#key
resource "aws_key_pair" "ram" {
  key_name   = "ram-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC/k5Lg8jK6d5jCJCKJlp2ocltd7WB9HZb2Vyid2w19xQ06O5A7zXLAdkN+3Nu+hdH1fpVW29fTIVeO/bN4FyipbRCrCiAAmztHkRDSHFuVy39flXPnIJIlHC9zZtwgd5PaHy70fZ88RqEXl0Siksi0TG07NEFcpm0kxnMBNU5qr0xoR2UhmsSmqsDpPZuFnnHxrFe0xM6XG8FQ/eCnUfpRoC5ADqFvm+rpbXcVtM6gylSXwFdeqoyRZnUkfWGEbGAzK2wznOQqBaDPc2S1RsdAyzK9nGECfwTKebsg0i/ZU4S1/R03JCmX9Xxv5n96h/Vuh+It/lZCzaAfHE3JpUYeJUVFynyw+JfykyJD8Xce1XGxK2to0mZh8M5pU7uwhE5DeSmAr4jvY94+8gjEhIep/zmKsuQVaWhkLMlGYghV4iaodUj2tPLlnuxl/N/IltJ+dDkghF+MMi5a5hpF21kjZd7NkmGOjUuY9WO3ZfmxEujKpnPRue5XiG5SbeMEtfM= ANJU YADAV@LAPTOP-IFFFOLT4"
}

resource "aws_instance" "bastion" {
  ami           = "ami-0d49cec198762b78c"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.pubsubnet[0].id
  key_name = aws_key_pair.ram.id 
  vpc_security_group_ids = ["${aws_security_group.bastion.id}"]


  tags = {
    Name = "${var.envname}-bastion"
  }
}
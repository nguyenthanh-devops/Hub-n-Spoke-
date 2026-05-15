# =====================================================
# 1. TẠO LẠI VPC 1 (EGRESS VPC CHUYÊN NGHIỆP)
# =====================================================
resource "aws_vpc" "vpc1_egress" {
  cidr_block           = "172.16.1.0/24"
  enable_dns_hostnames = true
  tags = { Name = "VPC-1-Egress" }
}

resource "aws_internet_gateway" "igw_vpc1" {
  vpc_id = aws_vpc.vpc1_egress.id
  tags   = { Name = "IGW-VPC1" }
}

# Subnet 1: Public (Chứa NAT Gateway & Trạm nhảy EC2)
resource "aws_subnet" "public_subnet_vpc1" {
  vpc_id                  = aws_vpc.vpc1_egress.id
  cidr_block              = "172.16.1.0/28"
  map_public_ip_on_launch = true
  tags                    = { Name = "VPC1-Public-Subnet" }
}

# Subnet 2: TGW Subnet (Chỉ để hứng traffic từ các mạng khác)
resource "aws_subnet" "tgw_subnet_vpc1" {
  vpc_id     = aws_vpc.vpc1_egress.id
  cidr_block = "172.16.1.16/28"
  tags       = { Name = "VPC1-TGW-Attach-Subnet" }
}

# =====================================================
# 2. KHỞI TẠO NAT GATEWAY (CỔNG DỊCH IP)
# =====================================================
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = { Name = "EIP-NAT-GW" }
}

resource "aws_nat_gateway" "central_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_vpc1.id # Đặt NAT ở mạng Public
  tags          = { Name = "Central-NAT-Gateway" }
  depends_on    = [aws_internet_gateway.igw_vpc1]
}

# =====================================================
# 3. ĐỊNH TUYẾN ÉP BUỘC TRONG VPC 1 (QUAN TRỌNG NHẤT)
# =====================================================
# RT của Public Subnet: Ra Internet thì qua IGW, về nội bộ thì qua TGW
resource "aws_route_table" "rt_public_vpc1" {
  vpc_id = aws_vpc.vpc1_egress.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_vpc1.id
  }
  route {
    cidr_block         = "172.16.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  }
  tags = { Name = "RT-VPC1-Public" }
}
resource "aws_route_table_association" "assoc_public_vpc1" {
  subnet_id      = aws_subnet.public_subnet_vpc1.id
  route_table_id = aws_route_table.rt_public_vpc1.id
}

# RT của TGW Subnet: Hứng traffic từ TGW và ÉP CHUI VÀO NAT GATEWAY
resource "aws_route_table" "rt_tgw_vpc1" {
  vpc_id = aws_vpc.vpc1_egress.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.central_nat.id # <--- Bẻ lái ra NAT
  }
  tags = { Name = "RT-VPC1-TGW-Attach" }
}
resource "aws_route_table_association" "assoc_tgw_vpc1" {
  subnet_id      = aws_subnet.tgw_subnet_vpc1.id
  route_table_id = aws_route_table.rt_tgw_vpc1.id
}

# =====================================================
# 4. KHỞI TẠO LẠI MÁY ẢO TRẠM NHẢY (BASTION HOST)
# =====================================================
module "ec2_1_reborn" {
  source        = "./modules/ec2"
  instance_name = "EC2-Host-1-Bastion"
  vpc_id        = aws_vpc.vpc1_egress.id
  subnet_id     = aws_subnet.public_subnet_vpc1.id
  ami_id        = data.aws_ami.amazon_linux.id
  key_name      = aws_key_pair.deployer.key_name
}
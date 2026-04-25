# Lấy hệ điều hành Amazon Linux mới nhất
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 1. Sinh khóa Private Key thuật toán RSA
resource "tls_private_key" "my_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 2. Đăng ký Public Key lên AWS
resource "aws_key_pair" "deployer" {
  key_name   = "capstone-key"
  public_key = tls_private_key.my_key.public_key_openssh
}

# 3. Tự động lưu file .pem xuống máy tính
resource "local_file" "private_key" {
  content         = tls_private_key.my_key.private_key_pem
  filename        = "${path.module}/capstone-key.pem"
  file_permission = "0400" # Cấp quyền Read-only bảo mật cho file
}

# ==========================================
# Kêu gọi Module tạo 4 VPC
# ==========================================
module "vpc1" {
  source    = "./modules/vpc"
  vpc_cidr  = var.vpc_cidrs["vpc1"]
  vpc_name  = "VPC-1-Public"
  is_public = true
}

module "vpc2" {
  source    = "./modules/vpc"
  vpc_cidr  = var.vpc_cidrs["vpc2"]
  vpc_name  = "VPC-2-Private"
  is_public = false
}

module "vpc3" {
  source    = "./modules/vpc"
  vpc_cidr  = var.vpc_cidrs["vpc3"]
  vpc_name  = "VPC-3-Public"
  is_public = true
}

module "vpc4" {
  source    = "./modules/vpc"
  vpc_cidr  = var.vpc_cidrs["vpc4"]
  vpc_name  = "VPC-4-Private"
  is_public = false
}

# ==========================================
# Kêu gọi Module tạo 4 EC2 gắn vào 4 VPC trên
# ==========================================
module "ec2_1" {
  source        = "./modules/ec2"
  instance_name = "EC2-Host-1"
  vpc_id        = module.vpc1.vpc_id
  subnet_id     = module.vpc1.subnet_id
  ami_id        = data.aws_ami.amazon_linux.id
  key_name      = aws_key_pair.deployer.key_name
}

module "ec2_2" {
  source        = "./modules/ec2"
  instance_name = "EC2-Host-2"
  vpc_id        = module.vpc2.vpc_id
  subnet_id     = module.vpc2.subnet_id
  ami_id        = data.aws_ami.amazon_linux.id
  key_name      = aws_key_pair.deployer.key_name
}

module "ec2_3" {
  source        = "./modules/ec2"
  instance_name = "EC2-Host-3"
  vpc_id        = module.vpc3.vpc_id
  subnet_id     = module.vpc3.subnet_id
  ami_id        = data.aws_ami.amazon_linux.id
  key_name      = aws_key_pair.deployer.key_name
}

module "ec2_4" {
  source        = "./modules/ec2"
  instance_name = "EC2-Host-4"
  vpc_id        = module.vpc4.vpc_id
  subnet_id     = module.vpc4.subnet_id
  ami_id        = data.aws_ami.amazon_linux.id
  key_name      = aws_key_pair.deployer.key_name
}
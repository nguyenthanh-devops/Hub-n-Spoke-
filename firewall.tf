# =====================================================
# 1. TẠO VPC 3 (INSPECTION VPC)
# =====================================================
resource "aws_vpc" "vpc3_inspection" {
  cidr_block           = "172.16.3.0/24"
  enable_dns_hostnames = true
  tags = { Name = "VPC-3-Inspection" }
}

# Subnet 1: Chứa TGW Attachment
resource "aws_subnet" "tgw_attach_subnet_vpc3" {
  vpc_id     = aws_vpc.vpc3_inspection.id
  cidr_block = "172.16.3.0/28"
  tags       = { Name = "VPC3-TGW-Attach-Subnet" }
}

# Subnet 2: Chứa Máy ảo EC2 Firewall
resource "aws_subnet" "fw_subnet_vpc3" {
  vpc_id     = aws_vpc.vpc3_inspection.id
  cidr_block = "172.16.3.16/28"
  tags       = { Name = "VPC3-EC2-Firewall-Subnet" }
}

# =====================================================
# 2. KHỞI TẠO EC2 FIREWALL (FREE TIER)
# =====================================================
# Security Group cho Firewall: Phải cho phép mọi luồng traffic đi qua để nó xử lý
resource "aws_security_group" "sg_ec2_firewall" {
  name        = "sg_ec2_firewall"
  description = "Allow all traffic for routing"
  vpc_id      = aws_vpc.vpc3_inspection.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks =["172.16.0.0/16"] # Nhận mọi traffic từ nội mạng
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2_firewall" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro" # MIỄN PHÍ
  subnet_id              = aws_subnet.fw_subnet_vpc3.id
  vpc_security_group_ids = [aws_security_group.sg_ec2_firewall.id]
  key_name               = aws_key_pair.deployer.key_name

  # TUYỆT KỸ 1: Bắt buộc phải TẮT tính năng này thì EC2 mới làm Router được
  source_dest_check = false 

  # TUYỆT KỸ 2: Script can thiệp vào nhân Linux (Bật IP Forwarding & iptables)
  user_data = <<-EOF
              #!/bin/bash
              # 1. Bật tính năng chuyển tiếp gói tin (IP Forwarding)
              echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
              sysctl -p

              # 2. Xóa các luật cũ
              iptables -F

              # =========================================================
              # 3. CHỐNG NMAP PORT SCANNING (XMAS SCAN & NULL SCAN)
              # =========================================================
              # Bắt và chặn các gói tin có cờ TCP bất hợp lệ (Kỹ thuật giấu thân của Hacker)
              iptables -A FORWARD -p tcp --tcp-flags FIN,PSH,URG FIN,PSH,URG -j LOG --log-prefix "FW-DROP-NMAP-XMAS: "
              iptables -A FORWARD -p tcp --tcp-flags FIN,PSH,URG FIN,PSH,URG -j DROP
              
              iptables -A FORWARD -p tcp --tcp-flags ALL NONE -j LOG --log-prefix "FW-DROP-NMAP-NULL: "
              iptables -A FORWARD -p tcp --tcp-flags ALL NONE -j DROP

              # =========================================================
              # 4. CHỐNG TẤN CÔNG DDOS / DOS (PING FLOOD)
              # =========================================================
              # Cho phép Ping nhưng RATE LIMIT: Tối đa 1 gói/giây (bình thường)
              iptables -A FORWARD -p icmp -m limit --limit 1/s --limit-burst 2 -j ACCEPT
              
              # Nếu vượt quá 1 gói/giây (Tấn công DoS) -> Ghi Log và Tiêu diệt
              iptables -A FORWARD -p icmp -j LOG --log-prefix "FW-DROP-DOS-PING: "
              iptables -A FORWARD -p icmp -j DROP
              EOF
              
  tags = { Name = "EC2-Linux-Firewall" }
}

# =====================================================
# 3. ĐỊNH TUYẾN TRONG VPC 3 (ÉP GÓI TIN CHUI VÀO EC2)
# =====================================================
# Bảng định tuyến TGW Subnet: BẮT BUỘC ĐẨY VÀO CARD MẠNG CỦA EC2
resource "aws_route_table" "tgw_attach_rt" {
  vpc_id = aws_vpc.vpc3_inspection.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.ec2_firewall.primary_network_interface_id
  }
  tags = { Name = "VPC3-TGW-Attach-RT" }
}
resource "aws_route_table_association" "tgw_attach_assoc" {
  subnet_id      = aws_subnet.tgw_attach_subnet_vpc3.id
  route_table_id = aws_route_table.tgw_attach_rt.id
}

# Bảng định tuyến EC2 Subnet: SOI XONG TRẢ LẠI TGW
resource "aws_route_table" "fw_subnet_rt" {
  vpc_id = aws_vpc.vpc3_inspection.id
  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  }
  tags = { Name = "VPC3-EC2FW-Subnet-RT" }
}
resource "aws_route_table_association" "fw_assoc" {
  subnet_id      = aws_subnet.fw_subnet_vpc3.id
  route_table_id = aws_route_table.fw_subnet_rt.id
}
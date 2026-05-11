# ==========================================
# 1. KHỞI TẠO TRANSIT GATEWAY 
# ==========================================
resource "aws_ec2_transit_gateway" "main_tgw" {
  description                     = "Central Hub with Network Segmentation"
  auto_accept_shared_attachments  = "enable"
  
  # BẮT BUỘC TẮT 2 DÒNG NÀY ĐỂ LÀM CÁCH LY MẠNG
  default_route_table_association = "disable" 
  default_route_table_propagation = "disable"
  
  tags = { Name = "Capstone-TGW-Segmented" }
}

# ==========================================
# 2. VPC ATTACHMENTS (CẮM NHÁNH VÀO HUB)
# ==========================================

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_att_2" {
  subnet_ids         = [module.vpc2.subnet_id]
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpc_id             = module.vpc2.vpc_id
  tags               = { Name = "TGW-Attachment-VPC2" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_att_3" {
  subnet_ids         =[aws_subnet.tgw_attach_subnet_vpc3.id] 
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpc_id             = aws_vpc.vpc3_inspection.id
  appliance_mode_support = "enable" 
  tags = { Name = "TGW-Attachment-VPC3-Inspection" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_att_4" {
  subnet_ids         =[module.vpc4.subnet_id]
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpc_id             = module.vpc4.vpc_id
  tags               = { Name = "TGW-Attachment-VPC4" }
}

# ==========================================
# 3. TẠO TGW ROUTE TABLES RIÊNG BIỆT
# ==========================================
# Bảng 1 dành cho VPC Quản trị (Được phép đi muôn nơi)
resource "aws_ec2_transit_gateway_route_table" "public_rt" {
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  tags = { Name = "TGW-RT-Public-Shared" }
}

# Bảng 2 dành cho VPC bị Cách ly (Không cho nhìn thấy nhau)
resource "aws_ec2_transit_gateway_route_table" "private_rt" {
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  tags = { Name = "TGW-RT-Private-Isolated" }
}

# Bảng 3 dành riêng cho VPC 3 (Sau khi đã soi mã độc xong)
resource "aws_ec2_transit_gateway_route_table" "inspection_rt" {
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  tags = { Name = "TGW-RT-Inspection-PostFW" }
}

# ==========================================
# 4. ASSOCIATIONS (Ai dùng Bảng nào?)
# ==========================================
resource "aws_ec2_transit_gateway_route_table_association" "assoc_vpc1" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_att_1.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.public_rt.id
}
resource "aws_ec2_transit_gateway_route_table_association" "assoc_vpc3" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_att_3.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection_rt.id
}
resource "aws_ec2_transit_gateway_route_table_association" "assoc_vpc2" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_att_2.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.private_rt.id
}
resource "aws_ec2_transit_gateway_route_table_association" "assoc_vpc4" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_att_4.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.private_rt.id
}

# ==========================================
# 5. PROPAGATIONS (Bơm đường đi - Cốt lõi của Cách ly mạng)
# ==========================================
# Bảng Public_RT học đường đến TẤT CẢ các VPC (1, 2, 3, 4)
resource "aws_ec2_transit_gateway_route_table_propagation" "prop_to_public" {
  count = 4
  transit_gateway_attachment_id  =[
    aws_ec2_transit_gateway_vpc_attachment.tgw_att_1.id,
    aws_ec2_transit_gateway_vpc_attachment.tgw_att_2.id,
    aws_ec2_transit_gateway_vpc_attachment.tgw_att_3.id,
    aws_ec2_transit_gateway_vpc_attachment.tgw_att_4.id
  ][count.index]
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.public_rt.id
}

# Bảng Private_RT CHỈ ĐƯỢC học đường đến VPC 1 và VPC 3 (Quản trị). 
# TUYỆT ĐỐI KHÔNG BƠM ĐƯỜNG của VPC 2 và 4 vào đây.
resource "aws_ec2_transit_gateway_route_table_propagation" "prop_to_private" {
  count = 2
  transit_gateway_attachment_id  =[
    aws_ec2_transit_gateway_vpc_attachment.tgw_att_1.id,
    aws_ec2_transit_gateway_vpc_attachment.tgw_att_3.id
  ][count.index]
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.private_rt.id
}

# ==========================================
# 6. ĐỊNH TUYẾN CHÍNH XÁC Ở VPC (CHỈ CÒN VPC 2 VÀ VPC 4)
# ==========================================
# GHI CHÚ: VPC 1 (Egress) và VPC 3 (Firewall) đã được định tuyến riêng 
# tại file egress.tf và firewall.tf nên ta xóa chúng khỏi danh sách này.

locals {
  vpc2_routes = [var.vpc_cidrs["vpc1"], var.vpc_cidrs["vpc3"], var.vpc_cidrs["vpc4"]]
  vpc4_routes =[var.vpc_cidrs["vpc1"], var.vpc_cidrs["vpc2"], var.vpc_cidrs["vpc3"]]
}

resource "aws_route" "routes_from_vpc2" {
  count                  = length(local.vpc2_routes)
  route_table_id         = module.vpc2.route_table_id
  destination_cidr_block = local.vpc2_routes[count.index]
  transit_gateway_id     = aws_ec2_transit_gateway.main_tgw.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.tgw_att_2]
}

resource "aws_route" "routes_from_vpc4" {
  count                  = length(local.vpc4_routes)
  route_table_id         = module.vpc4.route_table_id
  destination_cidr_block = local.vpc4_routes[count.index]
  transit_gateway_id     = aws_ec2_transit_gateway.main_tgw.id
  depends_on             =[aws_ec2_transit_gateway_vpc_attachment.tgw_att_4]
}

# ==========================================
# 7. BẺ LÁI ĐỊNH TUYẾN (INSPECTION & EGRESS ROUTES)
# ==========================================

# Gắn VPC 1 vào TGW (Dùng Subnet của Egress VPC)
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_att_1" {
  subnet_ids         =[aws_subnet.tgw_subnet_vpc1.id] 
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpc_id             = aws_vpc.vpc1_egress.id          
  tags               = { Name = "TGW-Attachment-VPC1-Egress" }
} 

# Bảng Public_RT (VPC 1) muốn đi VPC 4 -> Ép chạy sang VPC 3 (Firewall)
resource "aws_ec2_transit_gateway_route" "vpc1_to_vpc4_via_fw" {
  destination_cidr_block         = "172.16.4.0/24"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.public_rt.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_att_3.id
}

# Bảng Private_RT (VPC 4) muốn đi VPC 1 -> Ép chạy sang VPC 3 (Firewall)
resource "aws_ec2_transit_gateway_route" "vpc4_to_vpc1_via_fw" {
  destination_cidr_block         = "172.16.1.0/24"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.private_rt.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_att_3.id
}

# Bảng Inspection_RT (VPC 3) sau khi Firewall duyệt xong -> Cho đi tiếp vào VPC 4
resource "aws_ec2_transit_gateway_route" "vpc3_to_vpc4" {
  destination_cidr_block         = "172.16.4.0/24"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection_rt.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_att_4.id
}

# Báo cho TGW: Ai dùng mạng Private muốn ra Internet (0.0.0.0/0) thì đẩy sang VPC 1
resource "aws_ec2_transit_gateway_route" "internet_route_for_private" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.private_rt.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_att_1.id
}

# Báo cho máy ảo VPC 2: Muốn ra Internet thì đẩy gói tin vào TGW
resource "aws_route" "vpc2_default_to_tgw" {
  route_table_id         = module.vpc2.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.main_tgw.id
  depends_on             =[aws_ec2_transit_gateway_vpc_attachment.tgw_att_2]
}

# Báo cho máy ảo VPC 4: Muốn ra Internet thì đẩy gói tin vào TGW
resource "aws_route" "vpc4_default_to_tgw" {
  route_table_id         = module.vpc4.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.main_tgw.id
  depends_on             =[aws_ec2_transit_gateway_vpc_attachment.tgw_att_4]
}
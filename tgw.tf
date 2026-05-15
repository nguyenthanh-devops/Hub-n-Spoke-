# ==========================================
# 1. KHỞI TẠO TRANSIT GATEWAY 
# ==========================================
resource "aws_ec2_transit_gateway" "main_tgw" {
  description                     = "Central Hub with Network Segmentation"
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "disable" 
  default_route_table_propagation = "disable"
  tags = { Name = "Capstone-TGW-Segmented" }
}

# ==========================================
# 2. VPC ATTACHMENTS (CẮM NHÁNH VÀO HUB)
# ==========================================
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_att_1" {
  subnet_ids         =[aws_subnet.tgw_subnet_vpc1.id] 
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpc_id             = aws_vpc.vpc1_egress.id          
  tags               = { Name = "TGW-Attachment-VPC1-Egress" }
} 

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_att_2" {
  subnet_ids         = [module.vpc2.subnet_id]
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpc_id             = module.vpc2.vpc_id
  tags               = { Name = "TGW-Attachment-VPC2-DEV" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_att_3" {
  subnet_ids             = [aws_subnet.tgw_attach_subnet_vpc3.id] 
  transit_gateway_id     = aws_ec2_transit_gateway.main_tgw.id
  vpc_id                 = aws_vpc.vpc3_inspection.id
  appliance_mode_support = "enable" 
  tags                   = { Name = "TGW-Attachment-VPC3-Inspection" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_att_4" {
  subnet_ids         = [module.vpc4.subnet_id]
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpc_id             = module.vpc4.vpc_id
  tags               = { Name = "TGW-Attachment-VPC4-PROD" }
}

# ==========================================
# 3. TẠO TGW ROUTE TABLES RIÊNG BIỆT (ĐÃ FIX LỖI)
# ==========================================
resource "aws_ec2_transit_gateway_route_table" "public_rt" {
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  tags = { Name = "TGW-RT-Public-Shared" }
}
resource "aws_ec2_transit_gateway_route_table" "dev_rt" {
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  tags = { Name = "TGW-RT-Private-DEV" }
}
resource "aws_ec2_transit_gateway_route_table" "prod_rt" {
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  tags = { Name = "TGW-RT-Private-PROD" }
}
resource "aws_ec2_transit_gateway_route_table" "inspection_rt" {
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  tags = { Name = "TGW-RT-Inspection-PostFW" }
}

# ==========================================
# 4. ASSOCIATIONS (Ai dùng Bảng nào?)
# ==========================================
resource "aws_ec2_transit_gateway_route_table_association" "assoc_vpc1" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_att_1.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.public_rt.id
}

resource "aws_ec2_transit_gateway_route_table_association" "assoc_vpc2" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_att_2.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev_rt.id
}

resource "aws_ec2_transit_gateway_route_table_association" "assoc_vpc3" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_att_3.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection_rt.id
}

resource "aws_ec2_transit_gateway_route_table_association" "assoc_vpc4" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_att_4.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod_rt.id
}

# ==========================================
# 5. PROPAGATIONS (TỰ ĐỘNG HỌC ĐƯỜNG NỘI BỘ - BẮT BUỘC)
# ==========================================
# Bảng Public học rõ ràng đường đến V1, V2, V3
resource "aws_ec2_transit_gateway_route_table_propagation" "pub_prop_1" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_att_1.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.public_rt.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "pub_prop_2" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_att_2.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.public_rt.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "pub_prop_3" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_att_3.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.public_rt.id
}

# Bảng DEV học rõ ràng đường đến V1, V3 (Bỏ 0.0.0.0/0 nội bộ)
resource "aws_ec2_transit_gateway_route_table_propagation" "dev_prop_1" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_att_1.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev_rt.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "dev_prop_3" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_att_3.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev_rt.id
}

# Bảng PROD không học ai cả, ÉP ĐI QUA TƯỜNG LỬA HẾT (Static Route ở dưới).

# Bảng Inspection học rõ ràng V1, V2, V4 (Để Tường lửa soi xong biết đường trả về)
resource "aws_ec2_transit_gateway_route_table_propagation" "insp_prop_1" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_att_1.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection_rt.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "insp_prop_2" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_att_2.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection_rt.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "insp_prop_4" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_att_4.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection_rt.id
}

# ==========================================
# 6. BẺ LÁI ĐỊNH TUYẾN (STATIC ROUTES CHUYÊN SÂU)
# ==========================================
# Ép VPC 1 muốn đi VPC 4 -> Chạy sang VPC 3 (Firewall)
resource "aws_ec2_transit_gateway_route" "vpc1_to_vpc4_via_fw" {
  destination_cidr_block         = "172.16.4.0/24"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.public_rt.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_att_3.id
}

# Mọi luồng từ VPC 4 muốn về VPC 1 hoặc ra Internet đều PHẢI QUA FIREWALL
resource "aws_ec2_transit_gateway_route" "vpc4_to_vpc1_fw" {
  destination_cidr_block         = "172.16.1.0/24"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod_rt.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_att_3.id
}
resource "aws_ec2_transit_gateway_route" "vpc4_to_internet_fw" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod_rt.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_att_3.id
}

# VPC 2 (DEV) muốn ra Internet thì ném thẳng ra VPC 1
resource "aws_ec2_transit_gateway_route" "vpc2_to_internet" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev_rt.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_att_1.id
}

# Tường lửa sau khi xử lý xong, nếu traffic muốn ra Internet thì ném về VPC 1
resource "aws_ec2_transit_gateway_route" "fw_to_internet" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection_rt.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_att_1.id
}

# =====================================================
# 7. VÁ LỖ HỔNG ROUTING LEAK BẰNG BLACKHOLE CHUYÊN BIỆT
# =====================================================
# Ở bảng DEV: Gặp gói tin tìm đến PROD là Tiêu diệt
resource "aws_ec2_transit_gateway_route" "blackhole_vpc4_in_dev" {
  destination_cidr_block         = "172.16.4.0/24" 
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev_rt.id
  blackhole                      = true
}

# Ở bảng PROD: Gặp gói tin tìm đến DEV là Tiêu diệt
resource "aws_ec2_transit_gateway_route" "blackhole_vpc2_in_prod" {
  destination_cidr_block         = "172.16.2.0/24" 
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod_rt.id
  blackhole                      = true
}

# ==========================================
# 8. CẬP NHẬT ROUTE TABLE CHO VPC (Giữ nguyên)
# ==========================================
resource "aws_route" "vpc2_default_to_tgw" {
  route_table_id         = module.vpc2.route_table_id
  destination_cidr_block = "0.0.0.0/0" 
  transit_gateway_id     = aws_ec2_transit_gateway.main_tgw.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.tgw_att_2]
}

resource "aws_route" "vpc4_default_to_tgw" {
  route_table_id         = module.vpc4.route_table_id
  destination_cidr_block = "0.0.0.0/0" 
  transit_gateway_id     = aws_ec2_transit_gateway.main_tgw.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.tgw_att_4]
}
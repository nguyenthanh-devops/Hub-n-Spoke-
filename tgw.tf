# ==========================================
# 1. KHỞI TẠO TRANSIT GATEWAY (HUB)
# ==========================================
resource "aws_ec2_transit_gateway" "main_tgw" {
  description                     = "Central Hub for Capstone Project"
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  tags                            = { Name = "Capstone-Transit-Gateway" }
}

# ==========================================
# 2. VPC ATTACHMENTS (CẮM CÁC NHÁNH VÀO HUB)
# ==========================================
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_att_1" {
  subnet_ids         =[module.vpc1.subnet_id]
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpc_id             = module.vpc1.vpc_id
  tags               = { Name = "TGW-Attachment-VPC1" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_att_2" {
  subnet_ids         = [module.vpc2.subnet_id]
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpc_id             = module.vpc2.vpc_id
  tags               = { Name = "TGW-Attachment-VPC2" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_att_3" {
  subnet_ids         = [module.vpc3.subnet_id]
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpc_id             = module.vpc3.vpc_id
  tags               = { Name = "TGW-Attachment-VPC3" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_att_4" {
  subnet_ids         = [module.vpc4.subnet_id]
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpc_id             = module.vpc4.vpc_id
  tags               = { Name = "TGW-Attachment-VPC4" }
}

# ==========================================
# 3. ĐỊNH TUYẾN CHÍNH XÁC (EXPLICIT ROUTING)
# ==========================================

# Tính toán danh sách các dải IP đích mà mỗi VPC cần biết đường đi tới
locals {
  vpc1_routes =[var.vpc_cidrs["vpc2"], var.vpc_cidrs["vpc3"], var.vpc_cidrs["vpc4"]]
  vpc2_routes = [var.vpc_cidrs["vpc1"], var.vpc_cidrs["vpc3"], var.vpc_cidrs["vpc4"]]
  vpc3_routes = [var.vpc_cidrs["vpc1"], var.vpc_cidrs["vpc2"], var.vpc_cidrs["vpc4"]]
  vpc4_routes = [var.vpc_cidrs["vpc1"], var.vpc_cidrs["vpc2"], var.vpc_cidrs["vpc3"]]
}

# Khai báo các Route từ VPC 1 trỏ vào Transit Gateway
resource "aws_route" "routes_from_vpc1" {
  count                  = length(local.vpc1_routes)
  route_table_id         = module.vpc1.route_table_id
  destination_cidr_block = local.vpc1_routes[count.index]
  transit_gateway_id     = aws_ec2_transit_gateway.main_tgw.id
  depends_on             =[aws_ec2_transit_gateway_vpc_attachment.tgw_att_1]
}

# Khai báo các Route từ VPC 2 trỏ vào Transit Gateway
resource "aws_route" "routes_from_vpc2" {
  count                  = length(local.vpc2_routes)
  route_table_id         = module.vpc2.route_table_id
  destination_cidr_block = local.vpc2_routes[count.index]
  transit_gateway_id     = aws_ec2_transit_gateway.main_tgw.id
  depends_on             =[aws_ec2_transit_gateway_vpc_attachment.tgw_att_2]
}

# Khai báo các Route từ VPC 3 trỏ vào Transit Gateway
resource "aws_route" "routes_from_vpc3" {
  count                  = length(local.vpc3_routes)
  route_table_id         = module.vpc3.route_table_id
  destination_cidr_block = local.vpc3_routes[count.index]
  transit_gateway_id     = aws_ec2_transit_gateway.main_tgw.id
  depends_on             =[aws_ec2_transit_gateway_vpc_attachment.tgw_att_3]
}

# Khai báo các Route từ VPC 4 trỏ vào Transit Gateway
resource "aws_route" "routes_from_vpc4" {
  count                  = length(local.vpc4_routes)
  route_table_id         = module.vpc4.route_table_id
  destination_cidr_block = local.vpc4_routes[count.index]
  transit_gateway_id     = aws_ec2_transit_gateway.main_tgw.id
  depends_on             =[aws_ec2_transit_gateway_vpc_attachment.tgw_att_4]
}
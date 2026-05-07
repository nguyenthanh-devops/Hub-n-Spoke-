# =====================================================
# 1. TẠO VPC 3 ĐẶC THÙ (INSPECTION VPC) VÀ TÁCH 2 SUBNET
# =====================================================
resource "aws_vpc" "vpc3_inspection" {
  cidr_block           = "172.16.3.0/24"
  enable_dns_hostnames = true
  tags = { Name = "VPC-3-Inspection" }
}

# Subnet 1: Dành riêng cho Transit Gateway
resource "aws_subnet" "tgw_attach_subnet_vpc3" {
  vpc_id     = aws_vpc.vpc3_inspection.id
  cidr_block = "172.16.3.0/28" 
  tags       = { Name = "VPC3-TGW-Attach-Subnet" }
}

# Subnet 2: Dành riêng cho Cục Firewall
resource "aws_subnet" "fw_subnet_vpc3" {
  vpc_id     = aws_vpc.vpc3_inspection.id
  cidr_block = "172.16.3.16/28" 
  tags       = { Name = "VPC3-Firewall-Endpoint-Subnet" }
}

# =====================================================
# 2. LOGGING - BẰNG CHỨNG ĐỂ DEMO (CLOUDWATCH)
# =====================================================
resource "aws_cloudwatch_log_group" "fw_alerts" {
  name              = "/aws/network-firewall/alerts"
  retention_in_days = 3 # Giảm xuống 3 ngày cho tiết kiệm
}

# =====================================================
# 3. RULE GROUP - "VŨ KHÍ" SURICATA (CHẶN MÃ ĐỘC L7)
# =====================================================
resource "aws_networkfirewall_rule_group" "ips_rules" {
  capacity = 500
  name     = "advanced-ips-rules"
  type     = "STATEFUL"
  rule_group {
    rules_source {
      rules_string = <<EOF
# 1. Chặn SQL Injection giả lập
drop http $HOME_NET any -> $EXTERNAL_NET any (http.uri; content:"union"; nocase; msg:"Mối đe dọa: SQL Injection detected (UNION)"; sid:1000001; rev:1;)
drop http $HOME_NET any -> $EXTERNAL_NET any (http.uri; content:"select"; nocase; msg:"Mối đe dọa: SQL Injection detected (SELECT)"; sid:1000002; rev:1;)

# 2. Chặn Domain độc hại
drop http $HOME_NET any -> $EXTERNAL_NET any (http.host; dotprefix; content:"evil.com"; msg:"Mối đe dọa: Malicious Domain (evil.com)"; sid:1000003; rev:1;)

# 3. Chặn Log4j giả lập
drop tcp any any -> any any (content:"jndi:ldap"; nocase; msg:"Mối đe dọa: Log4j Exploit Attempt"; sid:1000004; rev:1;)

# 4. Vẫn giữ chặn Ping Layer 4
drop icmp 172.16.1.0/24 any -> 172.16.4.0/24 any (msg:"Mối đe dọa: Unauthorized Ping to Prod"; sid:1000005; rev:1;)
EOF
    }
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }
}

# =====================================================
# 4. FIREWALL POLICY & KHỞI TẠO FIREWALL
# =====================================================
resource "aws_networkfirewall_firewall_policy" "fw_policy" {
  name = "central-inspection-policy"
  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.ips_rules.arn
    }
  }
}

resource "aws_networkfirewall_firewall" "inspection_fw" {
  name                = "Capstone-Inspection-FW"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.fw_policy.arn
  vpc_id              = aws_vpc.vpc3_inspection.id
  subnet_mapping {
    subnet_id = aws_subnet.fw_subnet_vpc3.id # Trỏ đúng vào Subnet số 2
  }
}

resource "aws_networkfirewall_logging_configuration" "fw_log_config" {
  firewall_arn = aws_networkfirewall_firewall.inspection_fw.arn
  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.fw_alerts.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
  }
}

# =====================================================
# 5. ĐỊNH TUYẾN "MA THUẬT" TRONG VPC 3 (INLINE INSPECTION)
# =====================================================
# Lấy Endpoint ID của Firewall (Tự động hóa)
locals {
  fw_endpoint_id = element([for ss in aws_networkfirewall_firewall.inspection_fw.firewall_status[0].sync_states : ss.attachment[0].endpoint_id if ss.attachment[0].subnet_id == aws_subnet.fw_subnet_vpc3.id], 0)
}

# Bảng định tuyến TGW Subnet: BẮT BUỘC ĐẨY VÀO FIREWALL
resource "aws_route_table" "tgw_attach_rt" {
  vpc_id = aws_vpc.vpc3_inspection.id
  route {
    cidr_block      = "0.0.0.0/0" 
    vpc_endpoint_id = local.fw_endpoint_id
  }
  tags = { Name = "VPC3-TGW-Attach-RT" }
}
resource "aws_route_table_association" "tgw_attach_assoc" {
  subnet_id      = aws_subnet.tgw_attach_subnet_vpc3.id
  route_table_id = aws_route_table.tgw_attach_rt.id
}

# Bảng định tuyến FW Subnet: SOI XONG TRẢ LẠI TGW ĐỂ ĐI TỚI ĐÍCH
resource "aws_route_table" "fw_subnet_rt" {
  vpc_id = aws_vpc.vpc3_inspection.id
  route {
    cidr_block         = "0.0.0.0/0" 
    transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  }
  tags = { Name = "VPC3-Firewall-Subnet-RT" }
}
resource "aws_route_table_association" "fw_assoc" {
  subnet_id      = aws_subnet.fw_subnet_vpc3.id
  route_table_id = aws_route_table.fw_subnet_rt.id
}
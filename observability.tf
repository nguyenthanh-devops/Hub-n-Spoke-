# ==========================================
# 1. TẠO CLOUDWATCH LOG GROUP
# ==========================================
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/capstone-flow-logs"
  retention_in_days = 3 # Giữ log 3 ngày cho đồ án là đủ, giữ lâu tốn tiền
}

# ==========================================
# 2. IAM ROLE & POLICY CHO VPC FLOW LOGS
# ==========================================
# Tạo Role cho phép dịch vụ VPC được quyền đẩy Log
resource "aws_iam_role" "vpc_flow_log_role" {
  name = "vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement =[
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

# Cấp quyền ghi Log vào CloudWatch cho Role trên
resource "aws_iam_role_policy" "vpc_flow_log_policy" {
  name = "vpc-flow-log-policy"
  role = aws_iam_role.vpc_flow_log_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement =[
      {
        Action =[
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# ==========================================
# 3. BẬT FLOW LOGS CHO VPC 2 (PRIVATE)
# ==========================================
resource "aws_flow_log" "vpc2_flow_log" {
  iam_role_arn    = aws_iam_role.vpc_flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL" # Bắt cả gói tin được cho phép (ACCEPT) và bị chặn (REJECT)
  vpc_id          = module.vpc2.vpc_id # Giám sát toàn bộ VPC 2
  
  tags = { Name = "VPC2-Flow-Logs" }
}

# ==========================================
# 4. BẬT FLOW LOGS CHO TRANSIT GATEWAY 
# ==========================================
resource "aws_cloudwatch_log_group" "tgw_flow_logs" {
  name              = "/aws/tgw/capstone-flow-logs"
  retention_in_days = 3 
}

resource "aws_flow_log" "tgw_flow_log" {
  iam_role_arn       = aws_iam_role.vpc_flow_log_role.arn
  log_destination    = aws_cloudwatch_log_group.tgw_flow_logs.arn
  traffic_type       = "ALL"
  
  # Thay vì vpc_id, ta gắn thẳng vào cục Transit Gateway
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id 
  max_aggregation_interval = 60
  
  tags = { Name = "TGW-Flow-Logs" }
}
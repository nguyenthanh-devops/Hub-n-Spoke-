resource "aws_security_group" "this" {
  name        = "sg_${var.instance_name}"
  description = "Allow SSH and ICMP"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks =["0.0.0.0/0"]
  }
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks =["172.16.0.0/16"] # Chỉ cho ping trong mạng nội bộ
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "SG-${var.instance_name}" }
}

resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = var.key_name 
  tags = { Name = var.instance_name }
}
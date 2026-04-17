variable "vpc_cidr" { type = string }
variable "vpc_name" { type = string }
variable "is_public" { 
  type = bool
  default = false 
}
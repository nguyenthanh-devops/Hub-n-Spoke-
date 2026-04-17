variable "vpc_cidrs" {
  type = map(string)
  default = {
    "vpc1" = "172.16.1.0/24"
    "vpc2" = "172.16.2.0/24"
    "vpc3" = "172.16.3.0/24"
    "vpc4" = "172.16.4.0/24"
  }
}
# Hub-n-Spoke Infrastructure on AWS

Dự án này sử dụng **Terraform** để triển khai mô hình mạng Hub-and-Spoke với AWS Transit Gateway (TGW).

## 📌 Chức năng chính
- Khởi tạo **VPC Hub** và các **VPC Spoke**.
- Kết nối các VPC thông qua **Transit Gateway**.
- Quản lý hạ tầng bằng **Terraform Modules** (VPC, EC2).

## 🛠 Yêu cầu hệ thống
- Terraform v1.0+
- AWS CLI đã cấu hình (Access Key/Secret Key)

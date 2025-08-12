---
title : "Yêu cầu & Thiết lập"
date : "`r Sys.Date()`"
weight : 2
chapter : false
pre : " <b> 2. </b> "
---

# Yêu cầu & Thiết lập

Trước khi bắt đầu workshop ECS Advanced Networking, hãy đảm bảo môi trường của bạn được cấu hình đúng với tất cả các tools và permissions cần thiết.

## Yêu cầu AWS Account

### Thiết lập Account
- **AWS Account** với billing enabled
- **Administrative access** hoặc permissions tương đương cho:
  - EC2 (VPC, Security Groups, Load Balancers)
  - ECS (Clusters, Services, Tasks)
  - IAM (Roles, Policies)
  - CloudWatch (Logs, Metrics)
  - Route 53 (cho Service Discovery)

### Cân nhắc về Chi phí
- **Ước tính chi phí workshop**: $15-25
- **Free Tier eligible**: Một số services (CloudWatch Logs, limited ECS usage)
- **Billing alerts**: Khuyến nghị thiết lập trước khi bắt đầu

> **Cảnh báo**: Workshop này sẽ tạo AWS resources phát sinh chi phí. Hãy chắc chắn hoàn thành phần cleanup ở cuối!

## Tools cần thiết

### 1. AWS CLI v2
Cài đặt và cấu hình AWS Command Line Interface:

```bash
# Cài đặt AWS CLI v2 (Linux/macOS)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Xác minh cài đặt
aws --version
```

**Cấu hình AWS CLI:**
```bash
aws configure
# Nhập Access Key ID của bạn
# Nhập Secret Access Key của bạn
# Default region: us-east-1 (khuyến nghị cho workshop này)
# Default output format: json
```

### 2. Docker Desktop
Cài đặt Docker cho local container testing:

- **Windows/macOS**: [Docker Desktop](https://www.docker.com/products/docker-desktop)
- **Linux**: [Docker Engine](https://docs.docker.com/engine/install/)

```bash
# Xác minh Docker installation
docker --version
docker run hello-world
```

### 3. Text Editor/IDE
Editors được khuyến nghị với AWS/Docker support:
- **Visual Studio Code** với AWS Toolkit extension
- **AWS Cloud9** (browser-based IDE)
- **IntelliJ IDEA** với AWS plugin

### 4. Git (Tùy chọn)
Để clone workshop materials:
```bash
git --version
```

## AWS Permissions

### Required IAM Permissions
AWS user/role của bạn cần các permissions sau:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "ecs:*",
                "elasticloadbalancing:*",
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "iam:PassRole",
                "logs:*",
                "servicediscovery:*",
                "route53:*"
            ],
            "Resource": "*"
        }
    ]
}
```

### Service-Linked Roles
ECS sẽ tự động tạo required service-linked roles. Nếu bạn gặp permission issues, có thể cần tạo manually:

```bash
# Tạo ECS service-linked role
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com
```

## Environment Validation

### 1. AWS CLI Test
Xác minh AWS CLI configuration của bạn:

```bash
# Test AWS CLI connectivity
aws sts get-caller-identity

# Expected output:
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/YourUsername"
}
```

### 2. Region Check
Đảm bảo bạn đang sử dụng AWS region đúng:

```bash
# Kiểm tra current region
aws configure get region

# List available regions
aws ec2 describe-regions --query 'Regions[].RegionName' --output table
```

### 3. VPC Limits Check
Xác minh VPC limits của bạn:

```bash
# Kiểm tra VPC limits
aws ec2 describe-account-attributes --attribute-names supported-platforms
aws ec2 describe-vpcs --query 'length(Vpcs)'
```

## Workshop Materials

### Download Workshop Files
Clone hoặc download workshop repository:

```bash
# Clone repository
git clone https://github.com/Binh2423/ECS_Advanced_Networking_Workshop.git
cd ECS_Advanced_Networking_Workshop

# Hoặc download as ZIP từ GitHub
```

### Directory Structure
```
ECS_Advanced_Networking_Workshop/
├── cloudformation/          # CloudFormation templates
├── docker/                  # Sample Docker applications
├── scripts/                 # Helper scripts
├── docs/                    # Additional documentation
└── cleanup/                 # Cleanup scripts
```

## Pre-Workshop Checklist

Trước khi tiến hành phần tiếp theo, đảm bảo bạn đã hoàn thành:

- [ ] AWS account với appropriate permissions
- [ ] AWS CLI v2 installed và configured
- [ ] Docker installed và working
- [ ] Text editor/IDE ready
- [ ] Workshop materials downloaded
- [ ] Billing alerts configured (khuyến nghị)

### Verification Commands
Chạy các commands này để xác minh setup của bạn:

```bash
# AWS CLI
aws --version
aws sts get-caller-identity

# Docker
docker --version
docker run hello-world

# Region confirmation
echo "Using AWS region: $(aws configure get region)"
```

## Troubleshooting Common Issues

### AWS CLI Issues
**Vấn đề**: `aws: command not found`
**Giải pháp**: Đảm bảo AWS CLI trong PATH của bạn hoặc reinstall

**Vấn đề**: `Unable to locate credentials`
**Giải pháp**: Chạy `aws configure` hoặc kiểm tra environment variables

### Docker Issues
**Vấn đề**: `docker: permission denied`
**Giải pháp**: Add user vào docker group (Linux) hoặc restart Docker Desktop

**Vấn đề**: `Cannot connect to Docker daemon`
**Giải pháp**: Start Docker service/application

### Permission Issues
**Vấn đề**: `AccessDenied` errors
**Giải pháp**: Kiểm tra IAM permissions hoặc liên hệ AWS administrator

## Bước tiếp theo

Khi bạn đã hoàn thành tất cả prerequisites, bạn sẵn sàng chuyển đến [Cấu hình ECS Cluster & VPC](../3-cluster-setup/) nơi chúng ta sẽ bắt đầu xây dựng networking infrastructure.

---

**Cần Hỗ trợ?**
- Kiểm tra [AWS CLI User Guide](https://docs.aws.amazon.com/cli/latest/userguide/)
- Truy cập [Docker Documentation](https://docs.docker.com/)
- Tham gia [AWS Study Group](https://www.facebook.com/groups/awsstudygroupfcj/) để được community support

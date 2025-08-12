---
title : "Yêu cầu & Thiết lập"
date : "`r Sys.Date()`"
weight : 2
chapter : false
pre : " <b> 2. </b> "
---

# Yêu cầu & Thiết lập

Trước khi bắt đầu workshop ECS Advanced Networking, hãy đảm bảo môi trường của bạn được cấu hình đúng với tất cả các công cụ và quyền cần thiết.

## Yêu cầu AWS Account

### Thiết lập Account
- **AWS Account** với billing được kích hoạt
- **Quyền truy cập Administrative** hoặc permissions tương đương cho:
  - EC2 (VPC, Security Groups, Load Balancers)
  - ECS (Clusters, Services, Tasks)
  - IAM (Roles, Policies)
  - CloudWatch (Logs, Metrics)
  - Route 53 (cho Service Discovery)

### Cân nhắc về Chi phí
- **Ước tính chi phí workshop**: $15-25
- **Free Tier eligible**: Một số services (CloudWatch Logs, limited ECS usage)
- **Billing alerts**: Khuyến nghị thiết lập trước khi bắt đầu

> **⚠️ Cảnh báo quan trọng**: Workshop này sẽ tạo AWS resources phát sinh chi phí. Hãy chắc chắn hoàn thành phần cleanup ở cuối!

### Thiết lập Billing Alerts

Trước khi bắt đầu, hãy thiết lập billing alerts:

#### Bước 1: Truy cập Billing Console
1. Đăng nhập [AWS Console](https://console.aws.amazon.com/)
2. Chuyển đến [Billing & Cost Management](https://console.aws.amazon.com/billing/)
3. Chọn "Billing preferences" từ menu bên trái

#### Bước 2: Kích hoạt Billing Alerts
```bash
# Kích hoạt billing alerts qua CLI
aws budgets create-budget \
    --account-id $(aws sts get-caller-identity --query Account --output text) \
    --budget '{
        "BudgetName": "ECS-Workshop-Budget",
        "BudgetLimit": {
            "Amount": "30",
            "Unit": "USD"
        },
        "TimeUnit": "MONTHLY",
        "BudgetType": "COST"
    }' \
    --notifications-with-subscribers '[{
        "Notification": {
            "NotificationType": "ACTUAL",
            "ComparisonOperator": "GREATER_THAN",
            "Threshold": 80
        },
        "Subscribers": [{
            "SubscriptionType": "EMAIL",
            "Address": "your-email@example.com"
        }]
    }]'
```

## Công cụ cần thiết

### 1. AWS CLI v2

#### Cài đặt AWS CLI v2

**Linux/macOS:**
```bash
# Download và cài đặt
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Xác minh cài đặt
aws --version
```

**Windows:**
```powershell
# Download từ: https://awscli.amazonaws.com/AWSCLIV2.msi
# Hoặc sử dụng chocolatey
choco install awscli
```

#### Cấu hình AWS CLI

```bash
# Cấu hình credentials
aws configure

# Nhập thông tin khi được yêu cầu:
# AWS Access Key ID: [Nhập Access Key của bạn]
# AWS Secret Access Key: [Nhập Secret Key của bạn]
# Default region name: us-east-1 (khuyến nghị cho workshop)
# Default output format: json
```

#### Xác minh cấu hình

```bash
# Test kết nối
aws sts get-caller-identity

# Kết quả mong đợi:
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/YourUsername"
}
```

### 2. Docker Desktop

#### Cài đặt Docker

**Windows/macOS**: 
- Download [Docker Desktop](https://www.docker.com/products/docker-desktop)
- Chạy installer và làm theo hướng dẫn

**Linux (Ubuntu/Debian):**
```bash
# Cập nhật package index
sudo apt-get update

# Cài đặt packages cần thiết
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Thêm Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Thiết lập repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Cài đặt Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Thêm user vào docker group
sudo usermod -aG docker $USER
```

#### Xác minh Docker

```bash
# Kiểm tra version
docker --version

# Test với hello-world container
docker run hello-world

# Kết quả mong đợi: "Hello from Docker!" message
```

### 3. Text Editor/IDE

**Khuyến nghị sử dụng:**

#### Visual Studio Code với AWS Extensions
```bash
# Cài đặt VS Code extensions hữu ích
code --install-extension amazonwebservices.aws-toolkit-vscode
code --install-extension ms-vscode.vscode-json
code --install-extension redhat.vscode-yaml
```

#### AWS Cloud9 (Browser-based)
- Truy cập [AWS Cloud9](https://console.aws.amazon.com/cloud9/)
- Tạo new environment
- Chọn instance type t3.small
- Sử dụng Amazon Linux 2

### 4. Git (Tùy chọn)

```bash
# Cài đặt Git
# Ubuntu/Debian
sudo apt-get install git

# macOS
brew install git

# Windows
# Download từ: https://git-scm.com/download/win

# Xác minh
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
                "iam:GetRole",
                "iam:ListRoles",
                "logs:*",
                "servicediscovery:*",
                "route53:*",
                "cloudwatch:*",
                "application-autoscaling:*"
            ],
            "Resource": "*"
        }
    ]
}
```

### Tạo IAM User cho Workshop

#### Bước 1: Tạo IAM User qua Console
1. Truy cập [IAM Console](https://console.aws.amazon.com/iam/)
2. Chọn "Users" → "Add users"
3. Nhập username: `ecs-workshop-user`
4. Chọn "Programmatic access"

#### Bước 2: Attach Permissions
```bash
# Tạo custom policy cho workshop
aws iam create-policy \
    --policy-name ECSWorkshopPolicy \
    --policy-document file://workshop-policy.json

# Attach policy vào user
aws iam attach-user-policy \
    --user-name ecs-workshop-user \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/ECSWorkshopPolicy
```

### Service-Linked Roles

ECS sẽ tự động tạo required service-linked roles. Nếu gặp permission issues:

```bash
# Tạo ECS service-linked role
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com

# Tạo Application Auto Scaling service-linked role
aws iam create-service-linked-role --aws-service-name application-autoscaling.amazonaws.com
```

## Environment Validation

### 1. AWS CLI Test

```bash
# Test AWS CLI connectivity
aws sts get-caller-identity

# Kiểm tra permissions
aws iam get-user

# List available regions
aws ec2 describe-regions --query 'Regions[].RegionName' --output table
```

### 2. Region Check

```bash
# Kiểm tra current region
aws configure get region

# Đặt region nếu chưa có
aws configure set region us-east-1

# Xác minh region
echo "Đang sử dụng AWS region: $(aws configure get region)"
```

### 3. VPC Limits Check

```bash
# Kiểm tra VPC limits
aws ec2 describe-account-attributes --attribute-names supported-platforms

# Kiểm tra số lượng VPCs hiện tại
aws ec2 describe-vpcs --query 'length(Vpcs)'

# Kiểm tra ECS limits
aws service-quotas get-service-quota \
    --service-code ecs \
    --quota-code L-21C621EB
```

## Workshop Materials

### Download Workshop Files

```bash
# Clone repository
git clone https://github.com/Binh2423/ECS_Advanced_Networking_Workshop.git
cd ECS_Advanced_Networking_Workshop

# Hoặc download ZIP từ GitHub
curl -L https://github.com/Binh2423/ECS_Advanced_Networking_Workshop/archive/main.zip -o workshop.zip
unzip workshop.zip
```

### Directory Structure
```
ECS_Advanced_Networking_Workshop/
├── content/                 # Workshop content
├── static/                  # Static assets
├── scripts/                 # Helper scripts
├── templates/               # CloudFormation templates
└── examples/                # Example configurations
```

### Tạo Working Directory

```bash
# Tạo thư mục làm việc
mkdir -p ~/ecs-workshop
cd ~/ecs-workshop

# Tạo các thư mục con
mkdir -p {scripts,configs,logs,templates}

# Set working directory
export WORKSHOP_DIR=$(pwd)
echo "export WORKSHOP_DIR=$WORKSHOP_DIR" >> ~/.bashrc
```

## Pre-Workshop Checklist

Trước khi tiến hành phần tiếp theo, đảm bảo bạn đã hoàn thành:

### Checklist cơ bản
- [ ] AWS account với appropriate permissions
- [ ] AWS CLI v2 installed và configured
- [ ] Docker installed và working
- [ ] Text editor/IDE ready
- [ ] Workshop materials downloaded
- [ ] Working directory created

### Checklist nâng cao
- [ ] Billing alerts configured
- [ ] IAM user created (nếu cần)
- [ ] Service-linked roles verified
- [ ] VPC limits checked
- [ ] Region confirmed (us-east-1)

### Verification Commands

Chạy script verification tổng hợp:

```bash
#!/bin/bash
echo "=== ECS Workshop Environment Verification ==="

# AWS CLI
echo "1. AWS CLI Version:"
aws --version

echo "2. AWS Identity:"
aws sts get-caller-identity

echo "3. AWS Region:"
echo "Current region: $(aws configure get region)"

# Docker
echo "4. Docker Version:"
docker --version

echo "5. Docker Test:"
docker run --rm hello-world > /dev/null 2>&1 && echo "✅ Docker working" || echo "❌ Docker not working"

# Permissions
echo "6. ECS Permissions:"
aws ecs list-clusters > /dev/null 2>&1 && echo "✅ ECS access OK" || echo "❌ ECS access denied"

echo "7. EC2 Permissions:"
aws ec2 describe-vpcs > /dev/null 2>&1 && echo "✅ EC2 access OK" || echo "❌ EC2 access denied"

echo "=== Verification Complete ==="
```

## Tương tác với AWS Console

### Console Navigation cho Workshop

#### 1. **AWS Management Console**
- URL: [https://console.aws.amazon.com/](https://console.aws.amazon.com/)
- Bookmark các services chính:
  - [ECS Console](https://console.aws.amazon.com/ecs/)
  - [VPC Console](https://console.aws.amazon.com/vpc/)
  - [EC2 Console](https://console.aws.amazon.com/ec2/)
  - [CloudWatch Console](https://console.aws.amazon.com/cloudwatch/)

#### 2. **Console Tips**
- Sử dụng search bar để tìm services nhanh
- Pin frequently used services
- Sử dụng multiple tabs cho different services
- Enable console notifications

### AWS CLI Profile Setup

```bash
# Tạo profile riêng cho workshop
aws configure --profile ecs-workshop

# Sử dụng profile
export AWS_PROFILE=ecs-workshop

# Hoặc specify trong từng command
aws --profile ecs-workshop sts get-caller-identity
```

## Troubleshooting Common Issues

### AWS CLI Issues

#### Vấn đề: `aws: command not found`
**Giải pháp:**
```bash
# Kiểm tra PATH
echo $PATH

# Thêm AWS CLI vào PATH
export PATH=$PATH:/usr/local/bin

# Hoặc tạo symlink
sudo ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws
```

#### Vấn đề: `Unable to locate credentials`
**Giải pháp:**
```bash
# Kiểm tra credentials file
cat ~/.aws/credentials

# Hoặc set environment variables
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_DEFAULT_REGION=us-east-1
```

### Docker Issues

#### Vấn đề: `docker: permission denied`
**Giải pháp (Linux):**
```bash
# Thêm user vào docker group
sudo usermod -aG docker $USER

# Logout và login lại, hoặc
newgrp docker

# Test
docker run hello-world
```

#### Vấn đề: `Cannot connect to Docker daemon`
**Giải pháp:**
```bash
# Start Docker service (Linux)
sudo systemctl start docker
sudo systemctl enable docker

# Hoặc restart Docker Desktop (Windows/macOS)
```

### Permission Issues

#### Vấn đề: `AccessDenied` errors
**Giải pháp:**
```bash
# Kiểm tra current user permissions
aws iam get-user

# List attached policies
aws iam list-attached-user-policies --user-name $(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2)

# Kiểm tra specific permission
aws iam simulate-principal-policy \
    --policy-source-arn $(aws sts get-caller-identity --query 'Arn' --output text) \
    --action-names ecs:CreateCluster \
    --resource-arns "*"
```

## Bước tiếp theo

Khi bạn đã hoàn thành tất cả prerequisites và verification, bạn sẵn sàng chuyển đến [Cấu hình ECS Cluster & VPC](../3-cluster-setup/) nơi chúng ta sẽ bắt đầu xây dựng networking infrastructure.

### Quick Start Commands

```bash
# Tạo alias hữu ích cho workshop
echo 'alias ll="ls -la"' >> ~/.bashrc
echo 'alias awsid="aws sts get-caller-identity"' >> ~/.bashrc
echo 'alias awsregion="aws configure get region"' >> ~/.bashrc

# Source bashrc
source ~/.bashrc

# Test quick commands
awsid
awsregion
```

---

**Cần hỗ trợ?**
- Kiểm tra [AWS CLI User Guide](https://docs.aws.amazon.com/cli/latest/userguide/)
- Truy cập [Docker Documentation](https://docs.docker.com/)
- Tham gia [AWS Study Group](https://www.facebook.com/groups/awsstudygroupfcj/) để được community support
- Mở issue trên [GitHub Repository](https://github.com/Binh2423/ECS_Advanced_Networking_Workshop)

**Sẵn sàng cho bước tiếp theo? Hãy bắt đầu xây dựng infrastructure!** 🚀

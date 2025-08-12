---
title : "Chuẩn bị môi trường"
date : "`r Sys.Date()`"
weight : 2
chapter : false
pre : " <b> 2. </b> "
---

# Chuẩn bị môi trường làm việc

## Bước 1: Kiểm tra AWS Account

### 1.1 Đăng nhập AWS Console

1. Truy cập [AWS Console](https://console.aws.amazon.com/)
2. Đăng nhập với account của bạn
3. Chọn region **us-east-1** (N. Virginia)

![Đăng nhập AWS Console](/images/aws-console-login.png)

### 1.2 Kiểm tra quyền

Vào [IAM Console](https://console.aws.amazon.com/iam/) và kiểm tra:
- User có quyền **AdministratorAccess** hoặc
- Có đủ quyền cho ECS, VPC, EC2, IAM

![IAM Console](/images/iam-roles-ecs.png)

### 1.3 Thiết lập Billing Alert

**Tại sao cần?** Để tránh chi phí bất ngờ

**Cách làm:**
1. Vào [Billing Console](https://console.aws.amazon.com/billing/)
2. Chọn "Billing preferences"
3. Bật "Receive Billing Alerts"
4. Tạo alert cho $30

![Billing Alert Setup](/images/billing-alert-setup.png)

## Bước 2: Cài đặt AWS CLI

### 2.1 Download và cài đặt

**Windows:**
```powershell
# Download từ: https://awscli.amazonaws.com/AWSCLIV2.msi
# Chạy file .msi và làm theo hướng dẫn
```

**macOS:**
```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### 2.2 Xác minh cài đặt

```bash
aws --version
# Kết quả mong đợi: aws-cli/2.x.x Python/3.x.x
```

### 2.3 Cấu hình AWS CLI

```bash
aws configure
```

Nhập thông tin:
```
AWS Access Key ID: [Nhập access key]
AWS Secret Access Key: [Nhập secret key]  
Default region name: us-east-1
Default output format: json
```

### 2.4 Test kết nối

```bash
aws sts get-caller-identity
```

Kết quả mong đợi:
```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012", 
    "Arn": "arn:aws:iam::123456789012:user/YourUsername"
}
```

## Bước 3: Cài đặt Docker

### 3.1 Cài đặt Docker Desktop

**Windows/macOS:**
1. Download [Docker Desktop](https://www.docker.com/products/docker-desktop)
2. Chạy installer
3. Restart máy tính

**Linux (Ubuntu):**
```bash
# Cập nhật packages
sudo apt update

# Cài đặt Docker
sudo apt install docker.io

# Thêm user vào docker group
sudo usermod -aG docker $USER

# Logout và login lại
```

### 3.2 Xác minh Docker

```bash
docker --version
# Kết quả: Docker version 20.x.x

docker run hello-world
# Kết quả: "Hello from Docker!" message
```

## Bước 4: Chuẩn bị Text Editor

### 4.1 Cài đặt VS Code (khuyến nghị)

1. Download [VS Code](https://code.visualstudio.com/)
2. Cài đặt extensions hữu ích:
   - AWS Toolkit
   - YAML
   - JSON

### 4.2 Hoặc sử dụng AWS Cloud9

1. Vào [Cloud9 Console](https://console.aws.amazon.com/cloud9/)
2. Tạo new environment
3. Chọn instance type: t3.small
4. Sử dụng Amazon Linux 2

![Cloud9 Environment](/images/cloud9-environment.png)

## Bước 5: Tạo thư mục làm việc

```bash
# Tạo thư mục workshop
mkdir ~/ecs-workshop
cd ~/ecs-workshop

# Tạo các thư mục con
mkdir -p {scripts,configs,logs}

# Tạo file environment
touch workshop-env.sh
```

## Bước 6: Verification Script

Tạo script để kiểm tra tất cả:

```bash
cat > check-prerequisites.sh << 'EOF'
#!/bin/bash
echo "=== Kiểm tra Prerequisites ==="

# AWS CLI
echo "1. AWS CLI:"
if command -v aws &> /dev/null; then
    aws --version
    echo "✅ AWS CLI OK"
else
    echo "❌ AWS CLI chưa cài đặt"
fi

# AWS Credentials
echo "2. AWS Credentials:"
if aws sts get-caller-identity &> /dev/null; then
    echo "✅ AWS credentials OK"
else
    echo "❌ AWS credentials chưa cấu hình"
fi

# Docker
echo "3. Docker:"
if command -v docker &> /dev/null; then
    docker --version
    echo "✅ Docker OK"
else
    echo "❌ Docker chưa cài đặt"
fi

# Region
echo "4. AWS Region:"
REGION=$(aws configure get region)
echo "Current region: $REGION"
if [ "$REGION" = "us-east-1" ]; then
    echo "✅ Region OK"
else
    echo "⚠️  Khuyến nghị sử dụng us-east-1"
fi

echo "=== Kiểm tra hoàn tất ==="
EOF

chmod +x check-prerequisites.sh
./check-prerequisites.sh
```

## Bước 7: Tạo IAM User riêng (Tùy chọn)

Nếu bạn muốn tạo user riêng cho workshop:

### 7.1 Tạo User qua Console

1. Vào [IAM Console](https://console.aws.amazon.com/iam/)
2. Chọn "Users" → "Add users"
3. Username: `ecs-workshop-user`
4. Access type: "Programmatic access"

![Tạo IAM User](/images/iam-create-user.png)

### 7.2 Gán quyền

1. Attach existing policies directly
2. Chọn: `AdministratorAccess` (cho workshop)
3. Hoặc tạo custom policy với quyền cần thiết

![Gán quyền IAM](/images/iam-attach-policies.png)

### 7.3 Lưu credentials

1. Download .csv file
2. Hoặc copy Access Key ID và Secret Access Key
3. Cấu hình AWS CLI với credentials mới

## Troubleshooting

### Vấn đề thường gặp:

**AWS CLI không tìm thấy:**
```bash
# Kiểm tra PATH
echo $PATH
# Thêm AWS CLI vào PATH nếu cần
export PATH=$PATH:/usr/local/bin
```

**Docker permission denied (Linux):**
```bash
# Thêm user vào docker group
sudo usermod -aG docker $USER
# Logout và login lại
```

**AWS credentials không hoạt động:**
```bash
# Kiểm tra file credentials
cat ~/.aws/credentials
# Hoặc set environment variables
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
```

## Checklist hoàn thành

- [ ] AWS Account có quyền admin
- [ ] AWS CLI cài đặt và cấu hình
- [ ] Docker cài đặt và hoạt động
- [ ] Text editor sẵn sàng
- [ ] Thư mục làm việc đã tạo
- [ ] Verification script chạy thành công
- [ ] Billing alert đã thiết lập

## Bước tiếp theo

Khi tất cả đã sẵn sàng, chuyển đến [Xây dựng VPC và ECS Cluster](../3-cluster-setup/) để bắt đầu xây dựng infrastructure.

---

**💡 Tips:**
- Bookmark các AWS Console thường dùng
- Tạo alias cho các commands thường dùng
- Backup AWS credentials ở nơi an toàn

**🆘 Cần hỗ trợ?** Hỏi trong [AWS Study Group](https://www.facebook.com/groups/awsstudygroupfcj/)

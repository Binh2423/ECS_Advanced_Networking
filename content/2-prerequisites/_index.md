---
title : "Chuẩn bị môi trường"
date : "2024-08-13"
weight : 2
chapter : false
pre : " <b> 2. </b> "
---

# Chuẩn bị môi trường

## Kiểm tra yêu cầu

{{< alert type="warning" title="Chi phí AWS" >}}
💰 Workshop này sử dụng AWS resources có tính phí  
📊 **Ước tính chi phí:** $5-10 USD cho toàn bộ workshop  
⏰ **Thời gian:** Nhớ cleanup resources sau khi hoàn thành  
{{< /alert >}}

## Bước 1: Đăng nhập AWS Console

### 1.1 Truy cập AWS Console

{{< console-screenshot src="{{ "images/aws-console-login.png" | absURL }}" alt="AWS Console Login" caption="Đăng nhập vào AWS Console với tài khoản có quyền Administrator" service="AWS Console" >}}

**Các bước thực hiện:**
1. Truy cập: https://console.aws.amazon.com
2. Đăng nhập với IAM user hoặc root account
3. Đảm bảo có quyền Administrator

### 1.2 Chọn Region

{{< console-screenshot src="{{ "images/region-selection.png" | absURL }}" alt="Region Selection" caption="Chọn region us-east-1 (N. Virginia) để thực hiện workshop" service="AWS Console" >}}

**Khuyến nghị region:**
- **us-east-1** (N. Virginia) - Có đầy đủ services
- **us-west-2** (Oregon) - Alternative option
- **ap-southeast-1** (Singapore) - Cho khu vực châu Á

## Bước 2: Chuẩn bị AWS CLI

### 2.1 Kiểm tra AWS CLI

Mở terminal và kiểm tra:

```bash
aws --version
```

{{< alert type="success" title="Kết quả mong đợi" >}}
```
aws-cli/2.x.x Python/3.x.x
```
{{< /alert >}}

### 2.2 Cấu hình AWS CLI

```bash
aws configure
```

**Nhập thông tin:**
- **AWS Access Key ID:** [Your Access Key]
- **AWS Secret Access Key:** [Your Secret Key]
- **Default region name:** us-east-1
- **Default output format:** json

### 2.3 Test kết nối

```bash
aws sts get-caller-identity
```

{{< alert type="success" title="Kết quả thành công" >}}
```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/workshop-user"
}
```
{{< /alert >}}

## Bước 3: Tạo thư mục làm việc

### 3.1 Tạo workspace

```bash
mkdir ~/ecs-workshop
cd ~/ecs-workshop
```

### 3.2 Tạo file environment

```bash
cat > workshop-env.sh << 'EOF'
#!/bin/bash
export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""
export WORKSHOP_NAME="ecs-advanced-networking"
echo "✅ Workshop environment loaded"
EOF

chmod +x workshop-env.sh
source workshop-env.sh
```

## Bước 4: Kiểm tra quyền IAM

### 4.1 Test quyền cần thiết

```bash
# Test EC2 permissions
aws ec2 describe-vpcs --max-items 1

# Test ECS permissions  
aws ecs list-clusters --max-items 1

# Test ELB permissions
aws elbv2 describe-load-balancers --max-items 1
```

{{< alert type="info" title="Lưu ý" >}}
Nếu gặp lỗi permission, hãy đảm bảo IAM user có policy **AdministratorAccess** hoặc các quyền cụ thể cho EC2, ECS, ELB, IAM.
{{< /alert >}}

## Bước 5: Chuẩn bị hoàn tất

{{< alert type="success" title="Checklist hoàn thành" >}}
✅ **AWS Console** - Đã đăng nhập thành công  
✅ **Region** - Đã chọn us-east-1  
✅ **AWS CLI** - Đã cấu hình và test  
✅ **Workspace** - Đã tạo thư mục làm việc  
✅ **Permissions** - Đã kiểm tra quyền IAM  
{{< /alert >}}

## Sẵn sàng bắt đầu!

Môi trường đã được chuẩn bị xong. Bây giờ chúng ta sẽ bắt đầu xây dựng VPC infrastructure!

{{< button href="../3-cluster-setup/" >}}Tiếp theo: Thiết lập VPC →{{< /button >}}

---
title : "Tạo VPC"
date : "`r Sys.Date()`"
weight : 1
chapter : false
pre : " <b> 3.1 </b> "
---

# Tạo Virtual Private Cloud (VPC)

## Mục tiêu

Trong bước này, chúng ta sẽ tạo VPC chính với CIDR block 10.0.0.0/16 để chứa tất cả resources của workshop.

## Phương pháp 1: Sử dụng AWS Console

### Bước 1: Truy cập VPC Console

{{< console-interaction >}}
**📍 Vị trí:** AWS Management Console → Services → VPC

**Hành động:**
1. Đăng nhập vào AWS Console
2. Tìm kiếm "VPC" trong thanh tìm kiếm
3. Click vào **VPC** service

**📸 Screenshot cần chụp:**
- [ ] AWS Console homepage với VPC service được highlight
- [ ] VPC Dashboard với button "Create VPC"
{{< /console-interaction >}}

### Bước 2: Tạo VPC mới

{{< console-interaction >}}
**📍 Vị trí:** VPC Console → Create VPC

**Cấu hình:**
- **Name tag:** `ECS-Workshop-VPC`
- **IPv4 CIDR block:** `10.0.0.0/16`
- **IPv6 CIDR block:** No IPv6 CIDR block
- **Tenancy:** Default

**📸 Screenshot cần chụp:**
- [ ] Create VPC form với các thông tin đã điền
- [ ] VPC được tạo thành công trong VPC list
{{< /console-interaction >}}

## Phương pháp 2: Sử dụng AWS CLI

### Chuẩn bị environment

```bash
# Tạo file environment để lưu trữ variables
touch workshop-env.sh
chmod +x workshop-env.sh

# Set region (thay đổi theo region bạn muốn sử dụng)
export AWS_DEFAULT_REGION=ap-southeast-1
echo "export AWS_DEFAULT_REGION=ap-southeast-1" >> workshop-env.sh
```

### Tạo VPC

```bash
# Load environment variables
source workshop-env.sh

# Tạo VPC với CIDR block 10.0.0.0/16
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=ECS-Workshop-VPC},{Key=Project,Value=ECS-Workshop}]' \
    --query 'Vpc.VpcId' \
    --output text)

# Kiểm tra kết quả
if [ -n "$VPC_ID" ]; then
    echo "✅ VPC created successfully!"
    echo "📋 VPC ID: $VPC_ID"
    
    # Lưu VPC ID vào environment file
    echo "export VPC_ID=$VPC_ID" >> workshop-env.sh
else
    echo "❌ Failed to create VPC"
    exit 1
fi
```

### Enable DNS support

```bash
# Enable DNS hostnames và DNS resolution
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support

echo "✅ DNS support enabled for VPC"
```

## Xác minh kết quả

### Kiểm tra VPC đã tạo

```bash
# Xem thông tin VPC vừa tạo
aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].[VpcId,CidrBlock,State,Tags[?Key==`Name`].Value|[0]]' --output table

# Kết quả mong đợi:
# |  DescribeVpcs  |
# |----------------|
# |  vpc-xxxxxxxxx |
# |  10.0.0.0/16   |
# |  available     |
# |  ECS-Workshop-VPC |
```

### Kiểm tra trong Console

{{< console-interaction >}}
**📍 Vị trí:** VPC Console → Your VPCs

**Xác minh:**
- [ ] VPC `ECS-Workshop-VPC` xuất hiện trong danh sách
- [ ] State: `Available`
- [ ] CIDR: `10.0.0.0/16`
- [ ] DNS resolution: `Enabled`
- [ ] DNS hostnames: `Enabled`

**📸 Screenshot cần chụp:**
- [ ] VPC details page showing all configurations
{{< /console-interaction >}}

## Troubleshooting

### Lỗi thường gặp

{{< alert type="warning" title="Permission Denied" >}}
**Lỗi:** `An error occurred (UnauthorizedOperation) when calling the CreateVpc operation`

**Giải pháp:**
- Kiểm tra IAM permissions
- Đảm bảo có quyền `ec2:CreateVpc`, `ec2:CreateTags`
{{< /alert >}}

{{< alert type="warning" title="CIDR Conflict" >}}
**Lỗi:** `The CIDR '10.0.0.0/16' conflicts with another subnet`

**Giải pháp:**
- Sử dụng CIDR block khác như `172.16.0.0/16` hoặc `192.168.0.0/16`
- Cập nhật tất cả CIDR blocks trong workshop tương ứng
{{< /alert >}}

## Tóm tắt

🎉 **Hoàn thành!** Bạn đã tạo thành công:

✅ VPC với CIDR block 10.0.0.0/16  
✅ DNS resolution và DNS hostnames enabled  
✅ Environment variable `VPC_ID` đã được lưu  

## Bước tiếp theo

VPC đã sẵn sàng! Tiếp theo chúng ta sẽ tạo các subnets.

{{< button href="../02-create-subnets/" >}}Tiếp theo: Tạo Subnets →{{< /button >}}

---

{{< alert type="info" title="💡 Tip" >}}
**Lưu ý về chi phí:** VPC không tính phí, nhưng các resources bên trong như NAT Gateways sẽ có chi phí. Hãy nhớ cleanup sau khi hoàn thành workshop!
{{< /alert >}}

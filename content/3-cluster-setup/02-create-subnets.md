---
title : "Tạo Subnets"
date : "2024-08-13"
weight : 2
chapter : false
pre : " <b> 3.2 </b> "
---

# Tạo Subnets

## Mục tiêu

Tạo 4 subnets trong VPC:
- 2 **Public subnets** (cho ALB và NAT Gateways)
- 2 **Private subnets** (cho ECS tasks)

Mỗi loại subnet sẽ được đặt trong 2 Availability Zones khác nhau để đảm bảo high availability.

## Kiến trúc Subnets

![Subnets Architecture](images/3-cluster-setup/02-subnets/subnets-architecture.png)

## Phương pháp 1: Sử dụng AWS Console

### Bước 1: Tạo Public Subnet 1

![Create Subnet Form](images/3-cluster-setup/02-subnets/02-create-subnet-form-public1.png)

**Cấu hình:**
- **VPC ID:** Chọn `ECS-Workshop-VPC`
- **Subnet name:** `Public-Subnet-1`
- **Availability Zone:** Chọn AZ đầu tiên (ví dụ: ap-southeast-1a)
- **IPv4 CIDR block:** `10.0.1.0/24`

### Bước 2: Tạo các subnets còn lại

Lặp lại quá trình tương tự cho:

| Subnet Name | AZ | CIDR Block | Type |
|-------------|----|-----------|----- |
| Public-Subnet-2 | AZ thứ 2 | 10.0.2.0/24 | Public |
| Private-Subnet-1 | AZ đầu tiên | 10.0.3.0/24 | Private |
| Private-Subnet-2 | AZ thứ 2 | 10.0.4.0/24 | Private |

### Bước 3: Xác minh kết quả

![Subnets List Complete](images/3-cluster-setup/02-subnets/03-subnets-list-complete.png)

Tất cả 4 subnets sẽ xuất hiện trong danh sách với đúng CIDR blocks và AZs.

![Public Subnet Details](images/3-cluster-setup/02-subnets/04-subnet-details-public.png)

Public subnets sẽ có "Auto-assign public IPv4 address" = Yes.

![Private Subnet Details](images/3-cluster-setup/02-subnets/05-subnet-details-private.png)

Private subnets sẽ có "Auto-assign public IPv4 address" = No.

## Phương pháp 2: Sử dụng AWS CLI

### Chuẩn bị

```bash
# Load environment variables
source workshop-env.sh

# Lấy danh sách Availability Zones
AZ_1=$(aws ec2 describe-availability-zones \
    --query 'AvailabilityZones[0].ZoneName' \
    --output text)

AZ_2=$(aws ec2 describe-availability-zones \
    --query 'AvailabilityZones[1].ZoneName' \
    --output text)

echo "🌍 Availability Zones:"
echo "   AZ 1: $AZ_1"
echo "   AZ 2: $AZ_2"

# Lưu vào environment file
echo "export AZ_1=$AZ_1" >> workshop-env.sh
echo "export AZ_2=$AZ_2" >> workshop-env.sh
```

### Tạo Public Subnets

```bash
echo "🏗️ Creating Public Subnets..."

# Public Subnet 1 (AZ 1)
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone $AZ_1 \
    --tag-specifications 'ResourceType=subnet,Tags=[
        {Key=Name,Value=Public-Subnet-1},
        {Key=Type,Value=Public},
        {Key=Project,Value=ECS-Workshop}
    ]' \
    --query 'Subnet.SubnetId' \
    --output text)

# Public Subnet 2 (AZ 2)
PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone $AZ_2 \
    --tag-specifications 'ResourceType=subnet,Tags=[
        {Key=Name,Value=Public-Subnet-2},
        {Key=Type,Value=Public},
        {Key=Project,Value=ECS-Workshop}
    ]' \
    --query 'Subnet.SubnetId' \
    --output text)

# Enable auto-assign public IP cho public subnets
aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_1 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_2 --map-public-ip-on-launch

echo "✅ Public Subnets created:"
echo "   Public Subnet 1: $PUBLIC_SUBNET_1 ($AZ_1)"
echo "   Public Subnet 2: $PUBLIC_SUBNET_2 ($AZ_2)"
```

### Tạo Private Subnets

```bash
echo "🏗️ Creating Private Subnets..."

# Private Subnet 1 (AZ 1)
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.3.0/24 \
    --availability-zone $AZ_1 \
    --tag-specifications 'ResourceType=subnet,Tags=[
        {Key=Name,Value=Private-Subnet-1},
        {Key=Type,Value=Private},
        {Key=Project,Value=ECS-Workshop}
    ]' \
    --query 'Subnet.SubnetId' \
    --output text)

# Private Subnet 2 (AZ 2)
PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.4.0/24 \
    --availability-zone $AZ_2 \
    --tag-specifications 'ResourceType=subnet,Tags=[
        {Key=Name,Value=Private-Subnet-2},
        {Key=Type,Value=Private},
        {Key=Project,Value=ECS-Workshop}
    ]' \
    --query 'Subnet.SubnetId' \
    --output text)

echo "✅ Private Subnets created:"
echo "   Private Subnet 1: $PRIVATE_SUBNET_1 ($AZ_1)"
echo "   Private Subnet 2: $PRIVATE_SUBNET_2 ($AZ_2)"
```

### Lưu Subnet IDs

```bash
# Lưu tất cả subnet IDs vào environment file
cat >> workshop-env.sh << EOF
export PUBLIC_SUBNET_1=$PUBLIC_SUBNET_1
export PUBLIC_SUBNET_2=$PUBLIC_SUBNET_2
export PRIVATE_SUBNET_1=$PRIVATE_SUBNET_1
export PRIVATE_SUBNET_2=$PRIVATE_SUBNET_2
EOF

echo "💾 Subnet IDs saved to workshop-env.sh"
```

## Xác minh kết quả

### Kiểm tra bằng CLI

```bash
# Hiển thị tất cả subnets trong VPC
echo "📋 Subnet Summary:"
echo "=================="

aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[*].[
        Tags[?Key==`Name`].Value|[0],
        SubnetId,
        CidrBlock,
        AvailabilityZone,
        MapPublicIpOnLaunch
    ]' \
    --output table
```

## Troubleshooting

### Lỗi thường gặp

{{< alert type="warning" title="CIDR Overlap" >}}
**Lỗi:** `InvalidSubnet.Conflict: The CIDR '10.0.1.0/24' conflicts with another subnet`

**Giải pháp:**
- Kiểm tra các subnet đã tồn tại trong VPC
- Sử dụng CIDR blocks khác nhau
- Xóa subnet cũ nếu không cần thiết
{{< /alert >}}

{{< alert type="warning" title="AZ Not Available" >}}
**Lỗi:** `InvalidParameterValue: Value (us-east-1e) for parameter availabilityZone is invalid`

**Giải pháp:**
- Kiểm tra AZ available trong region: `aws ec2 describe-availability-zones`
- Sử dụng AZ khác
{{< /alert >}}

## Tóm tắt

🎉 **Hoàn thành!** Bạn đã tạo thành công:

✅ 2 Public subnets với auto-assign public IP  
✅ 2 Private subnets  
✅ Subnets được phân bố trên 2 AZs  
✅ Environment variables đã được lưu  

## Bước tiếp theo

Subnets đã sẵn sàng! Tiếp theo chúng ta sẽ tạo Internet Gateway.

{{< button href="../03-internet-gateway/" >}}Tiếp theo: Internet Gateway →{{< /button >}}

---

{{< alert type="info" title="💡 Best Practice" >}}
**High Availability:** Việc sử dụng 2 AZs đảm bảo ứng dụng của bạn có thể hoạt động ngay cả khi 1 AZ gặp sự cố.
{{< /alert >}}

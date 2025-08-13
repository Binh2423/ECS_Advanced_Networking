---
title : "Tạo Subnets"
date : "`r Sys.Date()`"
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

{{< mermaid >}}
graph TB
    subgraph "VPC: 10.0.0.0/16"
        subgraph "AZ-1"
            PUB1[Public Subnet 1<br/>10.0.1.0/24]
            PRIV1[Private Subnet 1<br/>10.0.3.0/24]
        end
        
        subgraph "AZ-2"
            PUB2[Public Subnet 2<br/>10.0.2.0/24]
            PRIV2[Private Subnet 2<br/>10.0.4.0/24]
        end
    end
{{< /mermaid >}}

## Phương pháp 1: Sử dụng AWS Console

### Bước 1: Truy cập Subnets Console

{{< console-interaction >}}
**📍 Vị trí:** VPC Console → Subnets

**Hành động:**
1. Trong VPC Console, click vào **Subnets** ở menu bên trái
2. Click **Create subnet**

**📸 Screenshot cần chụp:**
- [ ] Subnets dashboard
- [ ] Create subnet button
{{< /console-interaction >}}

### Bước 2: Tạo Public Subnet 1

{{< console-interaction >}}
**📍 Vị trí:** Create subnet form

**Cấu hình:**
- **VPC ID:** Chọn `ECS-Workshop-VPC`
- **Subnet name:** `Public-Subnet-1`
- **Availability Zone:** Chọn AZ đầu tiên (ví dụ: ap-southeast-1a)
- **IPv4 CIDR block:** `10.0.1.0/24`

**📸 Screenshot cần chụp:**
- [ ] Create subnet form với thông tin Public Subnet 1
{{< /console-interaction >}}

### Bước 3: Tạo các subnets còn lại

Lặp lại quá trình tương tự cho:

| Subnet Name | AZ | CIDR Block | Type |
|-------------|----|-----------|----- |
| Public-Subnet-2 | AZ thứ 2 | 10.0.2.0/24 | Public |
| Private-Subnet-1 | AZ đầu tiên | 10.0.3.0/24 | Private |
| Private-Subnet-2 | AZ thứ 2 | 10.0.4.0/24 | Private |

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

### Kiểm tra trong Console

{{< console-interaction >}}
**📍 Vị trí:** VPC Console → Subnets

**Xác minh:**
- [ ] 4 subnets xuất hiện trong danh sách
- [ ] Public subnets có "Auto-assign public IPv4 address" = Yes
- [ ] Private subnets có "Auto-assign public IPv4 address" = No
- [ ] Mỗi subnet ở AZ khác nhau

**📸 Screenshot cần chụp:**
- [ ] Subnets list showing all 4 subnets
- [ ] Subnet details cho mỗi subnet
{{< /console-interaction >}}

## Kiểm tra kết nối

### Test subnet connectivity

```bash
# Tạo script kiểm tra subnet
cat > check-subnets.sh << 'EOF'
#!/bin/bash
source workshop-env.sh

echo "🔍 Checking subnet configurations..."

# Function to check subnet
check_subnet() {
    local subnet_id=$1
    local subnet_name=$2
    
    echo "Checking $subnet_name ($subnet_id):"
    
    # Get subnet info
    subnet_info=$(aws ec2 describe-subnets --subnet-ids $subnet_id --query 'Subnets[0]')
    
    cidr=$(echo $subnet_info | jq -r '.CidrBlock')
    az=$(echo $subnet_info | jq -r '.AvailabilityZone')
    auto_ip=$(echo $subnet_info | jq -r '.MapPublicIpOnLaunch')
    
    echo "  ✓ CIDR: $cidr"
    echo "  ✓ AZ: $az"
    echo "  ✓ Auto-assign IP: $auto_ip"
    echo ""
}

# Check all subnets
check_subnet $PUBLIC_SUBNET_1 "Public-Subnet-1"
check_subnet $PUBLIC_SUBNET_2 "Public-Subnet-2"
check_subnet $PRIVATE_SUBNET_1 "Private-Subnet-1"
check_subnet $PRIVATE_SUBNET_2 "Private-Subnet-2"

echo "✅ All subnets configured correctly!"
EOF

chmod +x check-subnets.sh
./check-subnets.sh
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

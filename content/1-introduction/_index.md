---
title : "Thiết lập VPC và Networking"
date : "`r Sys.Date()`"
weight : 1
chapter : false
pre : " <b> 1. </b> "
---

## VPC là gì?

VPC (Virtual Private Cloud) giống như xây một khu nhà riêng trong thành phố AWS. Bạn có thể kiểm soát ai vào, ai ra, và các phòng nào kết nối với nhau.

{{< alert type="info" title="Tại sao cần VPC?" >}}
- **Bảo mật:** Tách biệt tài nguyên của bạn với người khác
- **Kiểm soát:** Quyết định traffic flow và access
- **Tổ chức:** Nhóm resources theo logic business
{{< /alert >}}

## Tổng quan Architecture

{{< workshop-image src="images/vpc-console-overview.png" alt="VPC Console Overview" caption="AWS VPC Console - nơi quản lý toàn bộ networking infrastructure" >}}

Chúng ta sẽ tạo VPC với cấu trúc:

```
VPC (10.0.0.0/16)
├── Public Subnets (Internet access)
│   ├── Public Subnet 1 (10.0.1.0/24) - AZ-a
│   └── Public Subnet 2 (10.0.2.0/24) - AZ-b
���── Private Subnets (No direct internet)
    ├── Private Subnet 1 (10.0.3.0/24) - AZ-a
    └── Private Subnet 2 (10.0.4.0/24) - AZ-b
```

## Bước 1: Chuẩn bị môi trường

### 1.1 Đăng nhập AWS Console

{{< console-screenshot src="images/aws-console-login.png" alt="AWS Console Login" caption="Đăng nhập vào AWS Console với IAM user có quyền admin" service="AWS Console" >}}

### 1.2 Chọn Region

{{< console-screenshot src="images/aws-console-region-selection.png" alt="AWS Region Selection" caption="Chọn region gần nhất để giảm latency (khuyến nghị: us-east-1 hoặc ap-southeast-1)" service="AWS Console" >}}

### 1.3 Tạo working directory

```bash
# Tạo thư mục làm việc
mkdir ~/ecs-workshop
cd ~/ecs-workshop

# Tạo file environment variables
cat > workshop-env.sh << 'EOF'
#!/bin/bash
# ECS Workshop Environment Variables

# AWS Configuration
export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""

# Workshop Configuration
export WORKSHOP_NAME="ecs-advanced-networking"
export ENVIRONMENT="workshop"

echo "✅ Workshop environment loaded"
echo "Region: $AWS_DEFAULT_REGION"
echo "Workshop: $WORKSHOP_NAME"
EOF

# Load environment
chmod +x workshop-env.sh
source workshop-env.sh
```

## Bước 2: Tạo VPC

### 2.1 Tạo VPC chính

```bash
echo "🌐 Tạo VPC..."

VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=ECS-Workshop-VPC},{Key=Environment,Value=workshop}]' \
    --query 'Vpc.VpcId' \
    --output text)

echo "✅ VPC ID: $VPC_ID"
echo "export VPC_ID=$VPC_ID" >> workshop-env.sh
```

### 2.2 Enable DNS support

```bash
echo "🔧 Enable DNS support..."

# Enable DNS hostnames
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames

# Enable DNS resolution
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-support

echo "✅ DNS support enabled"
```

### 2.3 Xem VPC trong Console

{{< console-screenshot src="images/vpc-creation-success.png" alt="VPC Creation Success" caption="VPC đã được tạo thành công với CIDR block 10.0.0.0/16" service="VPC Console" >}}

## Bước 3: Tạo Subnets

### 3.1 Lấy Availability Zones

```bash
echo "📍 Lấy danh sách Availability Zones..."

AZ_1=$(aws ec2 describe-availability-zones \
    --query 'AvailabilityZones[0].ZoneName' \
    --output text)

AZ_2=$(aws ec2 describe-availability-zones \
    --query 'AvailabilityZones[1].ZoneName' \
    --output text)

echo "✅ AZ 1: $AZ_1"
echo "✅ AZ 2: $AZ_2"

echo "export AZ_1=$AZ_1" >> workshop-env.sh
echo "export AZ_2=$AZ_2" >> workshop-env.sh
```

### 3.2 Tạo Public Subnets

```bash
echo "🌐 Tạo Public Subnets..."

# Public Subnet 1
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone $AZ_1 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=ECS-Workshop-Public-1},{Key=Type,Value=Public}]' \
    --query 'Subnet.SubnetId' \
    --output text)

# Public Subnet 2
PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone $AZ_2 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=ECS-Workshop-Public-2},{Key=Type,Value=Public}]' \
    --query 'Subnet.SubnetId' \
    --output text)

echo "✅ Public Subnet 1: $PUBLIC_SUBNET_1"
echo "✅ Public Subnet 2: $PUBLIC_SUBNET_2"

echo "export PUBLIC_SUBNET_1=$PUBLIC_SUBNET_1" >> workshop-env.sh
echo "export PUBLIC_SUBNET_2=$PUBLIC_SUBNET_2" >> workshop-env.sh
```

### 3.3 Tạo Private Subnets

```bash
echo "🔒 Tạo Private Subnets..."

# Private Subnet 1
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.3.0/24 \
    --availability-zone $AZ_1 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=ECS-Workshop-Private-1},{Key=Type,Value=Private}]' \
    --query 'Subnet.SubnetId' \
    --output text)

# Private Subnet 2
PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.4.0/24 \
    --availability-zone $AZ_2 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=ECS-Workshop-Private-2},{Key=Type,Value=Private}]' \
    --query 'Subnet.SubnetId' \
    --output text)

echo "✅ Private Subnet 1: $PRIVATE_SUBNET_1"
echo "✅ Private Subnet 2: $PRIVATE_SUBNET_2"

echo "export PRIVATE_SUBNET_1=$PRIVATE_SUBNET_1" >> workshop-env.sh
echo "export PRIVATE_SUBNET_2=$PRIVATE_SUBNET_2" >> workshop-env.sh
```

### 3.4 Xem Subnets trong Console

{{< console-screenshot src="images/subnets-console.png" alt="Subnets Console View" caption="4 subnets đã được tạo: 2 public và 2 private subnets across 2 AZs" service="VPC Console" >}}

## Bước 4: Tạo Internet Gateway

### 4.1 Tạo và attach Internet Gateway

```bash
echo "🌍 Tạo Internet Gateway..."

# Tạo Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=ECS-Workshop-IGW}]' \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

# Attach to VPC
aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID

echo "✅ Internet Gateway: $IGW_ID"
echo "export IGW_ID=$IGW_ID" >> workshop-env.sh
```

### 4.2 Enable auto-assign public IP cho public subnets

```bash
echo "🔧 Enable auto-assign public IP..."

aws ec2 modify-subnet-attribute \
    --subnet-id $PUBLIC_SUBNET_1 \
    --map-public-ip-on-launch

aws ec2 modify-subnet-attribute \
    --subnet-id $PUBLIC_SUBNET_2 \
    --map-public-ip-on-launch

echo "✅ Auto-assign public IP enabled"
```

## Bước 5: Tạo NAT Gateways

### 5.1 Allocate Elastic IPs

```bash
echo "📍 Allocate Elastic IPs cho NAT Gateways..."

# EIP cho NAT Gateway 1
EIP_1=$(aws ec2 allocate-address \
    --domain vpc \
    --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=ECS-Workshop-EIP-1}]' \
    --query 'AllocationId' \
    --output text)

# EIP cho NAT Gateway 2
EIP_2=$(aws ec2 allocate-address \
    --domain vpc \
    --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=ECS-Workshop-EIP-2}]' \
    --query 'AllocationId' \
    --output text)

echo "✅ EIP 1: $EIP_1"
echo "✅ EIP 2: $EIP_2"

echo "export EIP_1=$EIP_1" >> workshop-env.sh
echo "export EIP_2=$EIP_2" >> workshop-env.sh
```

### 5.2 Tạo NAT Gateways

```bash
echo "🔄 Tạo NAT Gateways..."

# NAT Gateway 1 (trong Public Subnet 1)
NAT_GW_1=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_1 \
    --allocation-id $EIP_1 \
    --tag-specifications 'ResourceType=nat-gateway,Tags=[{Key=Name,Value=ECS-Workshop-NAT-1}]' \
    --query 'NatGateway.NatGatewayId' \
    --output text)

# NAT Gateway 2 (trong Public Subnet 2)
NAT_GW_2=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_2 \
    --allocation-id $EIP_2 \
    --tag-specifications 'ResourceType=nat-gateway,Tags=[{Key=Name,Value=ECS-Workshop-NAT-2}]' \
    --query 'NatGateway.NatGatewayId' \
    --output text)

echo "✅ NAT Gateway 1: $NAT_GW_1"
echo "✅ NAT Gateway 2: $NAT_GW_2"

echo "export NAT_GW_1=$NAT_GW_1" >> workshop-env.sh
echo "export NAT_GW_2=$NAT_GW_2" >> workshop-env.sh
```

### 5.3 Chờ NAT Gateways available

```bash
echo "⏳ Chờ NAT Gateways available..."

aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_1 $NAT_GW_2

echo "✅ NAT Gateways đã sẵn sàng"
```

## Bước 6: Tạo Route Tables

### 6.1 Tạo Public Route Table

```bash
echo "🛣️ Tạo Public Route Table..."

PUBLIC_RT=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=ECS-Workshop-Public-RT}]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Thêm route đến Internet Gateway
aws ec2 create-route \
    --route-table-id $PUBLIC_RT \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

echo "✅ Public Route Table: $PUBLIC_RT"
echo "export PUBLIC_RT=$PUBLIC_RT" >> workshop-env.sh
```

### 6.2 Associate Public Subnets

```bash
echo "🔗 Associate Public Subnets với Route Table..."

aws ec2 associate-route-table \
    --subnet-id $PUBLIC_SUBNET_1 \
    --route-table-id $PUBLIC_RT

aws ec2 associate-route-table \
    --subnet-id $PUBLIC_SUBNET_2 \
    --route-table-id $PUBLIC_RT

echo "✅ Public subnets associated"
```

### 6.3 Tạo Private Route Tables

```bash
echo "🛣️ Tạo Private Route Tables..."

# Private Route Table 1
PRIVATE_RT_1=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=ECS-Workshop-Private-RT-1}]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Route đến NAT Gateway 1
aws ec2 create-route \
    --route-table-id $PRIVATE_RT_1 \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_1

# Private Route Table 2
PRIVATE_RT_2=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=ECS-Workshop-Private-RT-2}]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Route đến NAT Gateway 2
aws ec2 create-route \
    --route-table-id $PRIVATE_RT_2 \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_2

echo "✅ Private Route Table 1: $PRIVATE_RT_1"
echo "✅ Private Route Table 2: $PRIVATE_RT_2"

echo "export PRIVATE_RT_1=$PRIVATE_RT_1" >> workshop-env.sh
echo "export PRIVATE_RT_2=$PRIVATE_RT_2" >> workshop-env.sh
```

### 6.4 Associate Private Subnets

```bash
echo "🔗 Associate Private Subnets với Route Tables..."

aws ec2 associate-route-table \
    --subnet-id $PRIVATE_SUBNET_1 \
    --route-table-id $PRIVATE_RT_1

aws ec2 associate-route-table \
    --subnet-id $PRIVATE_SUBNET_2 \
    --route-table-id $PRIVATE_RT_2

echo "✅ Private subnets associated"
```

### 6.5 Xem Route Tables trong Console

{{< console-screenshot src="images/route-tables-console.png" alt="Route Tables Console" caption="Route tables đã được cấu hình: Public RT với IGW, Private RTs với NAT Gateways" service="VPC Console" >}}

## Bước 7: Tạo Security Groups

### 7.1 ALB Security Group

```bash
echo "🔒 Tạo ALB Security Group..."

ALB_SG=$(aws ec2 create-security-group \
    --group-name ecs-workshop-alb-sg \
    --description "Security group for Application Load Balancer" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ECS-Workshop-ALB-SG}]' \
    --query 'GroupId' \
    --output text)

# Allow HTTP from internet
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# Allow HTTPS from internet
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

echo "✅ ALB Security Group: $ALB_SG"
echo "export ALB_SG=$ALB_SG" >> workshop-env.sh
```

### 7.2 ECS Security Group

```bash
echo "🔒 Tạo ECS Security Group..."

ECS_SG=$(aws ec2 create-security-group \
    --group-name ecs-workshop-ecs-sg \
    --description "Security group for ECS services" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ECS-Workshop-ECS-SG}]' \
    --query 'GroupId' \
    --output text)

# Allow traffic from ALB
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol tcp \
    --port 80 \
    --source-group $ALB_SG

# Allow traffic within ECS security group (for service-to-service communication)
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol -1 \
    --source-group $ECS_SG

echo "✅ ECS Security Group: $ECS_SG"
echo "export ECS_SG=$ECS_SG" >> workshop-env.sh
```

### 7.3 Xem Security Groups trong Console

{{< console-screenshot src="images/security-groups-console.png" alt="Security Groups Console" caption="Security Groups đã được tạo với rules phù hợp cho ALB và ECS services" service="EC2 Console" >}}

## Bước 8: Kiểm tra kết quả

### 8.1 Tóm tắt resources đã tạo

```bash
echo "📋 Tóm tắt VPC Infrastructure:"
echo "================================"
echo "VPC ID: $VPC_ID"
echo "Internet Gateway: $IGW_ID"
echo ""
echo "Public Subnets:"
echo "  - Public Subnet 1: $PUBLIC_SUBNET_1 ($AZ_1)"
echo "  - Public Subnet 2: $PUBLIC_SUBNET_2 ($AZ_2)"
echo ""
echo "Private Subnets:"
echo "  - Private Subnet 1: $PRIVATE_SUBNET_1 ($AZ_1)"
echo "  - Private Subnet 2: $PRIVATE_SUBNET_2 ($AZ_2)"
echo ""
echo "NAT Gateways:"
echo "  - NAT Gateway 1: $NAT_GW_1"
echo "  - NAT Gateway 2: $NAT_GW_2"
echo ""
echo "Security Groups:"
echo "  - ALB Security Group: $ALB_SG"
echo "  - ECS Security Group: $ECS_SG"
echo ""
echo "✅ VPC Infrastructure hoàn tất!"
```

### 8.2 Test connectivity

```bash
echo "🧪 Test VPC connectivity..."

# Kiểm tra VPC DNS resolution
aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsHostnames
aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsSupport

echo "✅ VPC connectivity test completed"
```

## Troubleshooting

### Vấn đề thường gặp:

**NAT Gateway creation failed:**
```bash
# Kiểm tra EIP availability
aws ec2 describe-addresses --allocation-ids $EIP_1 $EIP_2

# Kiểm tra subnet state
aws ec2 describe-subnets --subnet-ids $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2
```

**Route table association issues:**
```bash
# Kiểm tra route table associations
aws ec2 describe-route-tables --route-table-ids $PUBLIC_RT $PRIVATE_RT_1 $PRIVATE_RT_2
```

**Security group rules:**
```bash
# Xem security group rules
aws ec2 describe-security-groups --group-ids $ALB_SG $ECS_SG
```

## Tóm tắt

Bạn đã tạo thành công VPC infrastructure với:

- ✅ **VPC** với CIDR 10.0.0.0/16
- ✅ **4 Subnets** (2 public, 2 private) across 2 AZs
- ✅ **Internet Gateway** cho public internet access
- ✅ **2 NAT Gateways** cho private subnet internet access
- ✅ **Route Tables** với proper routing
- ✅ **Security Groups** cho ALB và ECS

**Network Flow:**
- Public subnets → Internet Gateway → Internet
- Private subnets → NAT Gateway → Internet Gateway → Internet
- ALB (public) → ECS services (private)

## Bước tiếp theo

VPC đã sẵn sàng! Tiếp theo chúng ta sẽ [chuẩn bị môi trường](../2-prerequisites/) và tools cần thiết.

---

{{< alert type="tip" title="Pro Tip" >}}
Lưu file `workshop-env.sh` - bạn sẽ cần nó cho tất cả các bước tiếp theo!
{{< /alert >}}

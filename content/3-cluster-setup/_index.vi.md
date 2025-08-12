---
title : "Cấu hình ECS Cluster & VPC"
date : "`r Sys.Date()`"
weight : 3
chapter : false
pre : " <b> 3. </b> "
---

# Cấu hình ECS Cluster & VPC

Trong phần này, chúng ta sẽ tạo networking infrastructure cơ bản cho workshop ECS advanced networking. Chúng ta sẽ xây dựng custom VPC với kiến trúc subnet phù hợp và thiết lập ECS Fargate cluster.

## Tổng quan Kiến trúc

Chúng ta sẽ tạo infrastructure sau đây:

```
┌─────────────────────────────────────────────────────────────┐
│                    Custom VPC (10.0.0.0/16)                │
│                                                             │
│  ┌─────────────────────┐    ┌─────────────────────┐        │
│  │   Public Subnet     │    │   Public Subnet     │        │
│  │   10.0.1.0/24       │    │   10.0.2.0/24       │        │
│  │   (AZ-1a)           │    │   (AZ-1b)           │        │
│  └─────────────────────┘    └─────────────────────┘        │
│                                                             │
│  ┌─────────────────────┐    ┌─────────────────────┐        │
│  │   Private Subnet    │    │   Private Subnet    │        │
│  │   10.0.3.0/24       │    │   10.0.4.0/24       │        │
│  │   (AZ-1a)           │    │   (AZ-1b)           │        │
│  └─────────────────────┘    └─────────────────────┘        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Chuẩn bị môi trường

### Thiết lập Working Directory

```bash
# Tạo thư mục làm việc cho workshop
mkdir -p ~/ecs-workshop/cluster-setup
cd ~/ecs-workshop/cluster-setup

# Tạo thư mục con để tổ chức
mkdir -p {scripts,configs,logs}

# Set environment variables
export WORKSHOP_NAME="ecs-advanced-networking"
export AWS_REGION=$(aws configure get region)
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Workshop: $WORKSHOP_NAME"
echo "Region: $AWS_REGION" 
echo "Account ID: $ACCOUNT_ID"
```

### Tương tác với AWS Console

Trong suốt phần này, bạn có thể theo dõi tiến trình qua AWS Console:

#### 1. **VPC Console**
- Truy cập: [VPC Console](https://console.aws.amazon.com/vpc/)
- Theo dõi: VPCs, Subnets, Route Tables, Internet Gateways
- Tip: Sử dụng filter theo Name tag để dễ tìm resources

#### 2. **ECS Console**  
- Truy cập: [ECS Console](https://console.aws.amazon.com/ecs/)
- Theo dõi: Clusters, Task Definitions, Services
- Tip: Bookmark cluster page để truy cập nhanh

#### 3. **IAM Console**
- Truy cập: [IAM Console](https://console.aws.amazon.com/iam/)
- Theo dõi: Roles, Policies
- Tip: Kiểm tra roles được tạo tự động

## Bước 1: Tạo Custom VPC

### 1.1 Tạo VPC với AWS CLI

```bash
# Tạo VPC với CIDR block 10.0.0.0/16
echo "🚀 Đang tạo VPC..."
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$WORKSHOP_NAME-vpc},{Key=Workshop,Value=$WORKSHOP_NAME}]" \
    --query 'Vpc.VpcId' \
    --output text)

echo "✅ VPC đã được tạo: $VPC_ID"

# Lưu VPC ID vào file
echo "export VPC_ID=$VPC_ID" >> ../workshop-env.sh
```

### 1.2 Enable DNS Support

```bash
echo "🔧 Đang cấu hình DNS support..."

# Enable DNS hostnames
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames

# Enable DNS support  
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-support

echo "✅ DNS support đã được kích hoạt"
```

### 1.3 Xác minh VPC trong Console

**Tương tác với Console:**
1. Mở [VPC Console](https://console.aws.amazon.com/vpc/)
2. Chọn "Your VPCs" từ menu bên trái
3. Tìm VPC với tên `ecs-advanced-networking-vpc`
4. Xác minh:
   - State: Available
   - CIDR: 10.0.0.0/16
   - DNS resolution: Enabled
   - DNS hostnames: Enabled

## Bước 2: Tạo Subnets

### 2.1 Lấy Availability Zones

```bash
echo "📍 Đang lấy thông tin Availability Zones..."

# Lấy 2 AZ đầu tiên trong region
AZ1=$(aws ec2 describe-availability-zones \
    --query 'AvailabilityZones[0].ZoneName' \
    --output text)
AZ2=$(aws ec2 describe-availability-zones \
    --query 'AvailabilityZones[1].ZoneName' \
    --output text)

echo "AZ1: $AZ1"
echo "AZ2: $AZ2"

# Lưu vào environment file
echo "export AZ1=$AZ1" >> ../workshop-env.sh
echo "export AZ2=$AZ2" >> ../workshop-env.sh
```

### 2.2 Tạo Public Subnets

```bash
echo "🌐 Đang tạo Public Subnets..."

# Tạo Public Subnet 1 (AZ1)
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone $AZ1 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$WORKSHOP_NAME-public-subnet-1},{Key=Type,Value=Public},{Key=AZ,Value=$AZ1}]" \
    --query 'Subnet.SubnetId' \
    --output text)

# Tạo Public Subnet 2 (AZ2)  
PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone $AZ2 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$WORKSHOP_NAME-public-subnet-2},{Key=Type,Value=Public},{Key=AZ,Value=$AZ2}]" \
    --query 'Subnet.SubnetId' \
    --output text)

echo "✅ Public Subnet 1: $PUBLIC_SUBNET_1 ($AZ1)"
echo "✅ Public Subnet 2: $PUBLIC_SUBNET_2 ($AZ2)"

# Lưu vào environment file
echo "export PUBLIC_SUBNET_1=$PUBLIC_SUBNET_1" >> ../workshop-env.sh
echo "export PUBLIC_SUBNET_2=$PUBLIC_SUBNET_2" >> ../workshop-env.sh
```

### 2.3 Tạo Private Subnets

```bash
echo "🔒 Đang tạo Private Subnets..."

# Tạo Private Subnet 1 (AZ1)
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.3.0/24 \
    --availability-zone $AZ1 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$WORKSHOP_NAME-private-subnet-1},{Key=Type,Value=Private},{Key=AZ,Value=$AZ1}]" \
    --query 'Subnet.SubnetId' \
    --output text)

# Tạo Private Subnet 2 (AZ2)
PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.4.0/24 \
    --availability-zone $AZ2 \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$WORKSHOP_NAME-private-subnet-2},{Key=Type,Value=Private},{Key=AZ,Value=$AZ2}]" \
    --query 'Subnet.SubnetId' \
    --output text)

echo "✅ Private Subnet 1: $PRIVATE_SUBNET_1 ($AZ1)"
echo "✅ Private Subnet 2: $PRIVATE_SUBNET_2 ($AZ2)"

# Lưu vào environment file
echo "export PRIVATE_SUBNET_1=$PRIVATE_SUBNET_1" >> ../workshop-env.sh
echo "export PRIVATE_SUBNET_2=$PRIVATE_SUBNET_2" >> ../workshop-env.sh
```

### 2.4 Xác minh Subnets trong Console

**Tương tác với Console:**
1. Trong [VPC Console](https://console.aws.amazon.com/vpc/), chọn "Subnets"
2. Filter theo VPC ID hoặc Workshop tag
3. Xác minh 4 subnets đã được tạo:
   - 2 Public subnets (10.0.1.0/24, 10.0.2.0/24)
   - 2 Private subnets (10.0.3.0/24, 10.0.4.0/24)
4. Kiểm tra Availability Zone distribution

## Bước 3: Internet Gateway và NAT Gateways

### 3.1 Tạo và Attach Internet Gateway

```bash
echo "🌍 Đang tạo Internet Gateway..."

# Tạo Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$WORKSHOP_NAME-igw}]" \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

# Attach Internet Gateway vào VPC
aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID

echo "✅ Internet Gateway: $IGW_ID"
echo "export IGW_ID=$IGW_ID" >> ../workshop-env.sh
```

### 3.2 Tạo NAT Gateways

```bash
echo "🔄 Đang tạo NAT Gateways..."

# Allocate Elastic IPs cho NAT Gateways
echo "  📍 Đang allocate Elastic IPs..."
EIP_1=$(aws ec2 allocate-address \
    --domain vpc \
    --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$WORKSHOP_NAME-nat-eip-1}]" \
    --query 'AllocationId' \
    --output text)

EIP_2=$(aws ec2 allocate-address \
    --domain vpc \
    --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$WORKSHOP_NAME-nat-eip-2}]" \
    --query 'AllocationId' \
    --output text)

echo "  ✅ Elastic IP 1: $EIP_1"
echo "  ✅ Elastic IP 2: $EIP_2"

# Tạo NAT Gateway 1
echo "  🚀 Đang tạo NAT Gateway 1..."
NAT_GW_1=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_1 \
    --allocation-id $EIP_1 \
    --tag-specifications "ResourceType=nat-gateway,Tags=[{Key=Name,Value=$WORKSHOP_NAME-nat-gw-1}]" \
    --query 'NatGateway.NatGatewayId' \
    --output text)

# Tạo NAT Gateway 2  
echo "  🚀 Đang tạo NAT Gateway 2..."
NAT_GW_2=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_2 \
    --allocation-id $EIP_2 \
    --tag-specifications "ResourceType=nat-gateway,Tags=[{Key=Name,Value=$WORKSHOP_NAME-nat-gw-2}]" \
    --query 'NatGateway.NatGatewayId' \
    --output text)

echo "✅ NAT Gateway 1: $NAT_GW_1"
echo "✅ NAT Gateway 2: $NAT_GW_2"

# Lưu vào environment file
echo "export NAT_GW_1=$NAT_GW_1" >> ../workshop-env.sh
echo "export NAT_GW_2=$NAT_GW_2" >> ../workshop-env.sh

# Chờ NAT Gateways available (có thể mất 5-10 phút)
echo "⏳ Đang chờ NAT Gateways available (có thể mất 5-10 phút)..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_1 $NAT_GW_2
echo "✅ NAT Gateways đã sẵn sàng!"
```

### 3.3 Monitor NAT Gateway Creation

**Tương tác với Console:**
1. Trong [VPC Console](https://console.aws.amazon.com/vpc/), chọn "NAT Gateways"
2. Theo dõi status của 2 NAT Gateways:
   - State: Available (sau 5-10 phút)
   - Subnet: Trong public subnets
   - Elastic IP: Đã được assign

**Monitoring Script:**
```bash
# Script để monitor NAT Gateway status
cat > monitor-nat-gw.sh << 'EOF'
#!/bin/bash
echo "Monitoring NAT Gateway status..."
while true; do
    STATUS1=$(aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_1 --query 'NatGateways[0].State' --output text)
    STATUS2=$(aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_2 --query 'NatGateways[0].State' --output text)
    
    echo "$(date): NAT-GW-1: $STATUS1, NAT-GW-2: $STATUS2"
    
    if [[ "$STATUS1" == "available" && "$STATUS2" == "available" ]]; then
        echo "✅ Tất cả NAT Gateways đã sẵn sàng!"
        break
    fi
    
    sleep 30
done
EOF

chmod +x monitor-nat-gw.sh
# Chạy trong background: ./monitor-nat-gw.sh &
```

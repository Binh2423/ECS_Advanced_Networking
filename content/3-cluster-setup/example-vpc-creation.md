---
title : "Ví dụ: Tạo VPC Step-by-Step"
date : "`r Sys.Date()`"
weight : 31
chapter : false
pre : " <b> 3.1 </b> "
---

# Ví dụ: Tạo VPC Step-by-Step

## Tổng quan

Trong ví dụ này, chúng ta sẽ tạo một VPC hoàn chỉnh với tất cả components cần thiết cho ECS cluster. Mỗi bước sẽ được giải thích chi tiết với output mẫu và cách xác minh kết quả.

## Bước 1: Tạo VPC

### Command và Giải thích

```bash
# Command tạo VPC
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=ECS-Workshop-VPC}]' \
    --query 'Vpc.VpcId' \
    --output text)

echo "VPC ID: $VPC_ID"
```

### Giải thích từng tham số:

- **`--cidr-block 10.0.0.0/16`**: 
  - Định nghĩa dải IP cho VPC
  - 10.0.0.0/16 = 65,536 IP addresses (10.0.0.0 đến 10.0.255.255)
  - Đủ lớn cho workshop và có thể mở rộng

- **`--tag-specifications`**:
  - Gắn tags để dễ quản lý
  - Name tag giúp identify trong Console
  - Có thể thêm tags khác như Environment, Project

- **`--query 'Vpc.VpcId'`**:
  - Chỉ lấy VPC ID từ response
  - Lưu vào biến để sử dụng cho các commands tiếp theo

### Output mẫu:

```
VPC ID: vpc-0123456789abcdef0
```

### Xác minh trong AWS Console:

1. **Truy cập VPC Console**: https://console.aws.amazon.com/vpc/
2. **Chọn "Your VPCs"** từ menu bên trái
3. **Tìm VPC** với Name = "ECS-Workshop-VPC"
4. **Kiểm tra thông tin**:
   - State: Available
   - IPv4 CIDR: 10.0.0.0/16
   - Tenancy: Default

### Xác minh bằng CLI:

```bash
# Kiểm tra VPC vừa tạo
aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].{VpcId:VpcId,State:State,CidrBlock:CidrBlock}'

# Output mẫu:
{
    "VpcId": "vpc-0123456789abcdef0",
    "State": "available",
    "CidrBlock": "10.0.0.0/16"
}
```

## Bước 2: Enable DNS Support

### Tại sao cần DNS Support?

- **DNS Resolution**: Cho phép instances resolve DNS names
- **DNS Hostnames**: Tự động assign DNS names cho instances
- **Service Discovery**: Cần thiết cho ECS service discovery

### Commands và Giải thích:

```bash
# Enable DNS hostnames
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames

# Enable DNS support
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-support
```

### Xác minh DNS Settings:

```bash
# Kiểm tra DNS attributes
aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsHostnames
aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsSupport

# Output mẫu:
{
    "VpcId": "vpc-0123456789abcdef0",
    "EnableDnsHostnames": {
        "Value": true
    }
}
```

## Bước 3: Tạo Subnets

### Chiến lược Subnet Design

```
VPC: 10.0.0.0/16 (65,536 IPs)
├── Public Subnet 1:  10.0.1.0/24 (256 IPs) - AZ-1a
├── Public Subnet 2:  10.0.2.0/24 (256 IPs) - AZ-1b  
├── Private Subnet 1: 10.0.3.0/24 (256 IPs) - AZ-1a
└── Private Subnet 2: 10.0.4.0/24 (256 IPs) - AZ-1b
```

### Lấy Availability Zones:

```bash
# Lấy danh sách AZs
aws ec2 describe-availability-zones --query 'AvailabilityZones[].ZoneName'

# Output mẫu:
[
    "us-east-1a",
    "us-east-1b", 
    "us-east-1c",
    "us-east-1d"
]

# Chọn 2 AZ đầu tiên
AZ1=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text)
AZ2=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[1].ZoneName' --output text)

echo "Sử dụng AZ1: $AZ1"
echo "Sử dụng AZ2: $AZ2"
```

### Tạo Public Subnet 1:

```bash
# Tạo public subnet trong AZ1
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone $AZ1 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=ECS-Public-Subnet-1},{Key=Type,Value=Public}]' \
    --query 'Subnet.SubnetId' \
    --output text)

echo "Public Subnet 1: $PUBLIC_SUBNET_1"
```

### Giải thích tham số:
- **`--cidr-block 10.0.1.0/24`**: 256 IP addresses (10.0.1.0 - 10.0.1.255)
- **`--availability-zone $AZ1`**: Đặt subnet trong AZ cụ thể
- **Tags**: Type=Public để phân biệt với private subnets

### Xác minh Subnet:

```bash
# Kiểm tra subnet vừa tạo
aws ec2 describe-subnets --subnet-ids $PUBLIC_SUBNET_1 \
    --query 'Subnets[0].{SubnetId:SubnetId,State:State,CidrBlock:CidrBlock,AvailabilityZone:AvailabilityZone}'

# Output mẫu:
{
    "SubnetId": "subnet-0123456789abcdef0",
    "State": "available", 
    "CidrBlock": "10.0.1.0/24",
    "AvailabilityZone": "us-east-1a"
}
```

## Bước 4: Internet Gateway

### Tại sao cần Internet Gateway?

- **Public Internet Access**: Cho phép resources trong public subnets truy cập internet
- **Inbound Traffic**: Nhận traffic từ internet (qua Load Balancer)
- **Outbound Traffic**: ECS tasks pull images từ ECR

### Tạo và Attach Internet Gateway:

```bash
# Tạo Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=ECS-Workshop-IGW}]' \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

echo "Internet Gateway: $IGW_ID"

# Attach vào VPC
aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID

echo "Internet Gateway đã được attach vào VPC"
```

### Xác minh Internet Gateway:

```bash
# Kiểm tra IGW attachment
aws ec2 describe-internet-gateways --internet-gateway-ids $IGW_ID \
    --query 'InternetGateways[0].{InternetGatewayId:InternetGatewayId,State:Attachments[0].State,VpcId:Attachments[0].VpcId}'

# Output mẫu:
{
    "InternetGatewayId": "igw-0123456789abcdef0",
    "State": "attached",
    "VpcId": "vpc-0123456789abcdef0"
}
```

## Bước 5: NAT Gateway

### Tại sao cần NAT Gateway?

- **Private Subnet Internet Access**: Cho phép ECS tasks trong private subnets truy cập internet
- **Security**: Tasks không có public IP, chỉ outbound traffic
- **High Availability**: Một NAT Gateway per AZ

### Tạo Elastic IPs:

```bash
# Allocate EIP cho NAT Gateway 1
EIP_1=$(aws ec2 allocate-address \
    --domain vpc \
    --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=ECS-NAT-EIP-1}]' \
    --query 'AllocationId' \
    --output text)

echo "Elastic IP 1: $EIP_1"

# Kiểm tra EIP
aws ec2 describe-addresses --allocation-ids $EIP_1 \
    --query 'Addresses[0].{AllocationId:AllocationId,PublicIp:PublicIp,Domain:Domain}'

# Output mẫu:
{
    "AllocationId": "eipalloc-0123456789abcdef0",
    "PublicIp": "54.123.45.67",
    "Domain": "vpc"
}
```

### Tạo NAT Gateway:

```bash
# Tạo NAT Gateway trong public subnet
NAT_GW_1=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_1 \
    --allocation-id $EIP_1 \
    --tag-specifications 'ResourceType=nat-gateway,Tags=[{Key=Name,Value=ECS-NAT-GW-1}]' \
    --query 'NatGateway.NatGatewayId' \
    --output text)

echo "NAT Gateway 1: $NAT_GW_1"
```

### Monitor NAT Gateway Creation:

```bash
# NAT Gateway creation mất thời gian, monitor status
while true; do
    STATUS=$(aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_1 \
        --query 'NatGateways[0].State' --output text)
    echo "$(date): NAT Gateway status: $STATUS"
    
    if [ "$STATUS" = "available" ]; then
        echo "✅ NAT Gateway đã sẵn sàng!"
        break
    fi
    
    sleep 30
done
```

### Xác minh NAT Gateway:

```bash
# Kiểm tra NAT Gateway details
aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_1 \
    --query 'NatGateways[0].{NatGatewayId:NatGatewayId,State:State,SubnetId:SubnetId,PublicIp:NatGatewayAddresses[0].PublicIp}'

# Output mẫu:
{
    "NatGatewayId": "nat-0123456789abcdef0",
    "State": "available",
    "SubnetId": "subnet-0123456789abcdef0", 
    "PublicIp": "54.123.45.67"
}
```

## Troubleshooting Common Issues

### Issue 1: VPC Creation Failed

**Error**: `InvalidVpc.Range`

**Cause**: CIDR block conflict hoặc invalid

**Solution**:
```bash
# Kiểm tra existing VPCs
aws ec2 describe-vpcs --query 'Vpcs[].CidrBlock'

# Sử dụng CIDR block khác
VPC_ID=$(aws ec2 create-vpc --cidr-block 172.16.0.0/16 ...)
```

### Issue 2: Subnet Creation Failed

**Error**: `InvalidSubnet.Range`

**Cause**: CIDR block không nằm trong VPC CIDR

**Solution**:
```bash
# Kiểm tra VPC CIDR
aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].CidrBlock'

# Đảm bảo subnet CIDR nằm trong VPC CIDR
# VPC: 10.0.0.0/16 -> Subnets: 10.0.x.0/24
```

### Issue 3: NAT Gateway Creation Slow

**Cause**: NAT Gateway creation mất 5-10 phút

**Solution**:
```bash
# Sử dụng wait command
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_1

# Hoặc monitor với timeout
timeout 600 bash -c 'while [[ $(aws ec2 describe-nat-gateways --nat-gateway-ids '$NAT_GW_1' --query "NatGateways[0].State" --output text) != "available" ]]; do sleep 30; done'
```

## Best Practices

### 1. Naming Convention
```bash
# Consistent naming pattern
WORKSHOP_NAME="ecs-advanced-networking"
ENVIRONMENT="workshop"

# Tags structure
--tag-specifications "ResourceType=vpc,Tags=[
    {Key=Name,Value=${WORKSHOP_NAME}-vpc},
    {Key=Environment,Value=${ENVIRONMENT}},
    {Key=Project,Value=ECS-Workshop},
    {Key=Owner,Value=$(aws sts get-caller-identity --query 'Arn' --output text)}
]"
```

### 2. CIDR Planning
```bash
# Reserve space for future expansion
# VPC: 10.0.0.0/16 (65,536 IPs)
# Current use: 4 subnets x 256 IPs = 1,024 IPs
# Available for expansion: 64,512 IPs
```

### 3. Multi-AZ Design
```bash
# Always use multiple AZs for high availability
# Minimum 2 AZs for production workloads
# Consider 3 AZs for critical applications
```

## Summary

Trong ví dụ này, chúng ta đã:

1. ✅ Tạo VPC với CIDR 10.0.0.0/16
2. ✅ Enable DNS support cho service discovery
3. ✅ Tạo 4 subnets across 2 AZs
4. ✅ Setup Internet Gateway cho public access
5. ✅ Tạo NAT Gateways cho private subnet internet access
6. ✅ Verify tất cả components qua CLI và Console

**Next**: Tiếp tục với Route Tables và Security Groups trong phần tiếp theo.

---
title : "Xây dựng VPC và ECS Cluster"
date : "`r Sys.Date()`"
weight : 3
chapter : false
pre : " <b> 3. </b> "
---

# Xây dựng VPC và ECS Cluster

## Tổng quan

Chúng ta sẽ tạo một mạng riêng (VPC) và ECS cluster như thế này:

```
Internet
    ↓
┌─────────────────────────────────────┐
│           VPC (10.0.0.0/16)         │
│  ┌─────────────┐  ┌─────────────┐   │
│  │Public Subnet│  │Public Subnet│   │
│  │10.0.1.0/24  │  │10.0.2.0/24  │   │
│  └─────────────┘  └─────────────┘   │
│  ┌─────────────┐  ┌─────────────┐   │
│  │Private Sub. │  │Private Sub. │   │
│  │10.0.3.0/24  │  │10.0.4.0/24  │   │
│  │[ECS Tasks]  │  │[ECS Tasks]  │   │
│  └─────────────┘  └─────────────┘   │
└─────────────────────────────────────┘
```

## Bước 1: Tạo VPC

### 1.1 Chuẩn bị

```bash
# Di chuyển vào thư mục làm việc
cd ~/ecs-workshop

# Tạo file lưu environment variables
touch workshop-env.sh
```

### 1.2 Tạo VPC

```bash
# Tạo VPC với dải IP 10.0.0.0/16
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=ECS-Workshop-VPC}]' \
    --query 'Vpc.VpcId' \
    --output text)

echo "✅ VPC đã tạo: $VPC_ID"

# Lưu VPC ID
echo "export VPC_ID=$VPC_ID" >> workshop-env.sh
```

**Giải thích:**
- `10.0.0.0/16`: Dải IP cho VPC (65,536 địa chỉ IP)
- `--tag-specifications`: Đặt tên để dễ nhận biết
- `--query`: Chỉ lấy VPC ID từ kết quả

### 1.3 Xem VPC trong Console

1. Mở [VPC Console](https://console.aws.amazon.com/vpc/)
2. Chọn "Your VPCs" 
3. Tìm VPC tên "ECS-Workshop-VPC"
4. Kiểm tra State = "Available"

![VPC Console Overview](/images/vpc-console-overview.png)

### 1.4 Bật DNS Support

```bash
# Bật DNS hostnames (cần cho Service Discovery)
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames

# Bật DNS resolution
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-support

echo "✅ DNS support đã bật"
```

## Bước 2: Tạo Subnets

### 2.1 Lấy Availability Zones

```bash
# Lấy 2 AZ đầu tiên
AZ1=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text)
AZ2=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[1].ZoneName' --output text)

echo "Sử dụng AZ1: $AZ1"
echo "Sử dụng AZ2: $AZ2"

# Lưu vào file
echo "export AZ1=$AZ1" >> workshop-env.sh
echo "export AZ2=$AZ2" >> workshop-env.sh
```

### 2.2 Tạo Public Subnets

**Public Subnet 1:**
```bash
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone $AZ1 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Public-Subnet-1}]' \
    --query 'Subnet.SubnetId' \
    --output text)

echo "✅ Public Subnet 1: $PUBLIC_SUBNET_1"
```

**Public Subnet 2:**
```bash
PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone $AZ2 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Public-Subnet-2}]' \
    --query 'Subnet.SubnetId' \
    --output text)

echo "✅ Public Subnet 2: $PUBLIC_SUBNET_2"

# Lưu vào file
echo "export PUBLIC_SUBNET_1=$PUBLIC_SUBNET_1" >> workshop-env.sh
echo "export PUBLIC_SUBNET_2=$PUBLIC_SUBNET_2" >> workshop-env.sh
```

### 2.3 Tạo Private Subnets

**Private Subnet 1:**
```bash
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.3.0/24 \
    --availability-zone $AZ1 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Private-Subnet-1}]' \
    --query 'Subnet.SubnetId' \
    --output text)

echo "✅ Private Subnet 1: $PRIVATE_SUBNET_1"
```

**Private Subnet 2:**
```bash
PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.4.0/24 \
    --availability-zone $AZ2 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Private-Subnet-2}]' \
    --query 'Subnet.SubnetId' \
    --output text)

echo "✅ Private Subnet 2: $PRIVATE_SUBNET_2"

# Lưu vào file
echo "export PRIVATE_SUBNET_1=$PRIVATE_SUBNET_1" >> workshop-env.sh
echo "export PRIVATE_SUBNET_2=$PRIVATE_SUBNET_2" >> workshop-env.sh
```

### 2.4 Xem Subnets trong Console

1. Trong [VPC Console](https://console.aws.amazon.com/vpc/), chọn "Subnets"
2. Kiểm tra 4 subnets đã tạo
3. Xem Availability Zone của từng subnet

![Subnets Console](/images/subnets-console.png)

## Bước 3: Tạo Internet Gateway

### 3.1 Tạo và gắn Internet Gateway

```bash
# Tạo Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=ECS-Workshop-IGW}]' \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

echo "✅ Internet Gateway: $IGW_ID"

# Gắn vào VPC
aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID

echo "✅ Internet Gateway đã gắn vào VPC"

# Lưu vào file
echo "export IGW_ID=$IGW_ID" >> workshop-env.sh
```

**Giải thích:**
- Internet Gateway cho phép VPC kết nối internet
- Cần thiết cho public subnets

## Bước 4: Tạo NAT Gateways

### 4.1 Tạo Elastic IPs

```bash
# Tạo Elastic IP cho NAT Gateway 1
EIP_1=$(aws ec2 allocate-address \
    --domain vpc \
    --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=NAT-EIP-1}]' \
    --query 'AllocationId' \
    --output text)

# Tạo Elastic IP cho NAT Gateway 2  
EIP_2=$(aws ec2 allocate-address \
    --domain vpc \
    --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=NAT-EIP-2}]' \
    --query 'AllocationId' \
    --output text)

echo "✅ Elastic IPs: $EIP_1, $EIP_2"
```

### 4.2 Tạo NAT Gateways

```bash
# NAT Gateway 1 (trong Public Subnet 1)
NAT_GW_1=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_1 \
    --allocation-id $EIP_1 \
    --tag-specifications 'ResourceType=nat-gateway,Tags=[{Key=Name,Value=NAT-GW-1}]' \
    --query 'NatGateway.NatGatewayId' \
    --output text)

# NAT Gateway 2 (trong Public Subnet 2)
NAT_GW_2=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_2 \
    --allocation-id $EIP_2 \
    --tag-specifications 'ResourceType=nat-gateway,Tags=[{Key=Name,Value=NAT-GW-2}]' \
    --query 'NatGateway.NatGatewayId' \
    --output text)

echo "✅ NAT Gateways: $NAT_GW_1, $NAT_GW_2"

# Lưu vào file
echo "export NAT_GW_1=$NAT_GW_1" >> workshop-env.sh
echo "export NAT_GW_2=$NAT_GW_2" >> workshop-env.sh
```

### 4.3 Chờ NAT Gateways sẵn sàng

```bash
echo "⏳ Đang chờ NAT Gateways sẵn sàng (5-10 phút)..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_1 $NAT_GW_2
echo "✅ NAT Gateways đã sẵn sàng!"
```

**Giải thích:**
- NAT Gateway cho phép private subnets truy cập internet
- Cần 1 NAT Gateway per AZ cho high availability

## Bước 5: Tạo Route Tables

### 5.1 Tạo Route Tables

```bash
# Public Route Table
PUBLIC_RT=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=Public-RT}]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Private Route Table 1
PRIVATE_RT_1=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=Private-RT-1}]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Private Route Table 2
PRIVATE_RT_2=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=Private-RT-2}]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

echo "✅ Route Tables tạo xong"

# Lưu vào file
echo "export PRIVATE_RT_1=$PRIVATE_RT_1" >> workshop-env.sh
echo "export PRIVATE_RT_2=$PRIVATE_RT_2" >> workshop-env.sh
```

### 5.2 Tạo Routes

```bash
# Route từ Public RT đến Internet Gateway
aws ec2 create-route \
    --route-table-id $PUBLIC_RT \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

# Route từ Private RT 1 đến NAT Gateway 1
aws ec2 create-route \
    --route-table-id $PRIVATE_RT_1 \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_1

# Route từ Private RT 2 đến NAT Gateway 2
aws ec2 create-route \
    --route-table-id $PRIVATE_RT_2 \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_2

echo "✅ Routes đã tạo"
```

### 5.3 Gắn Route Tables vào Subnets

```bash
# Gắn Public Route Table vào Public Subnets
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_1 --route-table-id $PUBLIC_RT
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_2 --route-table-id $PUBLIC_RT

# Gắn Private Route Tables vào Private Subnets
aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_1 --route-table-id $PRIVATE_RT_1
aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_2 --route-table-id $PRIVATE_RT_2

echo "✅ Route Tables đã gắn vào Subnets"
```

![Route Tables Console](/images/route-tables-console.png)

## Bước 6: Tạo Security Groups

### 6.1 Security Group cho Load Balancer

```bash
ALB_SG=$(aws ec2 create-security-group \
    --group-name ECS-ALB-SG \
    --description "Security group for Application Load Balancer" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ECS-ALB-SG}]' \
    --query 'GroupId' \
    --output text)

echo "✅ ALB Security Group: $ALB_SG"

# Cho phép HTTP và HTTPS từ internet
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 443 --cidr 0.0.0.0/0
```

### 6.2 Security Group cho ECS Tasks

```bash
ECS_SG=$(aws ec2 create-security-group \
    --group-name ECS-Tasks-SG \
    --description "Security group for ECS tasks" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ECS-Tasks-SG}]' \
    --query 'GroupId' \
    --output text)

echo "✅ ECS Security Group: $ECS_SG"

# Cho phép traffic từ ALB
aws ec2 authorize-security-group-ingress --group-id $ECS_SG --protocol tcp --port 80 --source-group $ALB_SG
aws ec2 authorize-security-group-ingress --group-id $ECS_SG --protocol tcp --port 3000 --source-group $ALB_SG

# Lưu vào file
echo "export ALB_SG=$ALB_SG" >> workshop-env.sh
echo "export ECS_SG=$ECS_SG" >> workshop-env.sh
```

![Security Groups Console](/images/security-groups-console.png)

## Bước 7: Tạo ECS Cluster

### 7.1 Tạo Cluster

```bash
CLUSTER_NAME="ecs-workshop-cluster"

aws ecs create-cluster \
    --cluster-name $CLUSTER_NAME \
    --capacity-providers FARGATE \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
    --tags key=Name,value=ECS-Workshop-Cluster

echo "✅ ECS Cluster đã tạo: $CLUSTER_NAME"

# Lưu vào file
echo "export CLUSTER_NAME=$CLUSTER_NAME" >> workshop-env.sh
```

### 7.2 Xem Cluster trong Console

1. Mở [ECS Console](https://console.aws.amazon.com/ecs/)
2. Chọn "Clusters"
3. Tìm cluster "ecs-workshop-cluster"
4. Kiểm tra Status = "ACTIVE"

![ECS Cluster Details](/images/ecs-cluster-details.png)

## Bước 8: Tạo IAM Roles

### 8.1 Task Execution Role

```bash
# Tạo trust policy
cat > ecs-task-execution-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Tạo role
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document file://ecs-task-execution-trust-policy.json

# Gắn policy
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

echo "✅ Task Execution Role đã tạo"
```

### 8.2 Task Role

```bash
# Tạo task role
aws iam create-role \
    --role-name ecsTaskRole \
    --assume-role-policy-document file://ecs-task-execution-trust-policy.json

echo "✅ Task Role đã tạo"
```

## Bước 9: Kiểm tra kết quả

### 9.1 Chạy script kiểm tra

```bash
cat > check-infrastructure.sh << 'EOF'
#!/bin/bash
source workshop-env.sh

echo "=== Kiểm tra Infrastructure ==="

echo "1. VPC: $VPC_ID"
aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].State' --output text

echo "2. Subnets:"
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].{Name:Tags[?Key==`Name`].Value|[0],CIDR:CidrBlock,AZ:AvailabilityZone}' --output table

echo "3. ECS Cluster:"
aws ecs describe-clusters --clusters $CLUSTER_NAME --query 'clusters[0].status' --output text

echo "=== Kiểm tra hoàn tất ==="
EOF

chmod +x check-infrastructure.sh
./check-infrastructure.sh
```

### 9.2 Xem tổng quan trong Console

**VPC Dashboard:**
1. Mở [VPC Console](https://console.aws.amazon.com/vpc/)
2. Chọn VPC của bạn
3. Xem Resource map để thấy tổng quan

![VPC Resource Map](/images/vpc-resource-map.png)

**ECS Dashboard:**
1. Mở [ECS Console](https://console.aws.amazon.com/ecs/)
2. Chọn cluster của bạn
3. Xem Services và Tasks tabs

## Troubleshooting

### Vấn đề thường gặp:

**NAT Gateway mất quá lâu:**
- NAT Gateway cần 5-10 phút để sẵn sàng
- Sử dụng `aws ec2 wait nat-gateway-available`

**Security Group rules không hoạt động:**
- Kiểm tra VPC ID đúng không
- Đảm bảo source security group tồn tại

**ECS Cluster không tạo được:**
- Kiểm tra quyền IAM
- Đảm bảo region đúng

## Tóm tắt

Bạn đã tạo thành công:

- ✅ VPC với 4 subnets (2 public, 2 private)
- ✅ Internet Gateway và 2 NAT Gateways  
- ✅ Route Tables với routing đúng
- ✅ Security Groups cho ALB và ECS
- ✅ ECS Fargate Cluster
- ✅ IAM Roles cần thiết

## Bước tiếp theo

Infrastructure đã sẵn sàng! Chuyển đến [Triển khai Service Discovery](../4-service-discovery/) để các services có thể tìm thấy nhau.

---

**💾 Lưu ý:** File `workshop-env.sh` chứa tất cả IDs cần thiết cho các bước tiếp theo.

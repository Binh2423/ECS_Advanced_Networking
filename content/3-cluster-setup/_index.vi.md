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

Chúng ta sẽ tạo infrastructure sau:

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

## Bước 1: Tạo Custom VPC

### 1.1 Tạo VPC
Đầu tiên, hãy tạo custom VPC:

```bash
# Tạo VPC
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=ECS-Workshop-VPC}]' \
    --query 'Vpc.VpcId' \
    --output text)

echo "VPC ID: $VPC_ID"
```

### 1.2 Enable DNS Support
Enable DNS hostnames và resolution:

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

## Bước 2: Tạo Subnets

### 2.1 Lấy Availability Zones
```bash
# Lấy available AZs
AZ1=$(aws ec2 describe-availability-zones \
    --query 'AvailabilityZones[0].ZoneName' \
    --output text)
AZ2=$(aws ec2 describe-availability-zones \
    --query 'AvailabilityZones[1].ZoneName' \
    --output text)

echo "AZ1: $AZ1"
echo "AZ2: $AZ2"
```

### 2.2 Tạo Public Subnets
```bash
# Tạo Public Subnet 1
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone $AZ1 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=ECS-Public-Subnet-1}]' \
    --query 'Subnet.SubnetId' \
    --output text)

# Tạo Public Subnet 2
PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone $AZ2 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=ECS-Public-Subnet-2}]' \
    --query 'Subnet.SubnetId' \
    --output text)

echo "Public Subnet 1: $PUBLIC_SUBNET_1"
echo "Public Subnet 2: $PUBLIC_SUBNET_2"
```

### 2.3 Tạo Private Subnets
```bash
# Tạo Private Subnet 1
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.3.0/24 \
    --availability-zone $AZ1 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=ECS-Private-Subnet-1}]' \
    --query 'Subnet.SubnetId' \
    --output text)

# Tạo Private Subnet 2
PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.4.0/24 \
    --availability-zone $AZ2 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=ECS-Private-Subnet-2}]' \
    --query 'Subnet.SubnetId' \
    --output text)

echo "Private Subnet 1: $PRIVATE_SUBNET_1"
echo "Private Subnet 2: $PRIVATE_SUBNET_2"
```

## Bước 3: Internet Gateway và NAT Gateways

### 3.1 Tạo và Attach Internet Gateway
```bash
# Tạo Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=ECS-Workshop-IGW}]' \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

# Attach vào VPC
aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID

echo "Internet Gateway: $IGW_ID"
```

### 3.2 Tạo NAT Gateways
```bash
# Allocate Elastic IPs cho NAT Gateways
EIP_1=$(aws ec2 allocate-address \
    --domain vpc \
    --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=ECS-NAT-EIP-1}]' \
    --query 'AllocationId' \
    --output text)

EIP_2=$(aws ec2 allocate-address \
    --domain vpc \
    --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=ECS-NAT-EIP-2}]' \
    --query 'AllocationId' \
    --output text)

# Tạo NAT Gateways
NAT_GW_1=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_1 \
    --allocation-id $EIP_1 \
    --tag-specifications 'ResourceType=nat-gateway,Tags=[{Key=Name,Value=ECS-NAT-GW-1}]' \
    --query 'NatGateway.NatGatewayId' \
    --output text)

NAT_GW_2=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_2 \
    --allocation-id $EIP_2 \
    --tag-specifications 'ResourceType=nat-gateway,Tags=[{Key=Name,Value=ECS-NAT-GW-2}]' \
    --query 'NatGateway.NatGatewayId' \
    --output text)

echo "NAT Gateway 1: $NAT_GW_1"
echo "NAT Gateway 2: $NAT_GW_2"

# Chờ NAT Gateways available
echo "Đang chờ NAT Gateways available..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_1 $NAT_GW_2
```

## Bước 4: Route Tables

### 4.1 Tạo Route Tables
```bash
# Tạo Public Route Table
PUBLIC_RT=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=ECS-Public-RT}]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Tạo Private Route Tables
PRIVATE_RT_1=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=ECS-Private-RT-1}]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

PRIVATE_RT_2=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=ECS-Private-RT-2}]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

echo "Public Route Table: $PUBLIC_RT"
echo "Private Route Table 1: $PRIVATE_RT_1"
echo "Private Route Table 2: $PRIVATE_RT_2"
```

### 4.2 Tạo Routes
```bash
# Thêm route đến Internet Gateway cho public subnets
aws ec2 create-route \
    --route-table-id $PUBLIC_RT \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

# Thêm routes đến NAT Gateways cho private subnets
aws ec2 create-route \
    --route-table-id $PRIVATE_RT_1 \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_1

aws ec2 create-route \
    --route-table-id $PRIVATE_RT_2 \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_2
```

### 4.3 Associate Route Tables với Subnets
```bash
# Associate public subnets với public route table
aws ec2 associate-route-table \
    --subnet-id $PUBLIC_SUBNET_1 \
    --route-table-id $PUBLIC_RT

aws ec2 associate-route-table \
    --subnet-id $PUBLIC_SUBNET_2 \
    --route-table-id $PUBLIC_RT

# Associate private subnets với private route tables
aws ec2 associate-route-table \
    --subnet-id $PRIVATE_SUBNET_1 \
    --route-table-id $PRIVATE_RT_1

aws ec2 associate-route-table \
    --subnet-id $PRIVATE_SUBNET_2 \
    --route-table-id $PRIVATE_RT_2
```

## Bước 5: Security Groups

### 5.1 Tạo Security Groups
```bash
# Security Group cho ALB
ALB_SG=$(aws ec2 create-security-group \
    --group-name ECS-ALB-SG \
    --description "Security group for Application Load Balancer" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ECS-ALB-SG}]' \
    --query 'GroupId' \
    --output text)

# Security Group cho ECS Tasks
ECS_SG=$(aws ec2 create-security-group \
    --group-name ECS-Tasks-SG \
    --description "Security group for ECS tasks" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ECS-Tasks-SG}]' \
    --query 'GroupId' \
    --output text)

echo "ALB Security Group: $ALB_SG"
echo "ECS Security Group: $ECS_SG"
```

### 5.2 Cấu hình Security Group Rules
```bash
# ALB Security Group Rules
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# ECS Tasks Security Group Rules
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol tcp \
    --port 80 \
    --source-group $ALB_SG

aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# Cho phép all outbound traffic (default)
```

## Bước 6: Tạo ECS Cluster

### 6.1 Tạo ECS Cluster
```bash
# Tạo ECS cluster
CLUSTER_NAME="ecs-workshop-cluster"
aws ecs create-cluster \
    --cluster-name $CLUSTER_NAME \
    --capacity-providers FARGATE \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
    --tags key=Name,value=ECS-Workshop-Cluster

echo "ECS Cluster đã được tạo: $CLUSTER_NAME"
```

### 6.2 Xác minh Cluster Creation
```bash
# Xác minh cluster status
aws ecs describe-clusters \
    --clusters $CLUSTER_NAME \
    --query 'clusters[0].{Name:clusterName,Status:status,ActiveServicesCount:activeServicesCount}'
```

## Bước 7: Tạo IAM Roles

### 7.1 ECS Task Execution Role
```bash
# Tạo trust policy cho ECS tasks
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

# Tạo ECS task execution role
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document file://ecs-task-execution-trust-policy.json

# Attach AWS managed policy
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

### 7.2 ECS Task Role (cho application permissions)
```bash
# Tạo ECS task role
aws iam create-role \
    --role-name ecsTaskRole \
    --assume-role-policy-document file://ecs-task-execution-trust-policy.json

# Tạo custom policy cho task role
cat > ecs-task-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Tạo và attach custom policy
aws iam create-policy \
    --policy-name ECSTaskCustomPolicy \
    --policy-document file://ecs-task-policy.json

aws iam attach-role-policy \
    --role-name ecsTaskRole \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/ECSTaskCustomPolicy
```

## Bước 8: Verification

### 8.1 Lưu Environment Variables
Tạo file để lưu tất cả resource IDs cho việc sử dụng sau:

```bash
# Lưu tất cả resource IDs
cat > workshop-resources.env << EOF
export VPC_ID=$VPC_ID
export PUBLIC_SUBNET_1=$PUBLIC_SUBNET_1
export PUBLIC_SUBNET_2=$PUBLIC_SUBNET_2
export PRIVATE_SUBNET_1=$PRIVATE_SUBNET_1
export PRIVATE_SUBNET_2=$PRIVATE_SUBNET_2
export ALB_SG=$ALB_SG
export ECS_SG=$ECS_SG
export CLUSTER_NAME=$CLUSTER_NAME
export IGW_ID=$IGW_ID
export NAT_GW_1=$NAT_GW_1
export NAT_GW_2=$NAT_GW_2
export PRIVATE_RT_1=$PRIVATE_RT_1
export PRIVATE_RT_2=$PRIVATE_RT_2
EOF

echo "Resource IDs đã được lưu vào workshop-resources.env"
echo "Source file này trong future sessions: source workshop-resources.env"
```

### 8.2 Xác minh Infrastructure
```bash
# Xác minh VPC
aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].{VpcId:VpcId,State:State,CidrBlock:CidrBlock}'

# Xác minh subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].{SubnetId:SubnetId,CidrBlock:CidrBlock,AvailabilityZone:AvailabilityZone}'

# Xác minh ECS cluster
aws ecs describe-clusters --clusters $CLUSTER_NAME --query 'clusters[0].{Name:clusterName,Status:status}'
```

## Troubleshooting

### Các vấn đề thường gặp

1. **NAT Gateway Creation Timeout**
   - NAT Gateways có thể mất 5-10 phút để available
   - Sử dụng `aws ec2 wait nat-gateway-available` command

2. **Route Table Association Errors**
   - Đảm bảo subnets tồn tại trước khi associate route tables
   - Kiểm tra route table thuộc cùng VPC

3. **Security Group Rules**
   - Xác minh source security group tồn tại trước khi reference
   - Kiểm tra VPC ID matches cho tất cả security groups

### Verification Commands
```bash
# Kiểm tra VPC components
aws ec2 describe-vpcs --vpc-ids $VPC_ID
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID"
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID"
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID"

# Kiểm tra ECS cluster
aws ecs list-clusters
aws ecs describe-clusters --clusters $CLUSTER_NAME
```

## Bước tiếp theo

Chúc mừng! Bạn đã tạo thành công networking infrastructure cơ bản cho ECS workshop. Môi trường của bạn bây giờ bao gồm:

- ✅ Custom VPC với DNS support
- ✅ Public và private subnets trên hai AZs
- ✅ Internet Gateway và NAT Gateways
- ✅ Proper routing configuration
- ✅ Security groups cho ALB và ECS tasks
- ✅ ECS Fargate cluster
- ✅ IAM roles cho ECS tasks

Tiếp theo, chúng ta sẽ chuyển đến [Triển khai Service Discovery](../4-service-discovery/) nơi chúng ta sẽ thiết lập AWS Cloud Map cho service-to-service communication.

---

**Resources đã tạo:**
- 1 VPC
- 4 Subnets (2 public, 2 private)
- 1 Internet Gateway
- 2 NAT Gateways
- 3 Route Tables
- 2 Security Groups
- 1 ECS Cluster
- 2 IAM Roles

**Ước tính Chi phí hiện tại:** ~$3-5/giờ cho NAT Gateways

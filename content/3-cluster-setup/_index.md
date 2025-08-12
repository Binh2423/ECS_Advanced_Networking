---
title : "ECS Cluster & VPC Configuration"
date : "`r Sys.Date()`"
weight : 3
chapter : false
pre : " <b> 3. </b> "
---

# ECS Cluster & VPC Configuration

In this section, we'll create the foundational networking infrastructure for our ECS advanced networking workshop. We'll build a custom VPC with proper subnet architecture and set up an ECS Fargate cluster.

## Architecture Overview

We'll create the following infrastructure:

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

## Step 1: Create Custom VPC

### 1.1 Create VPC
First, let's create our custom VPC:

```bash
# Create VPC
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=ECS-Workshop-VPC}]' \
    --query 'Vpc.VpcId' \
    --output text)

echo "VPC ID: $VPC_ID"
```

### 1.2 Enable DNS Support
Enable DNS hostnames and resolution:

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

## Step 2: Create Subnets

### 2.1 Get Availability Zones
```bash
# Get available AZs
AZ1=$(aws ec2 describe-availability-zones \
    --query 'AvailabilityZones[0].ZoneName' \
    --output text)
AZ2=$(aws ec2 describe-availability-zones \
    --query 'AvailabilityZones[1].ZoneName' \
    --output text)

echo "AZ1: $AZ1"
echo "AZ2: $AZ2"
```

### 2.2 Create Public Subnets
```bash
# Create Public Subnet 1
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone $AZ1 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=ECS-Public-Subnet-1}]' \
    --query 'Subnet.SubnetId' \
    --output text)

# Create Public Subnet 2
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

### 2.3 Create Private Subnets
```bash
# Create Private Subnet 1
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.3.0/24 \
    --availability-zone $AZ1 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=ECS-Private-Subnet-1}]' \
    --query 'Subnet.SubnetId' \
    --output text)

# Create Private Subnet 2
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

## Step 3: Internet Gateway and NAT Gateways

### 3.1 Create and Attach Internet Gateway
```bash
# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=ECS-Workshop-IGW}]' \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

# Attach to VPC
aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID

echo "Internet Gateway: $IGW_ID"
```

### 3.2 Create NAT Gateways
```bash
# Allocate Elastic IPs for NAT Gateways
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

# Create NAT Gateways
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

# Wait for NAT Gateways to be available
echo "Waiting for NAT Gateways to be available..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_1 $NAT_GW_2
```

## Step 4: Route Tables

### 4.1 Create Route Tables
```bash
# Create Public Route Table
PUBLIC_RT=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=ECS-Public-RT}]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Create Private Route Tables
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

### 4.2 Create Routes
```bash
# Add route to Internet Gateway for public subnets
aws ec2 create-route \
    --route-table-id $PUBLIC_RT \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

# Add routes to NAT Gateways for private subnets
aws ec2 create-route \
    --route-table-id $PRIVATE_RT_1 \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_1

aws ec2 create-route \
    --route-table-id $PRIVATE_RT_2 \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_2
```

### 4.3 Associate Route Tables with Subnets
```bash
# Associate public subnets with public route table
aws ec2 associate-route-table \
    --subnet-id $PUBLIC_SUBNET_1 \
    --route-table-id $PUBLIC_RT

aws ec2 associate-route-table \
    --subnet-id $PUBLIC_SUBNET_2 \
    --route-table-id $PUBLIC_RT

# Associate private subnets with private route tables
aws ec2 associate-route-table \
    --subnet-id $PRIVATE_SUBNET_1 \
    --route-table-id $PRIVATE_RT_1

aws ec2 associate-route-table \
    --subnet-id $PRIVATE_SUBNET_2 \
    --route-table-id $PRIVATE_RT_2
```

## Step 5: Security Groups

### 5.1 Create Security Groups
```bash
# Security Group for ALB
ALB_SG=$(aws ec2 create-security-group \
    --group-name ECS-ALB-SG \
    --description "Security group for Application Load Balancer" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ECS-ALB-SG}]' \
    --query 'GroupId' \
    --output text)

# Security Group for ECS Tasks
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

### 5.2 Configure Security Group Rules
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

# Allow all outbound traffic (default)
```

## Step 6: Create ECS Cluster

### 6.1 Create ECS Cluster
```bash
# Create ECS cluster
CLUSTER_NAME="ecs-workshop-cluster"
aws ecs create-cluster \
    --cluster-name $CLUSTER_NAME \
    --capacity-providers FARGATE \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
    --tags key=Name,value=ECS-Workshop-Cluster

echo "ECS Cluster created: $CLUSTER_NAME"
```

### 6.2 Verify Cluster Creation
```bash
# Verify cluster status
aws ecs describe-clusters \
    --clusters $CLUSTER_NAME \
    --query 'clusters[0].{Name:clusterName,Status:status,ActiveServicesCount:activeServicesCount}'
```

## Step 7: Create IAM Roles

### 7.1 ECS Task Execution Role
```bash
# Create trust policy for ECS tasks
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

# Create ECS task execution role
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document file://ecs-task-execution-trust-policy.json

# Attach AWS managed policy
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

### 7.2 ECS Task Role (for application permissions)
```bash
# Create ECS task role
aws iam create-role \
    --role-name ecsTaskRole \
    --assume-role-policy-document file://ecs-task-execution-trust-policy.json

# Create custom policy for task role
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

# Create and attach custom policy
aws iam create-policy \
    --policy-name ECSTaskCustomPolicy \
    --policy-document file://ecs-task-policy.json

aws iam attach-role-policy \
    --role-name ecsTaskRole \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/ECSTaskCustomPolicy
```

## Step 8: Verification

### 8.1 Save Environment Variables
Create a file to save all the resource IDs for later use:

```bash
# Save all resource IDs
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
EOF

echo "Resource IDs saved to workshop-resources.env"
echo "Source this file in future sessions: source workshop-resources.env"
```

### 8.2 Verify Infrastructure
```bash
# Verify VPC
aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].{VpcId:VpcId,State:State,CidrBlock:CidrBlock}'

# Verify subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].{SubnetId:SubnetId,CidrBlock:CidrBlock,AvailabilityZone:AvailabilityZone}'

# Verify ECS cluster
aws ecs describe-clusters --clusters $CLUSTER_NAME --query 'clusters[0].{Name:clusterName,Status:status}'
```

## Troubleshooting

### Common Issues

1. **NAT Gateway Creation Timeout**
   - NAT Gateways can take 5-10 minutes to become available
   - Use `aws ec2 wait nat-gateway-available` command

2. **Route Table Association Errors**
   - Ensure subnets exist before associating route tables
   - Check that route table belongs to the same VPC

3. **Security Group Rules**
   - Verify source security group exists before referencing
   - Check VPC ID matches for all security groups

### Verification Commands
```bash
# Check VPC components
aws ec2 describe-vpcs --vpc-ids $VPC_ID
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID"
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID"
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID"

# Check ECS cluster
aws ecs list-clusters
aws ecs describe-clusters --clusters $CLUSTER_NAME
```

## Next Steps

Congratulations! You've successfully created the foundational networking infrastructure for the ECS workshop. Your environment now includes:

- ✅ Custom VPC with DNS support
- ✅ Public and private subnets across two AZs
- ✅ Internet Gateway and NAT Gateways
- ✅ Proper routing configuration
- ✅ Security groups for ALB and ECS tasks
- ✅ ECS Fargate cluster
- ✅ IAM roles for ECS tasks

Next, we'll move on to [Service Discovery Implementation](../4-service-discovery/) where we'll set up AWS Cloud Map for service-to-service communication.

---

**Resources Created:**
- 1 VPC
- 4 Subnets (2 public, 2 private)
- 1 Internet Gateway
- 2 NAT Gateways
- 3 Route Tables
- 2 Security Groups
- 1 ECS Cluster
- 2 IAM Roles

**Estimated Cost So Far:** ~$3-5/hour for NAT Gateways

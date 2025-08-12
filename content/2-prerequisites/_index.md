---
title : "Chuẩn bị môi trường"
date : "`r Sys.Date()`"
weight : 2
chapter : false
pre : " <b> 2. </b> "
---

## Kiểm tra Prerequisites

Trước khi bắt đầu workshop, chúng ta cần đảm bảo có đủ tools và permissions cần thiết.

{{< alert type="info" title="Quan trọng" >}}
Workshop này sử dụng AWS resources có tính phí. Ước tính chi phí: $2-5 cho toàn bộ workshop.
{{< /alert >}}

## Bước 1: Đăng nhập AWS Console

### 1.1 Truy cập AWS Console

{{< console-screenshot src="images/aws-console-login.png" alt="AWS Console Login" caption="Đăng nhập vào AWS Console với IAM user có quyền admin" service="AWS Console" >}}

### 1.2 Chọn Region phù hợp

{{< console-screenshot src="images/aws-console-region-selection.png" alt="AWS Region Selection" caption="Chọn region gần nhất để giảm latency (khuyến nghị: us-east-1 hoặc ap-southeast-1)" service="AWS Console" >}}

**Regions khuyến nghị:**
- **us-east-1** (N. Virginia) - Rẻ nhất, nhiều services
- **ap-southeast-1** (Singapore) - Gần Việt Nam
- **eu-west-1** (Ireland) - Cho châu Âu

## Bước 2: Kiểm tra AWS CLI

### 2.1 Cài đặt AWS CLI

```bash
# Kiểm tra version hiện tại
aws --version

# Nếu chưa có, cài đặt AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### 2.2 Cấu hình AWS CLI

```bash
# Cấu hình credentials
aws configure

# Nhập thông tin:
# AWS Access Key ID: [Your Access Key]
# AWS Secret Access Key: [Your Secret Key]
# Default region name: us-east-1
# Default output format: json
```

### 2.3 Test AWS Access

```bash
# Kiểm tra identity
aws sts get-caller-identity

# Kiểm tra permissions
aws iam get-user
aws ec2 describe-regions --region us-east-1 --output table
```

**Expected Output:**
```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/workshop-user"
}
```

## Bước 3: Kiểm tra IAM Permissions

### 3.1 Required Permissions

Workshop cần các permissions sau:

{{< console-screenshot src="images/iam-policies.png" alt="IAM Policies Console" caption="Kiểm tra IAM policies cần thiết cho workshop" service="IAM Console" >}}

**Minimum Required Policies:**
- `AmazonVPCFullAccess`
- `AmazonECS_FullAccess`
- `ElasticLoadBalancingFullAccess`
- `AmazonRoute53FullAccess`
- `CloudWatchFullAccess`
- `IAMFullAccess` (để tạo roles)

### 3.2 Kiểm tra ECS Service Role

{{< console-screenshot src="images/iam-roles-ecs.png" alt="ECS IAM Roles" caption="ECS service roles cần thiết cho Fargate và task execution" service="IAM Console" >}}

```bash
# Kiểm tra ECS roles
aws iam get-role --role-name ecsTaskExecutionRole 2>/dev/null || echo "Role chưa tồn tại"

# Tạo role nếu chưa có
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document '{
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
    }'

# Attach policy
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

## Bước 4: Kiểm tra Service Quotas

### 4.1 VPC Limits

```bash
# Kiểm tra VPC limits
aws ec2 describe-account-attributes --attribute-names supported-platforms
aws ec2 describe-vpcs --query 'length(Vpcs)'

echo "VPC Limit: 5 (default)"
echo "Current VPCs: $(aws ec2 describe-vpcs --query 'length(Vpcs)')"
```

### 4.2 ECS Limits

```bash
# Kiểm tra ECS clusters
aws ecs list-clusters --query 'length(clusterArns)'

echo "ECS Cluster Limit: 10000 (default)"
echo "Current Clusters: $(aws ecs list-clusters --query 'length(clusterArns)')"
```

### 4.3 Load Balancer Limits

```bash
# Kiểm tra ALB limits
aws elbv2 describe-load-balancers --query 'length(LoadBalancers)'

echo "ALB Limit: 50 (default)"
echo "Current ALBs: $(aws elbv2 describe-load-balancers --query 'length(LoadBalancers)')"
```

## Bước 5: Chuẩn bị Tools

### 5.1 Required Tools

```bash
# Kiểm tra tools cần thiết
echo "=== Tool Check ==="
echo "AWS CLI: $(aws --version 2>&1 | head -1)"
echo "jq: $(jq --version 2>/dev/null || echo 'Not installed')"
echo "curl: $(curl --version 2>&1 | head -1)"
echo "git: $(git --version 2>&1)"
```

### 5.2 Install Missing Tools

```bash
# Install jq (JSON processor)
sudo apt-get update && sudo apt-get install -y jq

# Hoặc trên macOS
brew install jq

# Hoặc trên Amazon Linux
sudo yum install -y jq
```

### 5.3 Setup Working Directory

```bash
# Tạo working directory
mkdir -p ~/ecs-workshop
cd ~/ecs-workshop

# Tạo environment file
cat > workshop-env.sh << 'EOF'
#!/bin/bash
# ECS Workshop Environment Variables

# AWS Configuration
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}
export AWS_PAGER=""

# Workshop Configuration
export WORKSHOP_NAME="ecs-advanced-networking"
export ENVIRONMENT="workshop"
export TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

echo "✅ Workshop environment loaded"
echo "Region: $AWS_DEFAULT_REGION"
echo "Workshop: $WORKSHOP_NAME"
echo "Timestamp: $TIMESTAMP"
EOF

# Make executable và load
chmod +x workshop-env.sh
source workshop-env.sh
```

## Bước 6: Pre-flight Check

### 6.1 Comprehensive Check Script

```bash
# Tạo pre-flight check script
cat > preflight-check.sh << 'EOF'
#!/bin/bash
source workshop-env.sh

log_info "Starting pre-flight check..."

# Check AWS CLI
if aws --version >/dev/null 2>&1; then
    log_success "AWS CLI installed: $(aws --version | head -1)"
else
    log_error "AWS CLI not found"
    exit 1
fi

# Check AWS credentials
if aws sts get-caller-identity >/dev/null 2>&1; then
    ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    log_success "AWS credentials valid"
    log_info "Account: $ACCOUNT"
    log_info "User: $USER_ARN"
else
    log_error "AWS credentials invalid or not configured"
    exit 1
fi

# Check region
CURRENT_REGION=$(aws configure get region)
log_info "Current region: $CURRENT_REGION"

# Check VPC quota
VPC_COUNT=$(aws ec2 describe-vpcs --query 'length(Vpcs)')
log_info "Current VPCs: $VPC_COUNT/5"

# Check ECS quota
CLUSTER_COUNT=$(aws ecs list-clusters --query 'length(clusterArns)')
log_info "Current ECS clusters: $CLUSTER_COUNT"

# Check required tools
for tool in jq curl git; do
    if command -v $tool >/dev/null 2>&1; then
        log_success "$tool installed"
    else
        log_warning "$tool not found (recommended)"
    fi
done

log_success "Pre-flight check completed!"
log_info "Ready to start workshop"
EOF

chmod +x preflight-check.sh
./preflight-check.sh
```

## Bước 7: Cost Estimation

### 7.1 Workshop Cost Breakdown

| Service | Resource | Cost/Hour | Duration | Total |
|---------|----------|-----------|----------|-------|
| **VPC** | NAT Gateway (2x) | $0.045 each | 4 hours | $0.36 |
| **ECS** | Fargate vCPU | $0.04048/vCPU | 4 hours | $0.32 |
| **ECS** | Fargate Memory | $0.004445/GB | 4 hours | $0.07 |
| **ALB** | Load Balancer | $0.0225 | 4 hours | $0.09 |
| **Route53** | Hosted Zone | $0.50/month | Prorated | $0.02 |
| **CloudWatch** | Logs | $0.50/GB | Minimal | $0.10 |
| **Data Transfer** | Various | $0.09/GB | Minimal | $0.05 |
| | | | **Total** | **~$1.01** |

{{< alert type="warning" title="Cost Control" >}}
- Workshop cost: $1-2 for 4 hours
- **QUAN TRỌNG:** Chạy cleanup script để tránh chi phí tiếp tục
- Set up billing alerts nếu lo lắng về cost
{{< /alert >}}

### 7.2 Setup Billing Alert

```bash
# Tạo billing alarm (optional)
aws cloudwatch put-metric-alarm \
    --alarm-name "Workshop-Cost-Alert" \
    --alarm-description "Alert when workshop costs exceed $5" \
    --metric-name EstimatedCharges \
    --namespace AWS/Billing \
    --statistic Maximum \
    --period 86400 \
    --threshold 5.0 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=Currency,Value=USD \
    --evaluation-periods 1 \
    --alarm-actions arn:aws:sns:us-east-1:$(aws sts get-caller-identity --query Account --output text):billing-alerts
```

## Troubleshooting

### Common Issues

**1. AWS CLI not configured:**
```bash
aws configure
# Nhập Access Key, Secret Key, Region, Output format
```

**2. Permission denied errors:**
```bash
# Kiểm tra IAM policies
aws iam list-attached-user-policies --user-name $(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2)
```

**3. Region mismatch:**
```bash
# Set consistent region
export AWS_DEFAULT_REGION=us-east-1
aws configure set region us-east-1
```

**4. Service quotas exceeded:**
```bash
# Check service quotas
aws service-quotas get-service-quota --service-code vpc --quota-code L-F678F1CE
```

## Tóm tắt

Bạn đã hoàn thành việc chuẩn bị môi trường với:

- ✅ **AWS Console Access** với proper region
- ✅ **AWS CLI** configured và tested
- ✅ **IAM Permissions** verified
- ✅ **Service Quotas** checked
- ✅ **Required Tools** installed
- ✅ **Working Directory** setup
- ✅ **Cost Estimation** understood

## Bước tiếp theo

Environment đã sẵn sàng! Tiếp theo chúng ta sẽ [xây dựng VPC và ECS Cluster](../3-cluster-setup/).

---

{{< alert type="tip" title="Pro Tip" >}}
Lưu file `workshop-env.sh` và `preflight-check.sh` - bạn sẽ cần chúng trong suốt workshop!
{{< /alert >}}

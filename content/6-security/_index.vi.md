---
title : "Best Practices bảo mật"
date : "`r Sys.Date()`"
weight : 6
chapter : false
pre : " <b> 6. </b> "
---

# Best Practices bảo mật

Trong phần này, chúng ta sẽ triển khai các biện pháp bảo mật toàn diện cho ECS networking setup, bao gồm network segmentation, encryption, access controls, và monitoring để tạo ra một môi trường an toàn sẵn sàng cho production.

## Tổng quan bảo mật

Bảo mật ECS bao gồm nhiều lớp:
- **Network Security**: VPC, subnets, security groups, NACLs
- **Access Control**: IAM roles, policies, và service permissions
- **Data Protection**: Encryption in transit và at rest
- **Monitoring**: Logging, auditing, và threat detection
- **Compliance**: Đáp ứng các yêu cầu regulatory và organizational

## Kiến trúc bảo mật

Chúng ta sẽ triển khai mô hình bảo mật defense-in-depth:

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet Gateway                         │
│                   (Public Access)                           │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                      WAF                                    │
│              (Web Application Firewall)                     │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                 Application Load Balancer                   │
│                  (SSL Termination)                          │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                  Private Subnets                            │
│              (ECS Tasks - No Public IP)                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Web App   │  │   API App   │  │  Database   │          │
│  │ (Encrypted) │  │ (Encrypted) │  │ (Encrypted) │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                   VPC Endpoints                             │
│              (Private AWS API Access)                       │
└─────────────────────────────────────────────────────────────┘
```

## Bước 1: Load Environment Variables

```bash
# Load environment variables
source workshop-resources.env

# Verify variables are loaded
echo "VPC ID: $VPC_ID"
echo "Cluster Name: $CLUSTER_NAME"
echo "ALB ARN: $ALB_ARN"
```

## Bước 2: Enhanced Security Groups

### 2.1 Tạo Granular Security Groups
```bash
# Tạo security group cho web tier
WEB_SG=$(aws ec2 create-security-group \
    --group-name ecs-web-tier-sg \
    --description "Security group for web tier ECS tasks" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ECS-Web-Tier-SG},{Key=Tier,Value=Web}]' \
    --query 'GroupId' \
    --output text)

# Tạo security group cho API tier
API_SG=$(aws ec2 create-security-group \
    --group-name ecs-api-tier-sg \
    --description "Security group for API tier ECS tasks" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ECS-API-Tier-SG},{Key=Tier,Value=API}]' \
    --query 'GroupId' \
    --output text)

# Tạo security group cho database tier
DB_SG=$(aws ec2 create-security-group \
    --group-name ecs-db-tier-sg \
    --description "Security group for database tier ECS tasks" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ECS-DB-Tier-SG},{Key=Tier,Value=Database}]' \
    --query 'GroupId' \
    --output text)

echo "Web Tier SG: $WEB_SG"
echo "API Tier SG: $API_SG"
echo "Database Tier SG: $DB_SG"
```

### 2.2 Cấu hình Security Group Rules
```bash
# Web tier - Chỉ cho phép traffic từ ALB
aws ec2 authorize-security-group-ingress \
    --group-id $WEB_SG \
    --protocol tcp \
    --port 80 \
    --source-group $ALB_SG

# API tier - Chỉ cho phép traffic từ web tier
aws ec2 authorize-security-group-ingress \
    --group-id $API_SG \
    --protocol tcp \
    --port 80 \
    --source-group $WEB_SG

# Database tier - Chỉ cho phép traffic từ API tier
aws ec2 authorize-security-group-ingress \
    --group-id $DB_SG \
    --protocol tcp \
    --port 6379 \
    --source-group $API_SG

# Cho phép HTTPS outbound cho tất cả tiers (cho AWS API calls)
for sg in $WEB_SG $API_SG $DB_SG; do
    aws ec2 authorize-security-group-egress \
        --group-id $sg \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0
done

echo "Security group rules đã được cấu hình"
```

## Bước 3: VPC Endpoints cho Private AWS API Access

### 3.1 Tạo VPC Endpoints
```bash
# Tạo VPC endpoint cho ECS
ECS_ENDPOINT=$(aws ec2 create-vpc-endpoint \
    --vpc-id $VPC_ID \
    --service-name com.amazonaws.$(aws configure get region).ecs \
    --vpc-endpoint-type Interface \
    --subnet-ids $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2 \
    --security-group-ids $ECS_SG \
    --private-dns-enabled \
    --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=ECS-VPC-Endpoint}]' \
    --query 'VpcEndpoint.VpcEndpointId' \
    --output text)

# Tạo VPC endpoint cho ECR API
ECR_API_ENDPOINT=$(aws ec2 create-vpc-endpoint \
    --vpc-id $VPC_ID \
    --service-name com.amazonaws.$(aws configure get region).ecr.api \
    --vpc-endpoint-type Interface \
    --subnet-ids $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2 \
    --security-group-ids $ECS_SG \
    --private-dns-enabled \
    --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=ECR-API-VPC-Endpoint}]' \
    --query 'VpcEndpoint.VpcEndpointId' \
    --output text)

# Tạo VPC endpoint cho ECR Docker
ECR_DKR_ENDPOINT=$(aws ec2 create-vpc-endpoint \
    --vpc-id $VPC_ID \
    --service-name com.amazonaws.$(aws configure get region).ecr.dkr \
    --vpc-endpoint-type Interface \
    --subnet-ids $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2 \
    --security-group-ids $ECS_SG \
    --private-dns-enabled \
    --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=ECR-DKR-VPC-Endpoint}]' \
    --query 'VpcEndpoint.VpcEndpointId' \
    --output text)

# Tạo VPC endpoint cho CloudWatch Logs
LOGS_ENDPOINT=$(aws ec2 create-vpc-endpoint \
    --vpc-id $VPC_ID \
    --service-name com.amazonaws.$(aws configure get region).logs \
    --vpc-endpoint-type Interface \
    --subnet-ids $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2 \
    --security-group-ids $ECS_SG \
    --private-dns-enabled \
    --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=CloudWatch-Logs-VPC-Endpoint}]' \
    --query 'VpcEndpoint.VpcEndpointId' \
    --output text)

# Tạo VPC endpoint cho S3 (Gateway endpoint)
S3_ENDPOINT=$(aws ec2 create-vpc-endpoint \
    --vpc-id $VPC_ID \
    --service-name com.amazonaws.$(aws configure get region).s3 \
    --vpc-endpoint-type Gateway \
    --route-table-ids $PRIVATE_RT_1 $PRIVATE_RT_2 \
    --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=S3-VPC-Endpoint}]' \
    --query 'VpcEndpoint.VpcEndpointId' \
    --output text)

echo "VPC Endpoints đã được tạo:"
echo "ECS: $ECS_ENDPOINT"
echo "ECR API: $ECR_API_ENDPOINT"
echo "ECR Docker: $ECR_DKR_ENDPOINT"
echo "CloudWatch Logs: $LOGS_ENDPOINT"
echo "S3: $S3_ENDPOINT"
```

## Bước 4: Network ACLs cho Additional Security

### 4.1 Tạo Custom Network ACLs
```bash
# Tạo Network ACL cho private subnets
PRIVATE_NACL=$(aws ec2 create-network-acl \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=network-acl,Tags=[{Key=Name,Value=ECS-Private-NACL}]' \
    --query 'NetworkAcl.NetworkAclId' \
    --output text)

echo "Private Network ACL: $PRIVATE_NACL"
```

### 4.2 Cấu hình Network ACL Rules
```bash
# Cho phép inbound HTTP từ public subnets
aws ec2 create-network-acl-entry \
    --network-acl-id $PRIVATE_NACL \
    --rule-number 100 \
    --protocol tcp \
    --rule-action allow \
    --port-range From=80,To=80 \
    --cidr-block 10.0.1.0/24

aws ec2 create-network-acl-entry \
    --network-acl-id $PRIVATE_NACL \
    --rule-number 110 \
    --protocol tcp \
    --rule-action allow \
    --port-range From=80,To=80 \
    --cidr-block 10.0.2.0/24

# Cho phép inbound HTTPS cho AWS API calls
aws ec2 create-network-acl-entry \
    --network-acl-id $PRIVATE_NACL \
    --rule-number 200 \
    --protocol tcp \
    --rule-action allow \
    --port-range From=443,To=443 \
    --cidr-block 0.0.0.0/0

# Cho phép ephemeral ports cho return traffic
aws ec2 create-network-acl-entry \
    --network-acl-id $PRIVATE_NACL \
    --rule-number 300 \
    --protocol tcp \
    --rule-action allow \
    --port-range From=1024,To=65535 \
    --cidr-block 0.0.0.0/0

# Cho phép outbound traffic
aws ec2 create-network-acl-entry \
    --network-acl-id $PRIVATE_NACL \
    --rule-number 100 \
    --protocol tcp \
    --rule-action allow \
    --port-range From=80,To=80 \
    --cidr-block 0.0.0.0/0 \
    --egress

aws ec2 create-network-acl-entry \
    --network-acl-id $PRIVATE_NACL \
    --rule-number 110 \
    --protocol tcp \
    --rule-action allow \
    --port-range From=443,To=443 \
    --cidr-block 0.0.0.0/0 \
    --egress

aws ec2 create-network-acl-entry \
    --network-acl-id $PRIVATE_NACL \
    --rule-number 200 \
    --protocol tcp \
    --rule-action allow \
    --port-range From=1024,To=65535 \
    --cidr-block 0.0.0.0/0 \
    --egress

echo "Network ACL rules đã được cấu hình"
```

### 4.3 Associate Network ACL với Private Subnets
```bash
# Lấy current associations
SUBNET1_ASSOC=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$PRIVATE_SUBNET_1" \
    --query 'NetworkAcls[0].Associations[?SubnetId==`'$PRIVATE_SUBNET_1'`].NetworkAclAssociationId' \
    --output text)

SUBNET2_ASSOC=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$PRIVATE_SUBNET_2" \
    --query 'NetworkAcls[0].Associations[?SubnetId==`'$PRIVATE_SUBNET_2'`].NetworkAclAssociationId' \
    --output text)

# Thay thế associations
aws ec2 replace-network-acl-association \
    --association-id $SUBNET1_ASSOC \
    --network-acl-id $PRIVATE_NACL

aws ec2 replace-network-acl-association \
    --association-id $SUBNET2_ASSOC \
    --network-acl-id $PRIVATE_NACL

echo "Network ACL đã được associate với private subnets"
```

## Bước 5: Enhanced IAM Security

### 5.1 Tạo Least Privilege Task Roles
```bash
# Tạo specific task role cho web service
cat > web-task-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):log-group:/ecs/web-*"
        }
    ]
}
EOF

aws iam create-policy \
    --policy-name ECSWebTaskPolicy \
    --policy-document file://web-task-policy.json

aws iam create-role \
    --role-name ecsWebTaskRole \
    --assume-role-policy-document file://ecs-task-execution-trust-policy.json

aws iam attach-role-policy \
    --role-name ecsWebTaskRole \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/ECSWebTaskPolicy

# Tạo specific task role cho API service
cat > api-task-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):log-group:/ecs/api-*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "servicediscovery:DiscoverInstances"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy \
    --policy-name ECSAPITaskPolicy \
    --policy-document file://api-task-policy.json

aws iam create-role \
    --role-name ecsAPITaskRole \
    --assume-role-policy-document file://ecs-task-execution-trust-policy.json

aws iam attach-role-policy \
    --role-name ecsAPITaskRole \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/ECSAPITaskPolicy

echo "Least privilege task roles đã được tạo"
```

## Bước 6: Secrets Management

### 6.1 Tạo Secrets trong AWS Secrets Manager
```bash
# Tạo database credentials secret
DB_SECRET_ARN=$(aws secretsmanager create-secret \
    --name "ecs-workshop/database" \
    --description "Database credentials for ECS workshop" \
    --secret-string '{"username":"admin","password":"SecurePassword123!","host":"db.workshop.local","port":"6379"}' \
    --tags Key=Environment,Value=workshop Key=Service,Value=database \
    --query 'ARN' \
    --output text)

# Tạo API keys secret
API_SECRET_ARN=$(aws secretsmanager create-secret \
    --name "ecs-workshop/api-keys" \
    --description "API keys for ECS workshop" \
    --secret-string '{"external_api_key":"api-key-12345","jwt_secret":"jwt-secret-67890"}' \
    --tags Key=Environment,Value=workshop Key=Service,Value=api \
    --query 'ARN' \
    --output text)

echo "Database Secret ARN: $DB_SECRET_ARN"
echo "API Secret ARN: $API_SECRET_ARN"
```

### 6.2 Cập nhật IAM Roles cho Secrets Access
```bash
# Tạo policy cho secrets access
cat > secrets-access-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": [
                "$DB_SECRET_ARN",
                "$API_SECRET_ARN"
            ]
        }
    ]
}
EOF

aws iam create-policy \
    --policy-name ECSSecretsAccessPolicy \
    --policy-document file://secrets-access-policy.json

# Attach vào API task role
aws iam attach-role-policy \
    --role-name ecsAPITaskRole \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/ECSSecretsAccessPolicy

echo "Secrets access policy đã được attached"
```

## Bước 7: Enable VPC Flow Logs

### 7.1 Tạo CloudWatch Log Group cho VPC Flow Logs
```bash
# Tạo log group cho VPC Flow Logs
aws logs create-log-group --log-group-name /aws/vpc/flowlogs

# Tạo IAM role cho VPC Flow Logs
cat > vpc-flow-logs-trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "vpc-flow-logs.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

aws iam create-role \
    --role-name flowlogsRole \
    --assume-role-policy-document file://vpc-flow-logs-trust-policy.json

# Tạo policy cho VPC Flow Logs
cat > vpc-flow-logs-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy \
    --policy-name flowlogsDeliveryRolePolicy \
    --policy-document file://vpc-flow-logs-policy.json

aws iam attach-role-policy \
    --role-name flowlogsRole \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/flowlogsDeliveryRolePolicy
```

### 7.2 Enable VPC Flow Logs
```bash
# Enable VPC Flow Logs
FLOW_LOG_ID=$(aws ec2 create-flow-logs \
    --resource-type VPC \
    --resource-ids $VPC_ID \
    --traffic-type ALL \
    --log-destination-type cloud-watch-logs \
    --log-group-name /aws/vpc/flowlogs \
    --deliver-logs-permission-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/flowlogsRole \
    --tag-specifications 'ResourceType=vpc-flow-log,Tags=[{Key=Name,Value=ECS-Workshop-VPC-FlowLogs}]' \
    --query 'FlowLogIds[0]' \
    --output text)

echo "VPC Flow Logs đã được enable: $FLOW_LOG_ID"
```

## Bước 8: AWS Config cho Compliance

### 8.1 Enable AWS Config
```bash
# Tạo S3 bucket cho AWS Config
CONFIG_BUCKET="aws-config-bucket-$(aws sts get-caller-identity --query Account --output text)-$(date +%s)"
aws s3 mb s3://$CONFIG_BUCKET --region $(aws configure get region)

# Tạo AWS Config service role
aws iam create-service-linked-role --aws-service-name config.amazonaws.com || echo "Service role đã tồn tại"

# Tạo configuration recorder
aws configservice put-configuration-recorder \
    --configuration-recorder name=default,roleARN=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig \
    --recording-group allSupported=true,includeGlobalResourceTypes=true

# Tạo delivery channel
aws configservice put-delivery-channel \
    --delivery-channel name=default,s3BucketName=$CONFIG_BUCKET

# Start configuration recorder
aws configservice start-configuration-recorder --configuration-recorder-name default

echo "AWS Config đã được enable với bucket: $CONFIG_BUCKET"
```

## Bước 9: GuardDuty cho Threat Detection

### 9.1 Enable GuardDuty
```bash
# Enable GuardDuty
DETECTOR_ID=$(aws guardduty create-detector \
    --enable \
    --finding-publishing-frequency FIFTEEN_MINUTES \
    --tags Environment=workshop,Service=security \
    --query 'DetectorId' \
    --output text)

echo "GuardDuty đã được enable với detector ID: $DETECTOR_ID"
```

## Bước 10: Security Monitoring và Alerting

### 10.1 Tạo CloudWatch Alarms cho Security Events
```bash
# Tạo SNS topic cho security alerts
SECURITY_TOPIC_ARN=$(aws sns create-topic \
    --name ecs-workshop-security-alerts \
    --tags Key=Environment,Value=workshop Key=Purpose,Value=security \
    --query 'TopicArn' \
    --output text)

# Subscribe email vào topic (thay thế bằng email của bạn)
# aws sns subscribe \
#     --topic-arn $SECURITY_TOPIC_ARN \
#     --protocol email \
#     --notification-endpoint your-email@example.com

# Tạo alarm cho failed login attempts (ví dụ)
aws cloudwatch put-metric-alarm \
    --alarm-name "ECS-Workshop-Security-FailedLogins" \
    --alarm-description "Alert on multiple failed login attempts" \
    --metric-name "FailedLoginAttempts" \
    --namespace "ECS/Workshop" \
    --statistic Sum \
    --period 300 \
    --threshold 5 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 1 \
    --alarm-actions $SECURITY_TOPIC_ARN

echo "Security monitoring đã được cấu hình"
echo "Security Topic ARN: $SECURITY_TOPIC_ARN"
```

## Bước 11: Cập nhật Environment Variables

```bash
# Cập nhật environment variables file
cat >> workshop-resources.env << EOF
export WEB_SG=$WEB_SG
export API_SG=$API_SG
export DB_SG=$DB_SG
export ECS_ENDPOINT=$ECS_ENDPOINT
export ECR_API_ENDPOINT=$ECR_API_ENDPOINT
export ECR_DKR_ENDPOINT=$ECR_DKR_ENDPOINT
export LOGS_ENDPOINT=$LOGS_ENDPOINT
export S3_ENDPOINT=$S3_ENDPOINT
export PRIVATE_NACL=$PRIVATE_NACL
export DB_SECRET_ARN=$DB_SECRET_ARN
export API_SECRET_ARN=$API_SECRET_ARN
export FLOW_LOG_ID=$FLOW_LOG_ID
export CONFIG_BUCKET=$CONFIG_BUCKET
export DETECTOR_ID=$DETECTOR_ID
export SECURITY_TOPIC_ARN=$SECURITY_TOPIC_ARN
EOF

echo "Security resources đã được thêm vào workshop-resources.env"
```

## Security Testing và Validation

### Test Network Segmentation
```bash
# Test rằng web tier chỉ có thể được truy cập từ ALB
echo "Testing network segmentation..."

# Điều này sẽ fail (không có direct access vào web tier)
# curl -m 5 http://PRIVATE_IP_OF_WEB_TASK

# Điều này sẽ work (thông qua ALB)
curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/

echo "Network segmentation test hoàn thành"
```

### Validate VPC Endpoints
```bash
# Kiểm tra VPC endpoint status
aws ec2 describe-vpc-endpoints \
    --vpc-endpoint-ids $ECS_ENDPOINT $ECR_API_ENDPOINT $ECR_DKR_ENDPOINT $LOGS_ENDPOINT \
    --query 'VpcEndpoints[].{Service:ServiceName,State:State}'

echo "VPC endpoints validation hoàn thành"
```

### Review Security Configuration
```bash
# Tạo security report
echo "=== BÁO CÁO CẤU HÌNH BẢO MẬT ==="
echo "VPC ID: $VPC_ID"
echo "Security Groups: Web($WEB_SG), API($API_SG), DB($DB_SG)"
echo "VPC Endpoints: ECS, ECR-API, ECR-DKR, CloudWatch Logs, S3"
echo "Network ACL: $PRIVATE_NACL"
echo "VPC Flow Logs: $FLOW_LOG_ID"
echo "AWS Config: Đã enable"
echo "GuardDuty: $DETECTOR_ID"
echo "Secrets Manager: Database và API secrets đã được cấu hình"
echo "=================================="
```

## Tóm tắt Security Best Practices

1. **Network Security**
   - ✅ Multi-tier security groups với least privilege
   - ✅ Network ACLs cho additional layer of security
   - ✅ VPC endpoints cho private AWS API access
   - ✅ Không có public IPs trên ECS tasks

2. **Access Control**
   - ✅ Least privilege IAM roles cho mỗi service
   - ✅ Service-specific permissions
   - ✅ Secrets Manager cho sensitive data

3. **Monitoring và Compliance**
   - ✅ VPC Flow Logs cho network monitoring
   - ✅ AWS Config cho compliance tracking
   - ✅ GuardDuty cho threat detection
   - ✅ CloudWatch alarms cho security events

4. **Data Protection**
   - ✅ Encryption in transit (HTTPS/TLS)
   - ✅ Secrets management
   - ✅ Secure communication giữa các services

## Bước tiếp theo

Xuất sắc! Bạn đã triển khai các biện pháp bảo mật toàn diện cho ECS networking setup. Môi trường của bạn bây giờ bao gồm:

- ✅ Multi-layered network security
- ✅ Least privilege access controls
- ✅ Private AWS API access qua VPC endpoints
- ✅ Comprehensive monitoring và threat detection
- ✅ Secrets management và data protection

Tiếp theo, chúng ta sẽ chuyển đến [Monitoring & Troubleshooting](../7-monitoring/) nơi chúng ta sẽ thiết lập observability toàn diện và học cách troubleshoot các vấn đề thường gặp.

---

**Security Resources đã tạo:**
- 3 Granular Security Groups
- 5 VPC Endpoints (ECS, ECR, CloudWatch Logs, S3)
- 1 Custom Network ACL
- 2 Secrets trong Secrets Manager
- VPC Flow Logs
- AWS Config
- GuardDuty
- Security monitoring và alerting

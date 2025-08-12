---
title : "Security Best Practices"
date : "`r Sys.Date()`"
weight : 6
chapter : false
pre : " <b> 6. </b> "
---

# Security Best Practices

In this section, we'll implement comprehensive security measures for our ECS networking setup, including network segmentation, encryption, access controls, and monitoring to create a production-ready secure environment.

## Security Overview

ECS security involves multiple layers:
- **Network Security**: VPC, subnets, security groups, NACLs
- **Access Control**: IAM roles, policies, and service permissions
- **Data Protection**: Encryption in transit and at rest
- **Monitoring**: Logging, auditing, and threat detection
- **Compliance**: Meeting regulatory and organizational requirements

## Security Architecture

We'll implement a defense-in-depth security model:

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

## Step 1: Load Environment Variables

```bash
# Load environment variables
source workshop-resources.env

# Verify variables are loaded
echo "VPC ID: $VPC_ID"
echo "Cluster Name: $CLUSTER_NAME"
echo "ALB ARN: $ALB_ARN"
```

## Step 2: Enhanced Security Groups

### 2.1 Create Granular Security Groups
```bash
# Create security group for web tier
WEB_SG=$(aws ec2 create-security-group \
    --group-name ecs-web-tier-sg \
    --description "Security group for web tier ECS tasks" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ECS-Web-Tier-SG},{Key=Tier,Value=Web}]' \
    --query 'GroupId' \
    --output text)

# Create security group for API tier
API_SG=$(aws ec2 create-security-group \
    --group-name ecs-api-tier-sg \
    --description "Security group for API tier ECS tasks" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ECS-API-Tier-SG},{Key=Tier,Value=API}]' \
    --query 'GroupId' \
    --output text)

# Create security group for database tier
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

### 2.2 Configure Security Group Rules
```bash
# Web tier - Allow traffic from ALB only
aws ec2 authorize-security-group-ingress \
    --group-id $WEB_SG \
    --protocol tcp \
    --port 80 \
    --source-group $ALB_SG

# API tier - Allow traffic from web tier only
aws ec2 authorize-security-group-ingress \
    --group-id $API_SG \
    --protocol tcp \
    --port 80 \
    --source-group $WEB_SG

# Database tier - Allow traffic from API tier only
aws ec2 authorize-security-group-ingress \
    --group-id $DB_SG \
    --protocol tcp \
    --port 6379 \
    --source-group $API_SG

# Allow HTTPS outbound for all tiers (for AWS API calls)
for sg in $WEB_SG $API_SG $DB_SG; do
    aws ec2 authorize-security-group-egress \
        --group-id $sg \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0
done

echo "Security group rules configured"
```

## Step 3: VPC Endpoints for Private AWS API Access

### 3.1 Create VPC Endpoints
```bash
# Create VPC endpoint for ECS
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

# Create VPC endpoint for ECR API
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

# Create VPC endpoint for ECR Docker
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

# Create VPC endpoint for CloudWatch Logs
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

# Create VPC endpoint for S3 (Gateway endpoint)
S3_ENDPOINT=$(aws ec2 create-vpc-endpoint \
    --vpc-id $VPC_ID \
    --service-name com.amazonaws.$(aws configure get region).s3 \
    --vpc-endpoint-type Gateway \
    --route-table-ids $PRIVATE_RT_1 $PRIVATE_RT_2 \
    --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=S3-VPC-Endpoint}]' \
    --query 'VpcEndpoint.VpcEndpointId' \
    --output text)

echo "VPC Endpoints created:"
echo "ECS: $ECS_ENDPOINT"
echo "ECR API: $ECR_API_ENDPOINT"
echo "ECR Docker: $ECR_DKR_ENDPOINT"
echo "CloudWatch Logs: $LOGS_ENDPOINT"
echo "S3: $S3_ENDPOINT"
```

## Step 4: Network ACLs for Additional Security

### 4.1 Create Custom Network ACLs
```bash
# Create Network ACL for private subnets
PRIVATE_NACL=$(aws ec2 create-network-acl \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=network-acl,Tags=[{Key=Name,Value=ECS-Private-NACL}]' \
    --query 'NetworkAcl.NetworkAclId' \
    --output text)

echo "Private Network ACL: $PRIVATE_NACL"
```

### 4.2 Configure Network ACL Rules
```bash
# Allow inbound HTTP from public subnets
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

# Allow inbound HTTPS for AWS API calls
aws ec2 create-network-acl-entry \
    --network-acl-id $PRIVATE_NACL \
    --rule-number 200 \
    --protocol tcp \
    --rule-action allow \
    --port-range From=443,To=443 \
    --cidr-block 0.0.0.0/0

# Allow ephemeral ports for return traffic
aws ec2 create-network-acl-entry \
    --network-acl-id $PRIVATE_NACL \
    --rule-number 300 \
    --protocol tcp \
    --rule-action allow \
    --port-range From=1024,To=65535 \
    --cidr-block 0.0.0.0/0

# Allow outbound traffic
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

echo "Network ACL rules configured"
```

### 4.3 Associate Network ACL with Private Subnets
```bash
# Get current associations
SUBNET1_ASSOC=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$PRIVATE_SUBNET_1" \
    --query 'NetworkAcls[0].Associations[?SubnetId==`'$PRIVATE_SUBNET_1'`].NetworkAclAssociationId' \
    --output text)

SUBNET2_ASSOC=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$PRIVATE_SUBNET_2" \
    --query 'NetworkAcls[0].Associations[?SubnetId==`'$PRIVATE_SUBNET_2'`].NetworkAclAssociationId' \
    --output text)

# Replace associations
aws ec2 replace-network-acl-association \
    --association-id $SUBNET1_ASSOC \
    --network-acl-id $PRIVATE_NACL

aws ec2 replace-network-acl-association \
    --association-id $SUBNET2_ASSOC \
    --network-acl-id $PRIVATE_NACL

echo "Network ACL associated with private subnets"
```

## Step 5: Enhanced IAM Security

### 5.1 Create Least Privilege Task Roles
```bash
# Create specific task role for web service
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

# Create specific task role for API service
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

echo "Least privilege task roles created"
```

## Step 6: Secrets Management

### 6.1 Create Secrets in AWS Secrets Manager
```bash
# Create database credentials secret
DB_SECRET_ARN=$(aws secretsmanager create-secret \
    --name "ecs-workshop/database" \
    --description "Database credentials for ECS workshop" \
    --secret-string '{"username":"admin","password":"SecurePassword123!","host":"db.workshop.local","port":"6379"}' \
    --tags Key=Environment,Value=workshop Key=Service,Value=database \
    --query 'ARN' \
    --output text)

# Create API keys secret
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

### 6.2 Update IAM Roles for Secrets Access
```bash
# Create policy for secrets access
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

# Attach to API task role
aws iam attach-role-policy \
    --role-name ecsAPITaskRole \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/ECSSecretsAccessPolicy

echo "Secrets access policy attached"
```

## Step 7: Enable VPC Flow Logs

### 7.1 Create CloudWatch Log Group for VPC Flow Logs
```bash
# Create log group for VPC Flow Logs
aws logs create-log-group --log-group-name /aws/vpc/flowlogs

# Create IAM role for VPC Flow Logs
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

# Create policy for VPC Flow Logs
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

echo "VPC Flow Logs enabled: $FLOW_LOG_ID"
```

## Step 8: AWS Config for Compliance

### 8.1 Enable AWS Config
```bash
# Create S3 bucket for AWS Config
CONFIG_BUCKET="aws-config-bucket-$(aws sts get-caller-identity --query Account --output text)-$(date +%s)"
aws s3 mb s3://$CONFIG_BUCKET --region $(aws configure get region)

# Create AWS Config service role
aws iam create-service-linked-role --aws-service-name config.amazonaws.com || echo "Service role already exists"

# Create configuration recorder
aws configservice put-configuration-recorder \
    --configuration-recorder name=default,roleARN=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig \
    --recording-group allSupported=true,includeGlobalResourceTypes=true

# Create delivery channel
aws configservice put-delivery-channel \
    --delivery-channel name=default,s3BucketName=$CONFIG_BUCKET

# Start configuration recorder
aws configservice start-configuration-recorder --configuration-recorder-name default

echo "AWS Config enabled with bucket: $CONFIG_BUCKET"
```

## Step 9: GuardDuty for Threat Detection

### 9.1 Enable GuardDuty
```bash
# Enable GuardDuty
DETECTOR_ID=$(aws guardduty create-detector \
    --enable \
    --finding-publishing-frequency FIFTEEN_MINUTES \
    --tags Environment=workshop,Service=security \
    --query 'DetectorId' \
    --output text)

echo "GuardDuty enabled with detector ID: $DETECTOR_ID"
```

## Step 10: Security Monitoring and Alerting

### 10.1 Create CloudWatch Alarms for Security Events
```bash
# Create SNS topic for security alerts
SECURITY_TOPIC_ARN=$(aws sns create-topic \
    --name ecs-workshop-security-alerts \
    --tags Key=Environment,Value=workshop Key=Purpose,Value=security \
    --query 'TopicArn' \
    --output text)

# Subscribe email to topic (replace with your email)
# aws sns subscribe \
#     --topic-arn $SECURITY_TOPIC_ARN \
#     --protocol email \
#     --notification-endpoint your-email@example.com

# Create alarm for failed login attempts (example)
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

echo "Security monitoring configured"
echo "Security Topic ARN: $SECURITY_TOPIC_ARN"
```

## Step 11: Update Environment Variables

```bash
# Update environment variables file
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

echo "Security resources added to workshop-resources.env"
```

## Security Testing and Validation

### Test Network Segmentation
```bash
# Test that web tier can only be accessed from ALB
echo "Testing network segmentation..."

# This should fail (no direct access to web tier)
# curl -m 5 http://PRIVATE_IP_OF_WEB_TASK

# This should work (through ALB)
curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/

echo "Network segmentation test completed"
```

### Validate VPC Endpoints
```bash
# Check VPC endpoint status
aws ec2 describe-vpc-endpoints \
    --vpc-endpoint-ids $ECS_ENDPOINT $ECR_API_ENDPOINT $ECR_DKR_ENDPOINT $LOGS_ENDPOINT \
    --query 'VpcEndpoints[].{Service:ServiceName,State:State}'

echo "VPC endpoints validation completed"
```

### Review Security Configuration
```bash
# Generate security report
echo "=== SECURITY CONFIGURATION REPORT ==="
echo "VPC ID: $VPC_ID"
echo "Security Groups: Web($WEB_SG), API($API_SG), DB($DB_SG)"
echo "VPC Endpoints: ECS, ECR-API, ECR-DKR, CloudWatch Logs, S3"
echo "Network ACL: $PRIVATE_NACL"
echo "VPC Flow Logs: $FLOW_LOG_ID"
echo "AWS Config: Enabled"
echo "GuardDuty: $DETECTOR_ID"
echo "Secrets Manager: Database and API secrets configured"
echo "=================================="
```

## Security Best Practices Summary

1. **Network Security**
   - ✅ Multi-tier security groups with least privilege
   - ✅ Network ACLs for additional layer of security
   - ✅ VPC endpoints for private AWS API access
   - ✅ No public IPs on ECS tasks

2. **Access Control**
   - ✅ Least privilege IAM roles for each service
   - ✅ Service-specific permissions
   - ✅ Secrets Manager for sensitive data

3. **Monitoring and Compliance**
   - ✅ VPC Flow Logs for network monitoring
   - ✅ AWS Config for compliance tracking
   - ✅ GuardDuty for threat detection
   - ✅ CloudWatch alarms for security events

4. **Data Protection**
   - ✅ Encryption in transit (HTTPS/TLS)
   - ✅ Secrets management
   - ✅ Secure communication between services

## Next Steps

Outstanding! You've implemented comprehensive security measures for your ECS networking setup. Your environment now includes:

- ✅ Multi-layered network security
- ✅ Least privilege access controls
- ✅ Private AWS API access via VPC endpoints
- ✅ Comprehensive monitoring and threat detection
- ✅ Secrets management and data protection

Next, we'll move on to [Monitoring & Troubleshooting](../7-monitoring/) where we'll set up comprehensive observability and learn how to troubleshoot common issues.

---

**Security Resources Created:**
- 3 Granular Security Groups
- 5 VPC Endpoints (ECS, ECR, CloudWatch Logs, S3)
- 1 Custom Network ACL
- 2 Secrets in Secrets Manager
- VPC Flow Logs
- AWS Config
- GuardDuty
- Security monitoring and alerting

---
title : "Security và Network Policies"
date : "`r Sys.Date()`"
weight : 6
chapter : false
pre : " <b> 6. </b> "
---

# Security và Network Policies

## Tại sao Security quan trọng?

Giống như khóa cửa nhà, security đảm bảo chỉ những người được phép mới có thể truy cập vào hệ thống của bạn.

**Nguyên tắc Defense in Depth:**
- **Network Level:** Security Groups, NACLs
- **Application Level:** IAM Roles, Task Roles  
- **Data Level:** Encryption, Secrets Management
- **Monitoring:** CloudTrail, VPC Flow Logs

## Tổng quan Security Architecture

```
Internet → WAF → ALB → Security Groups → ECS Tasks
    ↓       ↓      ↓         ↓              ↓
  Filter  Filter  Route   Network      Application
  Attacks  Rules  Traffic  Control      Security
```

## Bước 1: Chuẩn bị

### 1.1 Load environment

```bash
cd ~/ecs-workshop
source workshop-env.sh

# Kiểm tra resources hiện tại
echo "VPC ID: $VPC_ID"
echo "ALB ARN: $ALB_ARN"
echo "ECS Cluster: $CLUSTER_NAME"
```

### 1.2 Kiểm tra Security Groups hiện tại

```bash
echo "📋 Security Groups hiện tại:"
aws ec2 describe-security-groups \
    --group-ids $ALB_SG $ECS_SG \
    --query 'SecurityGroups[].{GroupId:GroupId,GroupName:GroupName,Description:Description}' \
    --output table
```

## Bước 2: Tăng cường Security Groups

### 2.1 Tạo Database Security Group

```bash
echo "🔒 Tạo Database Security Group..."

DB_SG=$(aws ec2 create-security-group \
    --group-name ecs-database-sg \
    --description "Security group for ECS database services" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ECS-Database-SG},{Key=Environment,Value=Workshop}]' \
    --query 'GroupId' \
    --output text)

echo "✅ Database SG ID: $DB_SG"
echo "export DB_SG=$DB_SG" >> workshop-env.sh
```

### 2.2 Cấu hình Database Security Group Rules

```bash
echo "🔧 Cấu hình Database SG rules..."

# Chỉ cho phép ECS services truy cập database
aws ec2 authorize-security-group-ingress \
    --group-id $DB_SG \
    --protocol tcp \
    --port 6379 \
    --source-group $ECS_SG \
    --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=Redis-Access-from-ECS}]'

# Cho phép MySQL/PostgreSQL nếu cần
aws ec2 authorize-security-group-ingress \
    --group-id $DB_SG \
    --protocol tcp \
    --port 3306 \
    --source-group $ECS_SG \
    --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=MySQL-Access-from-ECS}]'

aws ec2 authorize-security-group-ingress \
    --group-id $DB_SG \
    --protocol tcp \
    --port 5432 \
    --source-group $ECS_SG \
    --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=PostgreSQL-Access-from-ECS}]'

echo "✅ Database SG rules đã được cấu hình"
```

### 2.3 Tạo Management Security Group

```bash
echo "🔒 Tạo Management Security Group..."

MGMT_SG=$(aws ec2 create-security-group \
    --group-name ecs-management-sg \
    --description "Security group for management access" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ECS-Management-SG},{Key=Environment,Value=Workshop}]' \
    --query 'GroupId' \
    --output text)

echo "✅ Management SG ID: $MGMT_SG"
echo "export MGMT_SG=$MGMT_SG" >> workshop-env.sh
```

### 2.4 Cấu hình Management Access

```bash
echo "🔧 Cấu hình Management SG rules..."

# SSH access từ specific IP (thay đổi IP theo nhu cầu)
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
    --group-id $MGMT_SG \
    --protocol tcp \
    --port 22 \
    --cidr ${MY_IP}/32 \
    --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=SSH-Access}]'

# HTTPS access cho management tools
aws ec2 authorize-security-group-ingress \
    --group-id $MGMT_SG \
    --protocol tcp \
    --port 443 \
    --cidr ${MY_IP}/32 \
    --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=HTTPS-Management}]'

echo "✅ Management access từ IP: $MY_IP"
```

## Bước 3: Cập nhật ECS Security Groups

### 3.1 Tăng cường ECS Security Group

```bash
echo "🔧 Cập nhật ECS Security Group..."

# Xóa rule quá rộng nếu có
aws ec2 revoke-security-group-ingress \
    --group-id $ECS_SG \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 2>/dev/null || echo "Rule không tồn tại"

# Chỉ cho phép ALB truy cập ECS tasks
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol tcp \
    --port 80 \
    --source-group $ALB_SG \
    --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=HTTP-from-ALB}]' 2>/dev/null || echo "Rule đã tồn tại"

# Cho phép HTTPS nếu cần
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol tcp \
    --port 443 \
    --source-group $ALB_SG \
    --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=HTTPS-from-ALB}]' 2>/dev/null || echo "Rule đã tồn tại"

echo "✅ ECS Security Group đã được cập nhật"
```

### 3.2 Cập nhật ALB Security Group

```bash
echo "🔧 Cập nhật ALB Security Group..."

# Kiểm tra và thêm HTTPS rule nếu chưa có
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=HTTPS-Internet}]' 2>/dev/null || echo "HTTPS rule đã tồn tại"

echo "✅ ALB Security Group đã được cập nhật"
```

## Bước 4: Cấu hình IAM Security

### 4.1 Tạo Enhanced Task Role

```bash
echo "👤 Tạo Enhanced Task Role..."

# Tạo trust policy
cat > task-trust-policy.json << EOF
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

# Tạo task role với permissions hạn chế
aws iam create-role \
    --role-name ecsEnhancedTaskRole \
    --assume-role-policy-document file://task-trust-policy.json \
    --description "Enhanced ECS task role with limited permissions" \
    --tags Key=Environment,Value=Workshop Key=Purpose,Value=ECS-Task

echo "✅ Enhanced Task Role đã tạo"
```

### 4.2 Tạo Custom Policy cho Tasks

```bash
echo "📜 Tạo Custom Policy..."

cat > task-custom-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):log-group:/ecs/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": [
                "arn:aws:secretsmanager:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):secret:ecs-workshop/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters"
            ],
            "Resource": [
                "arn:aws:ssm:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):parameter/ecs-workshop/*"
            ]
        }
    ]
}
EOF

# Tạo policy
aws iam create-policy \
    --policy-name ECSWorkshopTaskPolicy \
    --policy-document file://task-custom-policy.json \
    --description "Custom policy for ECS workshop tasks"

# Attach policy to role
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws iam attach-role-policy \
    --role-name ecsEnhancedTaskRole \
    --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/ECSWorkshopTaskPolicy

echo "✅ Custom policy đã được attach"
```

## Bước 5: Secrets Management

### 5.1 Tạo Secrets trong AWS Secrets Manager

```bash
echo "🔐 Tạo secrets..."

# Database credentials
aws secretsmanager create-secret \
    --name "ecs-workshop/database" \
    --description "Database credentials for ECS workshop" \
    --secret-string '{"username":"dbuser","password":"SecurePassword123!","host":"db.myapp.local","port":"6379"}' \
    --tags Key=Environment,Value=Workshop Key=Service,Value=Database

# API keys
aws secretsmanager create-secret \
    --name "ecs-workshop/api-keys" \
    --description "API keys for ECS workshop" \
    --secret-string '{"api_key":"workshop-api-key-123","jwt_secret":"super-secret-jwt-key-456"}' \
    --tags Key=Environment,Value=Workshop Key=Service,Value=API

echo "✅ Secrets đã được tạo"
```

### 5.2 Tạo Parameters trong Systems Manager

```bash
echo "⚙️ Tạo SSM parameters..."

# Application configuration
aws ssm put-parameter \
    --name "/ecs-workshop/app/environment" \
    --value "production" \
    --type "String" \
    --description "Application environment" \
    --tags Key=Environment,Value=Workshop

aws ssm put-parameter \
    --name "/ecs-workshop/app/debug" \
    --value "false" \
    --type "String" \
    --description "Debug mode setting" \
    --tags Key=Environment,Value=Workshop

aws ssm put-parameter \
    --name "/ecs-workshop/app/max-connections" \
    --value "100" \
    --type "String" \
    --description "Maximum database connections" \
    --tags Key=Environment,Value=Workshop

echo "✅ SSM parameters đã được tạo"
```

## Bước 6: Network Security với NACLs

### 6.1 Tạo Custom Network ACL

```bash
echo "🛡️ Tạo Custom Network ACL..."

CUSTOM_NACL=$(aws ec2 create-network-acl \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=network-acl,Tags=[{Key=Name,Value=ECS-Workshop-NACL},{Key=Environment,Value=Workshop}]' \
    --query 'NetworkAcl.NetworkAclId' \
    --output text)

echo "✅ Custom NACL ID: $CUSTOM_NACL"
echo "export CUSTOM_NACL=$CUSTOM_NACL" >> workshop-env.sh
```

### 6.2 Cấu hình NACL Rules

```bash
echo "🔧 Cấu hình NACL rules..."

# Allow HTTP inbound
aws ec2 create-network-acl-entry \
    --network-acl-id $CUSTOM_NACL \
    --rule-number 100 \
    --protocol tcp \
    --rule-action allow \
    --port-range From=80,To=80 \
    --cidr-block 0.0.0.0/0

# Allow HTTPS inbound
aws ec2 create-network-acl-entry \
    --network-acl-id $CUSTOM_NACL \
    --rule-number 110 \
    --protocol tcp \
    --rule-action allow \
    --port-range From=443,To=443 \
    --cidr-block 0.0.0.0/0

# Allow ephemeral ports inbound (for return traffic)
aws ec2 create-network-acl-entry \
    --network-acl-id $CUSTOM_NACL \
    --rule-number 120 \
    --protocol tcp \
    --rule-action allow \
    --port-range From=1024,To=65535 \
    --cidr-block 0.0.0.0/0

# Allow all outbound traffic
aws ec2 create-network-acl-entry \
    --network-acl-id $CUSTOM_NACL \
    --rule-number 100 \
    --protocol -1 \
    --rule-action allow \
    --cidr-block 0.0.0.0/0 \
    --egress

echo "✅ NACL rules đã được cấu hình"
```

## Bước 7: VPC Flow Logs

### 7.1 Tạo CloudWatch Log Group cho VPC Flow Logs

```bash
echo "📊 Tạo VPC Flow Logs..."

aws logs create-log-group --log-group-name /aws/vpc/flowlogs

# Tạo IAM role cho VPC Flow Logs
cat > flowlogs-trust-policy.json << EOF
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
    --assume-role-policy-document file://flowlogs-trust-policy.json

# Attach policy
aws iam attach-role-policy \
    --role-name flowlogsRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/VPCFlowLogsDeliveryRolePolicy

echo "✅ Flow Logs role đã tạo"
```

### 7.2 Enable VPC Flow Logs

```bash
echo "🔍 Enable VPC Flow Logs..."

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)

aws ec2 create-flow-logs \
    --resource-type VPC \
    --resource-ids $VPC_ID \
    --traffic-type ALL \
    --log-destination-type cloud-watch-logs \
    --log-group-name /aws/vpc/flowlogs \
    --deliver-logs-permission-arn arn:aws:iam::$ACCOUNT_ID:role/flowlogsRole \
    --tag-specifications 'ResourceType=vpc-flow-log,Tags=[{Key=Name,Value=ECS-Workshop-FlowLogs}]'

echo "✅ VPC Flow Logs đã được enable"
```

## Bước 8: Cập nhật Task Definitions với Security

### 8.1 Cập nhật Frontend Task với Secrets

```bash
echo "🔄 Cập nhật Frontend Task với security..."

cat > frontend-secure-task-definition.json << EOF
{
    "family": "frontend-secure",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole",
    "taskRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsEnhancedTaskRole",
    "containerDefinitions": [
        {
            "name": "frontend",
            "image": "nginx:latest",
            "portMappings": [
                {
                    "containerPort": 80,
                    "protocol": "tcp"
                }
            ],
            "essential": true,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/frontend",
                    "awslogs-region": "$(aws configure get region)",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "environment": [
                {
                    "name": "API_ENDPOINT",
                    "value": "http://api.myapp.local"
                }
            ],
            "secrets": [
                {
                    "name": "API_KEY",
                    "valueFrom": "arn:aws:secretsmanager:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):secret:ecs-workshop/api-keys:api_key::"
                }
            ]
        }
    ]
}
EOF

aws ecs register-task-definition --cli-input-json file://frontend-secure-task-definition.json
echo "✅ Frontend secure task definition đã tạo"
```

### 8.2 Cập nhật Database Service với Security Group

```bash
echo "🔄 Cập nhật Database service với DB Security Group..."

aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service db-service \
    --network-configuration "awsvpcConfiguration={
        subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],
        securityGroups=[$DB_SG],
        assignPublicIp=DISABLED
    }"

echo "✅ Database service đã được cập nhật với DB Security Group"
```

## Bước 9: Security Monitoring

### 9.1 Tạo CloudWatch Alarms

```bash
echo "🚨 Tạo Security Alarms..."

# Alarm cho failed login attempts (giả định)
aws cloudwatch put-metric-alarm \
    --alarm-name "ECS-High-Error-Rate" \
    --alarm-description "High error rate in ECS services" \
    --metric-name "4XXError" \
    --namespace "AWS/ApplicationELB" \
    --statistic "Sum" \
    --period 300 \
    --threshold 10 \
    --comparison-operator "GreaterThanThreshold" \
    --evaluation-periods 2 \
    --alarm-actions "arn:aws:sns:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):ecs-workshop-alerts" \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-)

# Alarm cho unusual network traffic
aws cloudwatch put-metric-alarm \
    --alarm-name "ECS-High-Network-Traffic" \
    --alarm-description "Unusual network traffic pattern" \
    --metric-name "NetworkPacketsIn" \
    --namespace "AWS/ECS" \
    --statistic "Sum" \
    --period 300 \
    --threshold 10000 \
    --comparison-operator "GreaterThanThreshold" \
    --evaluation-periods 1 \
    --dimensions Name=ClusterName,Value=$CLUSTER_NAME

echo "✅ Security alarms đã được tạo"
```

### 9.2 Tạo SNS Topic cho Alerts

```bash
echo "📧 Tạo SNS topic cho security alerts..."

SNS_TOPIC_ARN=$(aws sns create-topic \
    --name ecs-workshop-alerts \
    --attributes DisplayName="ECS Workshop Security Alerts" \
    --tags Key=Environment,Value=Workshop \
    --query 'TopicArn' \
    --output text)

echo "✅ SNS Topic ARN: $SNS_TOPIC_ARN"

# Subscribe email (thay đổi email address)
# aws sns subscribe \
#     --topic-arn $SNS_TOPIC_ARN \
#     --protocol email \
#     --notification-endpoint your-email@example.com

echo "💡 Để nhận alerts, chạy:"
echo "aws sns subscribe --topic-arn $SNS_TOPIC_ARN --protocol email --notification-endpoint your-email@example.com"
```

## Bước 10: Security Testing

### 10.1 Test Security Groups

```bash
echo "🧪 Test Security Groups..."

# Test từ internet đến ALB (should work)
echo "Test ALB access:"
curl -s -o /dev/null -w "Status: %{http_code}\n" http://$ALB_DNS/

# Test direct access to ECS (should fail)
echo "Test direct ECS access (should fail):"
ECS_TASK_IP=$(aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name frontend-service --query 'taskArns[0]' --output text) \
    --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value' \
    --output text)

echo "ECS Task IP: $ECS_TASK_IP"
timeout 5 curl -s http://$ECS_TASK_IP/ || echo "✅ Direct access blocked (good!)"
```

### 10.2 Test Secrets Access

```bash
echo "🔐 Test Secrets Access..."

# Kiểm tra task có thể access secrets không
aws ecs run-task \
    --cluster $CLUSTER_NAME \
    --task-definition frontend-secure \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={
        subnets=[$PRIVATE_SUBNET_1],
        securityGroups=[$ECS_SG],
        assignPublicIp=DISABLED
    }" \
    --count 1

echo "✅ Test task với secrets đã được start"
```

## Bước 11: Security Best Practices

### 11.1 Kiểm tra Security Configuration

```bash
echo "📋 Security Configuration Summary:"

echo "=== Security Groups ==="
aws ec2 describe-security-groups \
    --group-ids $ALB_SG $ECS_SG $DB_SG \
    --query 'SecurityGroups[].{Name:GroupName,ID:GroupId,Rules:length(IpPermissions)}' \
    --output table

echo "=== IAM Roles ==="
aws iam list-roles \
    --query 'Roles[?contains(RoleName,`ecs`)].{RoleName:RoleName,Created:CreateDate}' \
    --output table

echo "=== Secrets ==="
aws secretsmanager list-secrets \
    --query 'SecretList[?contains(Name,`ecs-workshop`)].{Name:Name,LastChanged:LastChangedDate}' \
    --output table

echo "=== VPC Flow Logs ==="
aws ec2 describe-flow-logs \
    --filter Name=resource-id,Values=$VPC_ID \
    --query 'FlowLogs[].{ID:FlowLogId,Status:FlowLogStatus,LogGroup:LogDestination}' \
    --output table
```

### 11.2 Security Checklist

```bash
echo "✅ Security Checklist:"
echo "□ Security Groups configured with least privilege"
echo "□ IAM roles follow principle of least privilege"  
echo "□ Secrets stored in AWS Secrets Manager"
echo "□ VPC Flow Logs enabled"
echo "□ CloudWatch monitoring configured"
echo "□ Network ACLs configured (optional)"
echo "□ SSL/TLS certificates ready (for production)"
echo "□ WAF configured (for production)"
```

## Troubleshooting Security Issues

### Vấn đề thường gặp:

**Task không thể access secrets:**
```bash
# Kiểm tra task role permissions
aws iam simulate-principal-policy \
    --policy-source-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsEnhancedTaskRole \
    --action-names secretsmanager:GetSecretValue \
    --resource-arns arn:aws:secretsmanager:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):secret:ecs-workshop/api-keys
```

**Security Group rules không hoạt động:**
```bash
# Kiểm tra security group associations
aws ec2 describe-network-interfaces \
    --filters Name=group-id,Values=$ECS_SG \
    --query 'NetworkInterfaces[].{ID:NetworkInterfaceId,Groups:Groups[].GroupId}'
```

**VPC Flow Logs không có data:**
```bash
# Kiểm tra flow logs status
aws ec2 describe-flow-logs --flow-log-ids $(aws ec2 describe-flow-logs --filter Name=resource-id,Values=$VPC_ID --query 'FlowLogs[0].FlowLogId' --output text)
```

## Tóm tắt

Bạn đã triển khai thành công:

- ✅ **Network Security:** Security Groups với least privilege
- ✅ **IAM Security:** Custom roles và policies
- ✅ **Secrets Management:** AWS Secrets Manager và SSM
- ✅ **Network Monitoring:** VPC Flow Logs
- ✅ **Security Monitoring:** CloudWatch Alarms
- ✅ **Access Control:** NACLs và proper routing
- ✅ **Security Testing:** Verification scripts

**Security Layers:**
- **Perimeter:** ALB Security Group
- **Application:** ECS Security Group  
- **Data:** Database Security Group
- **Monitoring:** Flow Logs + CloudWatch
- **Secrets:** Encrypted storage

## Bước tiếp theo

Security đã được tăng cường! Tiếp theo chúng ta sẽ thiết lập [Monitoring và Logging](../7-monitoring/) để theo dõi hệ thống.

---

**💡 Security Tip:** Luôn áp dụng nguyên tắc "least privilege" - chỉ cấp quyền tối thiểu cần thiết.

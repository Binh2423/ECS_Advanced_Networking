---
title : "Security và Monitoring"
date : "2024-08-13"
weight : 6
chapter : false
pre : " <b> 6. </b> "
---

# Security và Monitoring

## Tổng quan

{{< workshop-image src="{{ "images/security-monitoring.png" | absURL }}" alt="Security and Monitoring" caption="Security và monitoring cho ECS infrastructure" >}}

### Chúng ta sẽ cấu hình:

🔒 **IAM Roles và Policies** cho ECS tasks  
📊 **CloudWatch Logs** cho container logs  
📈 **CloudWatch Metrics** cho monitoring  
🛡️ **VPC Flow Logs** cho network monitoring  
🚨 **CloudWatch Alarms** cho alerting  

## Bước 1: IAM Security

### 1.1 Tạo Task Role

{{< console-screenshot src="{{ "images/iam-roles.png" | absURL }}" alt="IAM Roles" caption="IAM Roles cung cấp permissions cho ECS tasks" service="IAM Console" >}}

```bash
# Load environment
source workshop-env.sh

# Tạo task role cho application permissions
cat > ecs-task-role-policy.json << 'EOF'
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

# Tạo task role
aws iam create-role \
    --role-name ecsTaskRole \
    --assume-role-policy-document file://ecs-task-role-policy.json

echo "✅ ECS Task Role created"
```

### 1.2 Tạo Custom Policy

```bash
# Tạo custom policy cho ECS tasks
cat > ecs-task-permissions.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Tạo và attach policy
aws iam create-policy \
    --policy-name ECSTaskCustomPolicy \
    --policy-document file://ecs-task-permissions.json

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws iam attach-role-policy \
    --role-name ecsTaskRole \
    --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/ECSTaskCustomPolicy

echo "✅ Custom IAM policy attached"
```

## Bước 2: CloudWatch Logs

### 2.1 Tạo Log Groups

{{< console-screenshot src="{{ "images/cloudwatch-logs.png" | absURL }}" alt="CloudWatch Logs" caption="CloudWatch Logs thu thập và lưu trữ container logs" service="CloudWatch Console" >}}

```bash
# Tạo log groups cho các services
aws logs create-log-group --log-group-name /ecs/workshop-frontend --retention-in-days 7
aws logs create-log-group --log-group-name /ecs/workshop-backend --retention-in-days 7
aws logs create-log-group --log-group-name /ecs/workshop-monitoring --retention-in-days 7

echo "✅ CloudWatch Log Groups created"
```

### 2.2 Xem Logs

```bash
# Xem recent logs từ frontend service
echo "📋 Recent Frontend Logs:"
aws logs describe-log-streams \
    --log-group-name /ecs/workshop-frontend \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].logStreamName' --output text

# Xem recent logs từ backend service
echo "📋 Recent Backend Logs:"
aws logs describe-log-streams \
    --log-group-name /ecs/workshop-backend \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].logStreamName' --output text

echo "✅ Log streams checked"
```

## Bước 3: VPC Flow Logs

### 3.1 Tạo Flow Logs Role

{{< console-screenshot src="{{ "images/vpc-flow-logs.png" | absURL }}" alt="VPC Flow Logs" caption="VPC Flow Logs monitor network traffic" service="VPC Console" >}}

```bash
# Tạo role cho VPC Flow Logs
cat > vpc-flow-logs-role.json << 'EOF'
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
    --assume-role-policy-document file://vpc-flow-logs-role.json

# Attach policy
aws iam attach-role-policy \
    --role-name flowlogsRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/VPCFlowLogsDeliveryRolePolicy

echo "✅ VPC Flow Logs Role created"
```

### 3.2 Enable VPC Flow Logs

```bash
# Tạo log group cho VPC Flow Logs
aws logs create-log-group --log-group-name /aws/vpc/flowlogs --retention-in-days 7

# Enable VPC Flow Logs
FLOW_LOG_ID=$(aws ec2 create-flow-logs \
    --resource-type VPC \
    --resource-ids $VPC_ID \
    --traffic-type ALL \
    --log-destination-type cloud-watch-logs \
    --log-group-name /aws/vpc/flowlogs \
    --deliver-logs-permission-arn arn:aws:iam::$ACCOUNT_ID:role/flowlogsRole \
    --query 'FlowLogIds[0]' --output text)

echo "✅ VPC Flow Logs enabled: $FLOW_LOG_ID"
echo "export FLOW_LOG_ID=$FLOW_LOG_ID" >> workshop-env.sh
```

## Bước 4: CloudWatch Metrics và Alarms

### 4.1 Tạo Custom Metrics

{{< console-screenshot src="{{ "images/cloudwatch-metrics.png" | absURL }}" alt="CloudWatch Metrics" caption="CloudWatch Metrics hiển thị performance data" service="CloudWatch Console" >}}

```bash
# Tạo custom metric cho ALB
aws cloudwatch put-metric-data \
    --namespace "Workshop/ALB" \
    --metric-data MetricName=CustomHealthCheck,Value=1,Unit=Count

echo "✅ Custom metrics created"
```

### 4.2 Tạo CloudWatch Alarms

```bash
# Alarm cho ALB Target Health
aws cloudwatch put-metric-alarm \
    --alarm-name "ALB-UnhealthyTargets" \
    --alarm-description "Alert when ALB has unhealthy targets" \
    --metric-name UnHealthyHostCount \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 300 \
    --threshold 1 \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --evaluation-periods 2 \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-)

# Alarm cho ECS Service CPU
aws cloudwatch put-metric-alarm \
    --alarm-name "ECS-HighCPU" \
    --alarm-description "Alert when ECS service CPU is high" \
    --metric-name CPUUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=ServiceName,Value=workshop-frontend Name=ClusterName,Value=$CLUSTER_NAME

echo "✅ CloudWatch Alarms created"
```

## Bước 5: Security Groups Audit

### 5.1 Review Security Group Rules

{{< console-screenshot src="{{ "images/security-groups-audit.png" | absURL }}" alt="Security Groups Audit" caption="Audit Security Group rules để đảm bảo security" service="EC2 Console" >}}

```bash
echo "🔍 Security Groups Audit:"
echo "========================="

# ALB Security Group
echo "ALB Security Group ($ALB_SG):"
aws ec2 describe-security-groups --group-ids $ALB_SG \
    --query 'SecurityGroups[0].IpPermissions[*].{Port:FromPort,Protocol:IpProtocol,Source:IpRanges[0].CidrIp}' \
    --output table

# ECS Security Group
echo "ECS Security Group ($ECS_SG):"
aws ec2 describe-security-groups --group-ids $ECS_SG \
    --query 'SecurityGroups[0].IpPermissions[*].{Port:FromPort,Protocol:IpProtocol,Source:UserIdGroupPairs[0].GroupId}' \
    --output table

echo "✅ Security Groups audited"
```

### 5.2 Network ACLs Check

```bash
# Kiểm tra Network ACLs
echo "🔍 Network ACLs Check:"
aws ec2 describe-network-acls --filters Name=vpc-id,Values=$VPC_ID \
    --query 'NetworkAcls[*].{AclId:NetworkAclId,IsDefault:IsDefault}' \
    --output table

echo "✅ Network ACLs checked"
```

## Bước 6: Monitoring Dashboard

### 6.1 Tạo CloudWatch Dashboard

{{< console-screenshot src="{{ "images/cloudwatch-dashboard.png" | absURL }}" alt="CloudWatch Dashboard" caption="CloudWatch Dashboard tổng hợp metrics" service="CloudWatch Console" >}}

```bash
# Tạo dashboard configuration
cat > dashboard-config.json << EOF
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "$(echo $ALB_ARN | cut -d'/' -f2-)"],
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "$(echo $ALB_ARN | cut -d'/' -f2-)"]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "ALB Metrics"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ECS", "CPUUtilization", "ServiceName", "workshop-frontend", "ClusterName", "$CLUSTER_NAME"],
          ["AWS/ECS", "MemoryUtilization", "ServiceName", "workshop-frontend", "ClusterName", "$CLUSTER_NAME"]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "ECS Frontend Metrics"
      }
    }
  ]
}
EOF

# Tạo dashboard
aws cloudwatch put-dashboard \
    --dashboard-name "ECS-Workshop-Dashboard" \
    --dashboard-body file://dashboard-config.json

echo "✅ CloudWatch Dashboard created"
```

## Bước 7: Security Best Practices

### 7.1 Secrets Management

```bash
# Tạo secret trong Secrets Manager (demo)
aws secretsmanager create-secret \
    --name "workshop/database/credentials" \
    --description "Database credentials for workshop" \
    --secret-string '{"username":"admin","password":"temp-password-123"}'

echo "✅ Demo secret created (remember to rotate!)"
```

### 7.2 Container Security Scan

```bash
echo "🔍 Container Security Recommendations:"
echo "======================================"
echo "✅ Use specific image tags (not 'latest')"
echo "✅ Scan images for vulnerabilities"
echo "✅ Use minimal base images"
echo "✅ Run containers as non-root user"
echo "✅ Implement resource limits"
echo "✅ Use read-only root filesystem when possible"
```

## Kiểm tra kết quả

### 7.3 Security và Monitoring Summary

{{< console-screenshot src="{{ "images/monitoring-complete.png" | absURL }}" alt="Monitoring Complete" caption="Monitoring và security infrastructure hoàn chỉnh" service="CloudWatch Console" >}}

```bash
echo "📋 Security & Monitoring Summary:"
echo "================================="
echo "IAM Roles: ecsTaskExecutionRole, ecsTaskRole, flowlogsRole"
echo "CloudWatch Logs: Frontend, Backend, VPC Flow Logs"
echo "CloudWatch Alarms: ALB Health, ECS CPU"
echo "Dashboard: ECS-Workshop-Dashboard"
echo "VPC Flow Logs: $FLOW_LOG_ID"
echo ""
echo "✅ Security & Monitoring setup completed!"
```

{{< alert type="success" title="Hoàn thành!" >}}
🎉 **Security và Monitoring đã sẵn sàng!**  
✅ IAM roles và policies đã cấu hình  
✅ CloudWatch Logs thu thập container logs  
✅ VPC Flow Logs monitor network traffic  
✅ CloudWatch Alarms cho alerting  
✅ Dashboard để monitoring tổng quan  
{{< /alert >}}

## Best Practices Summary

{{< alert type="info" title="Security Best Practices" >}}
🔒 **Principle of Least Privilege** - Chỉ cấp quyền tối thiểu cần thiết  
🔄 **Regular Security Audits** - Kiểm tra security groups và IAM policies  
📊 **Comprehensive Monitoring** - Monitor cả application và infrastructure  
🚨 **Proactive Alerting** - Thiết lập alerts cho các metrics quan trọng  
🔐 **Secrets Management** - Sử dụng AWS Secrets Manager cho sensitive data  
{{< /alert >}}

## Bước tiếp theo

Security và Monitoring đã hoàn tất. Tiếp theo chúng ta sẽ tìm hiểu cách monitor và troubleshoot!

{{< button href="../7-monitoring/" >}}Tiếp theo: Advanced Monitoring →{{< /button >}}

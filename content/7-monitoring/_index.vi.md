---
title : "Monitoring & Troubleshooting"
date : "`r Sys.Date()`"
weight : 7
chapter : false
pre : " <b> 7. </b> "
---

# Monitoring & Troubleshooting

Trong phần này, chúng ta sẽ triển khai monitoring và observability toàn diện cho ECS networking setup, học cách troubleshoot các vấn đề thường gặp, và thiết lập alerting cho việc phát hiện vấn đề proactive.

## Tổng quan Monitoring

Monitoring hiệu quả cho ECS networking bao gồm nhiều lớp:
- **Infrastructure Monitoring**: VPC, subnets, load balancers, NAT gateways
- **Application Monitoring**: ECS services, tasks, containers
- **Network Monitoring**: Traffic flows, connectivity, performance
- **Security Monitoring**: Access patterns, threats, compliance
- **Cost Monitoring**: Resource utilization và optimization

## Kiến trúc Monitoring

Chúng ta sẽ triển khai monitoring stack toàn diện:

```
┌─────────────────────────────────────────────────────────────┐
│                    CloudWatch Dashboard                     │
│              (Centralized Monitoring View)                  │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                  CloudWatch Metrics                         │
│        (ECS, ALB, VPC, Custom Application Metrics)          │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                  CloudWatch Logs                            │
│         (Application Logs, VPC Flow Logs, ALB Logs)         │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                  CloudWatch Alarms                          │
│              (Proactive Alert System)                       │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                      SNS Topics                             │
│              (Notification Distribution)                    │
└─────────────────────────────────────────────────────────────┘
```

## Bước 1: Load Environment Variables

```bash
# Load environment variables
source workshop-resources.env

# Verify variables are loaded
echo "VPC ID: $VPC_ID"
echo "Cluster Name: $CLUSTER_NAME"
echo "ALB DNS: $ALB_DNS"
```

## Bước 2: Enhanced CloudWatch Logging

### 2.1 Tạo Log Groups cho Different Components
```bash
# Tạo log groups cho different tiers
aws logs create-log-group --log-group-name /ecs/workshop/web-tier
aws logs create-log-group --log-group-name /ecs/workshop/api-tier
aws logs create-log-group --log-group-name /ecs/workshop/db-tier
aws logs create-log-group --log-group-name /aws/applicationloadbalancer/ecs-workshop

# Đặt retention policies
aws logs put-retention-policy --log-group-name /ecs/workshop/web-tier --retention-in-days 30
aws logs put-retention-policy --log-group-name /ecs/workshop/api-tier --retention-in-days 30
aws logs put-retention-policy --log-group-name /ecs/workshop/db-tier --retention-in-days 30
aws logs put-retention-policy --log-group-name /aws/applicationloadbalancer/ecs-workshop --retention-in-days 7

echo "Enhanced log groups đã được tạo với retention policies"
```

### 2.2 Enable ALB Access Logs
```bash
# Tạo S3 bucket cho ALB access logs
ALB_LOGS_BUCKET="ecs-workshop-alb-logs-$(aws sts get-caller-identity --query Account --output text)-$(date +%s)"
aws s3 mb s3://$ALB_LOGS_BUCKET --region $(aws configure get region)

# Tạo bucket policy cho ALB access logs
cat > alb-logs-bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::033677994240:root"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::$ALB_LOGS_BUCKET/AWSLogs/$(aws sts get-caller-identity --query Account --output text)/*"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::$ALB_LOGS_BUCKET/AWSLogs/$(aws sts get-caller-identity --query Account --output text)/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::$ALB_LOGS_BUCKET"
        }
    ]
}
EOF

aws s3api put-bucket-policy --bucket $ALB_LOGS_BUCKET --policy file://alb-logs-bucket-policy.json

# Enable ALB access logs
aws elbv2 modify-load-balancer-attributes \
    --load-balancer-arn $ALB_ARN \
    --attributes Key=access_logs.s3.enabled,Value=true \
              Key=access_logs.s3.bucket,Value=$ALB_LOGS_BUCKET \
              Key=access_logs.s3.prefix,Value=alb-logs

echo "ALB access logs đã được enable vào S3 bucket: $ALB_LOGS_BUCKET"
```

## Bước 3: Custom CloudWatch Metrics

### 3.1 Tạo Custom Metrics cho Application Performance
```bash
# Tạo custom namespace cho application metrics
NAMESPACE="ECS/Workshop"

# Ví dụ: Put custom metric cho application response time
aws cloudwatch put-metric-data \
    --namespace $NAMESPACE \
    --metric-data MetricName=ResponseTime,Value=150,Unit=Milliseconds,Dimensions=Service=web-service,Environment=workshop

# Ví dụ: Put custom metric cho database connections
aws cloudwatch put-metric-data \
    --namespace $NAMESPACE \
    --metric-data MetricName=DatabaseConnections,Value=5,Unit=Count,Dimensions=Service=api-service,Environment=workshop

echo "Custom metrics đã được publish vào CloudWatch"
```

## Bước 4: CloudWatch Dashboards

### 4.1 Tạo Comprehensive Dashboard
```bash
# Tạo CloudWatch dashboard
cat > dashboard-body.json << EOF
{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ECS", "CPUUtilization", "ServiceName", "web-service", "ClusterName", "$CLUSTER_NAME" ],
                    [ ".", "MemoryUtilization", ".", ".", ".", "." ],
                    [ ".", "CPUUtilization", "ServiceName", "api-service", "ClusterName", "$CLUSTER_NAME" ],
                    [ ".", "MemoryUtilization", ".", ".", ".", "." ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$(aws configure get region)",
                "title": "ECS Service Resource Utilization",
                "period": 300
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "$(echo $ALB_ARN | cut -d'/' -f2-)" ],
                    [ ".", "TargetResponseTime", ".", "." ],
                    [ ".", "HTTPCode_Target_2XX_Count", ".", "." ],
                    [ ".", "HTTPCode_Target_4XX_Count", ".", "." ],
                    [ ".", "HTTPCode_Target_5XX_Count", ".", "." ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$(aws configure get region)",
                "title": "Application Load Balancer Metrics",
                "period": 300
            }
        }
    ]
}
EOF

# Tạo dashboard
aws cloudwatch put-dashboard \
    --dashboard-name "ECS-Workshop-Monitoring" \
    --dashboard-body file://dashboard-body.json

echo "CloudWatch dashboard đã được tạo: ECS-Workshop-Monitoring"
```

## Bước 5: CloudWatch Alarms

### 5.1 Tạo Alarms cho ECS Services
```bash
# Tạo SNS topic cho alerts
ALERT_TOPIC_ARN=$(aws sns create-topic \
    --name ecs-workshop-alerts \
    --tags Key=Environment,Value=workshop Key=Purpose,Value=monitoring \
    --query 'TopicArn' \
    --output text)

# High CPU utilization alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ECS-Workshop-HighCPU" \
    --alarm-description "ECS service high CPU utilization" \
    --metric-name CPUUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=ServiceName,Value=web-service Name=ClusterName,Value=$CLUSTER_NAME \
    --evaluation-periods 2 \
    --alarm-actions $ALERT_TOPIC_ARN

# High memory utilization alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ECS-Workshop-HighMemory" \
    --alarm-description "ECS service high memory utilization" \
    --metric-name MemoryUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 300 \
    --threshold 85 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=ServiceName,Value=web-service Name=ClusterName,Value=$CLUSTER_NAME \
    --evaluation-periods 2 \
    --alarm-actions $ALERT_TOPIC_ARN

echo "ECS service alarms đã được tạo"
```

### 5.2 Tạo Alarms cho Load Balancer
```bash
# ALB high response time alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ALB-Workshop-HighResponseTime" \
    --alarm-description "ALB high response time" \
    --metric-name TargetResponseTime \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 300 \
    --threshold 1.0 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-) \
    --evaluation-periods 2 \
    --alarm-actions $ALERT_TOPIC_ARN

# ALB high 5xx error rate alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ALB-Workshop-High5xxErrors" \
    --alarm-description "ALB high 5xx error rate" \
    --metric-name HTTPCode_Target_5XX_Count \
    --namespace AWS/ApplicationELB \
    --statistic Sum \
    --period 300 \
    --threshold 10 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-) \
    --evaluation-periods 1 \
    --alarm-actions $ALERT_TOPIC_ARN

echo "ALB alarms đã được tạo"
```

## Bước 6: Network Monitoring

### 6.1 VPC Flow Logs Analysis
```bash
# Tạo CloudWatch Insights queries cho VPC Flow Logs analysis
echo "VPC Flow Logs Analysis Queries:"

echo "1. Top talkers by bytes:"
echo "fields @timestamp, srcaddr, dstaddr, bytes"
echo "| filter bytes > 1000"
echo "| stats sum(bytes) as total_bytes by srcaddr, dstaddr"
echo "| sort total_bytes desc"
echo "| limit 10"

echo ""
echo "2. Rejected connections:"
echo "fields @timestamp, srcaddr, dstaddr, srcport, dstport, action"
echo "| filter action = \"REJECT\""
echo "| stats count() as rejected_count by srcaddr, dstaddr, dstport"
echo "| sort rejected_count desc"

echo ""
echo "3. Traffic by protocol:"
echo "fields @timestamp, protocol, bytes"
echo "| stats sum(bytes) as total_bytes by protocol"
echo "| sort total_bytes desc"
```

## Bước 7: Troubleshooting Guide

### Các vấn đề ECS Networking thường gặp

#### 1. Service Discovery không hoạt động
**Triệu chứng**: Services không thể resolve nhau qua DNS names

**Các bước Troubleshooting**:
```bash
# Kiểm tra service discovery configuration
aws servicediscovery get-service --id $WEB_SERVICE_ID

# Kiểm tra nếu instances được registered
aws servicediscovery list-instances --service-id $WEB_SERVICE_ID

# Test DNS resolution từ trong task
# nslookup web.workshop.local
```

**Nguyên nhân thường gặp**:
- VPC DNS resolution không được enable
- Service registry misconfiguration
- Network connectivity issues

#### 2. Load Balancer Health Check Failures
**Triệu chứng**: Targets hiển thị unhealthy trong target groups

**Các bước Troubleshooting**:
```bash
# Kiểm tra target health
aws elbv2 describe-target-health --target-group-arn $WEB_TG_ARN

# Kiểm tra security group rules
aws ec2 describe-security-groups --group-ids $ECS_SG

# Kiểm tra health check configuration
aws elbv2 describe-target-groups --target-group-arns $WEB_TG_ARN
```

**Nguyên nhân thường gặp**:
- Security group blocking health check traffic
- Application không respond trên health check path
- Health check timeout quá ngắn

#### 3. Tasks không thể Pull Images
**Triệu chứng**: Tasks fail to start với image pull errors

**Các bước Troubleshooting**:
```bash
# Kiểm tra VPC endpoints
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $ECR_API_ENDPOINT $ECR_DKR_ENDPOINT

# Kiểm tra NAT Gateway connectivity
aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_1

# Kiểm tra task execution role permissions
aws iam get-role --role-name ecsTaskExecutionRole
```

**Nguyên nhân thường gặp**:
- Missing VPC endpoints cho ECR
- NAT Gateway issues
- Insufficient IAM permissions

## Bước 8: Cập nhật Environment Variables

```bash
# Cập nhật environment variables file
cat >> workshop-resources.env << EOF
export ALB_LOGS_BUCKET=$ALB_LOGS_BUCKET
export ALERT_TOPIC_ARN=$ALERT_TOPIC_ARN
export NAMESPACE=$NAMESPACE
EOF

echo "Monitoring resources đã được thêm vào workshop-resources.env"
```

## Best Practices Monitoring

1. **Thiết lập Comprehensive Dashboards**
   - Bao gồm infrastructure, application, và business metrics
   - Sử dụng time ranges và aggregations phù hợp
   - Tạo role-based dashboards

2. **Triển khai Effective Alerting**
   - Đặt meaningful thresholds dựa trên baselines
   - Sử dụng composite alarms cho complex conditions
   - Triển khai escalation procedures

3. **Log Management**
   - Sử dụng structured logging
   - Đặt appropriate retention policies
   - Triển khai log aggregation và analysis

4. **Performance Monitoring**
   - Monitor key performance indicators (KPIs)
   - Thiết lập synthetic monitoring
   - Track user experience metrics

## Bước tiếp theo

Tuyệt vời! Bạn đã triển khai comprehensive monitoring và troubleshooting capabilities cho ECS networking setup. Monitoring stack của bạn bây giờ bao gồm:

- ✅ Enhanced CloudWatch logging và metrics
- ✅ Custom dashboards cho visualization
- ✅ Proactive alerting system
- ✅ Network performance monitoring
- ✅ Cost monitoring và optimization
- ✅ Troubleshooting guides và procedures

Cuối cùng, hãy chuyển đến [Dọn dẹp tài nguyên](../8-cleanup/) nơi chúng ta sẽ properly clean up tất cả resources đã tạo để tránh ongoing charges.

---

**Monitoring Resources đã tạo:**
- Enhanced CloudWatch log groups với retention policies
- ALB access logs vào S3
- Custom CloudWatch dashboard
- 8+ CloudWatch alarms cho proactive monitoring
- SNS topic cho alert notifications
- VPC Flow Logs analysis queries
- Cost monitoring alarms

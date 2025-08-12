---
title : "Monitoring & Troubleshooting"
date : "`r Sys.Date()`"
weight : 7
chapter : false
pre : " <b> 7. </b> "
---

# Monitoring & Troubleshooting

In this section, we'll implement comprehensive monitoring and observability for our ECS networking setup, learn how to troubleshoot common issues, and set up alerting for proactive problem detection.

## Monitoring Overview

Effective monitoring for ECS networking involves multiple layers:
- **Infrastructure Monitoring**: VPC, subnets, load balancers, NAT gateways
- **Application Monitoring**: ECS services, tasks, containers
- **Network Monitoring**: Traffic flows, connectivity, performance
- **Security Monitoring**: Access patterns, threats, compliance
- **Cost Monitoring**: Resource utilization and optimization

## Monitoring Architecture

We'll implement a comprehensive monitoring stack:

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

## Step 1: Load Environment Variables

```bash
# Load environment variables
source workshop-resources.env

# Verify variables are loaded
echo "VPC ID: $VPC_ID"
echo "Cluster Name: $CLUSTER_NAME"
echo "ALB DNS: $ALB_DNS"
```

## Step 2: Enhanced CloudWatch Logging

### 2.1 Create Log Groups for Different Components
```bash
# Create log groups for different tiers
aws logs create-log-group --log-group-name /ecs/workshop/web-tier
aws logs create-log-group --log-group-name /ecs/workshop/api-tier
aws logs create-log-group --log-group-name /ecs/workshop/db-tier
aws logs create-log-group --log-group-name /aws/applicationloadbalancer/ecs-workshop

# Set retention policies
aws logs put-retention-policy --log-group-name /ecs/workshop/web-tier --retention-in-days 30
aws logs put-retention-policy --log-group-name /ecs/workshop/api-tier --retention-in-days 30
aws logs put-retention-policy --log-group-name /ecs/workshop/db-tier --retention-in-days 30
aws logs put-retention-policy --log-group-name /aws/applicationloadbalancer/ecs-workshop --retention-in-days 7

echo "Enhanced log groups created with retention policies"
```

### 2.2 Enable ALB Access Logs
```bash
# Create S3 bucket for ALB access logs
ALB_LOGS_BUCKET="ecs-workshop-alb-logs-$(aws sts get-caller-identity --query Account --output text)-$(date +%s)"
aws s3 mb s3://$ALB_LOGS_BUCKET --region $(aws configure get region)

# Get ELB service account ID for the region
ELB_ACCOUNT_ID=$(aws elbv2 describe-account-attributes --attribute-names access-logs.s3.enabled --query 'AccountAttributes[0].AttributeValue' --output text)

# Create bucket policy for ALB access logs
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

echo "ALB access logs enabled to S3 bucket: $ALB_LOGS_BUCKET"
```

## Step 3: Custom CloudWatch Metrics

### 3.1 Create Custom Metrics for Application Performance
```bash
# Create custom namespace for application metrics
NAMESPACE="ECS/Workshop"

# Example: Put custom metric for application response time
aws cloudwatch put-metric-data \
    --namespace $NAMESPACE \
    --metric-data MetricName=ResponseTime,Value=150,Unit=Milliseconds,Dimensions=Service=web-service,Environment=workshop

# Example: Put custom metric for database connections
aws cloudwatch put-metric-data \
    --namespace $NAMESPACE \
    --metric-data MetricName=DatabaseConnections,Value=5,Unit=Count,Dimensions=Service=api-service,Environment=workshop

echo "Custom metrics published to CloudWatch"
```

### 3.2 Create CloudWatch Agent Configuration
```bash
# Create CloudWatch agent configuration for detailed monitoring
cat > cloudwatch-agent-config.json << EOF
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "namespace": "ECS/Workshop/DetailedMonitoring",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/ecs/workshop/system",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    }
}
EOF

echo "CloudWatch agent configuration created"
```

## Step 4: CloudWatch Dashboards

### 4.1 Create Comprehensive Dashboard
```bash
# Create CloudWatch dashboard
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
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ECS", "RunningTaskCount", "ServiceName", "web-service", "ClusterName", "$CLUSTER_NAME" ],
                    [ ".", ".", "ServiceName", "api-service", "ClusterName", "$CLUSTER_NAME" ],
                    [ ".", ".", "ServiceName", "db-service", "ClusterName", "$CLUSTER_NAME" ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$(aws configure get region)",
                "title": "ECS Running Tasks",
                "period": 300
            }
        },
        {
            "type": "log",
            "x": 12,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "query": "SOURCE '/ecs/web-app' | fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 20",
                "region": "$(aws configure get region)",
                "title": "Recent Application Errors",
                "view": "table"
            }
        }
    ]
}
EOF

# Create the dashboard
aws cloudwatch put-dashboard \
    --dashboard-name "ECS-Workshop-Monitoring" \
    --dashboard-body file://dashboard-body.json

echo "CloudWatch dashboard created: ECS-Workshop-Monitoring"
```

## Step 5: CloudWatch Alarms

### 5.1 Create Alarms for ECS Services
```bash
# Create SNS topic for alerts
ALERT_TOPIC_ARN=$(aws sns create-topic \
    --name ecs-workshop-alerts \
    --tags Key=Environment,Value=workshop Key=Purpose,Value=monitoring \
    --query 'TopicArn' \
    --output text)

# Subscribe email to topic (replace with your email)
# aws sns subscribe \
#     --topic-arn $ALERT_TOPIC_ARN \
#     --protocol email \
#     --notification-endpoint your-email@example.com

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

# Service task count alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ECS-Workshop-LowTaskCount" \
    --alarm-description "ECS service running fewer tasks than desired" \
    --metric-name RunningTaskCount \
    --namespace AWS/ECS \
    --statistic Average \
    --period 300 \
    --threshold 1 \
    --comparison-operator LessThanThreshold \
    --dimensions Name=ServiceName,Value=web-service Name=ClusterName,Value=$CLUSTER_NAME \
    --evaluation-periods 1 \
    --alarm-actions $ALERT_TOPIC_ARN

echo "ECS service alarms created"
```

### 5.2 Create Alarms for Load Balancer
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

# ALB unhealthy target alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ALB-Workshop-UnhealthyTargets" \
    --alarm-description "ALB has unhealthy targets" \
    --metric-name UnHealthyHostCount \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 300 \
    --threshold 0 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=TargetGroup,Value=$(echo $WEB_TG_ARN | cut -d'/' -f2-) \
    --evaluation-periods 1 \
    --alarm-actions $ALERT_TOPIC_ARN

echo "ALB alarms created"
```

## Step 6: Network Monitoring

### 6.1 VPC Flow Logs Analysis
```bash
# Create CloudWatch Insights queries for VPC Flow Logs analysis
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

### 6.2 Create Network Performance Alarms
```bash
# NAT Gateway high bandwidth utilization
aws cloudwatch put-metric-alarm \
    --alarm-name "NAT-Gateway-HighBandwidth" \
    --alarm-description "NAT Gateway high bandwidth utilization" \
    --metric-name BytesOutToDestination \
    --namespace AWS/NATGateway \
    --statistic Sum \
    --period 300 \
    --threshold 1000000000 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=NatGatewayId,Value=$NAT_GW_1 \
    --evaluation-periods 2 \
    --alarm-actions $ALERT_TOPIC_ARN

# VPC endpoint connection errors
aws cloudwatch put-metric-alarm \
    --alarm-name "VPC-Endpoint-Errors" \
    --alarm-description "VPC endpoint connection errors" \
    --metric-name ErrorCount \
    --namespace AWS/VpcEndpoint \
    --statistic Sum \
    --period 300 \
    --threshold 5 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=VpcEndpointId,Value=$ECS_ENDPOINT \
    --evaluation-periods 1 \
    --alarm-actions $ALERT_TOPIC_ARN

echo "Network performance alarms created"
```

## Step 7: Application Performance Monitoring (APM)

### 7.1 Enable X-Ray Tracing
```bash
# Create X-Ray service map
aws xray create-service-map \
    --service-map-name "ECS-Workshop-ServiceMap" \
    --tags Key=Environment,Value=workshop

# Enable X-Ray tracing for ECS services (requires application code changes)
echo "To enable X-Ray tracing, add the following to your task definitions:"
echo "{"
echo "  \"name\": \"xray-daemon\","
echo "  \"image\": \"amazon/aws-xray-daemon:latest\","
echo "  \"cpu\": 32,"
echo "  \"memoryReservation\": 256,"
echo "  \"portMappings\": ["
echo "    {"
echo "      \"containerPort\": 2000,"
echo "      \"protocol\": \"udp\""
echo "    }"
echo "  ]"
echo "}"

echo "X-Ray setup information provided"
```

## Step 8: Cost Monitoring

### 8.1 Create Cost Alarms
```bash
# Create billing alarm (requires billing metrics to be enabled)
aws cloudwatch put-metric-alarm \
    --alarm-name "ECS-Workshop-CostAlert" \
    --alarm-description "Alert when workshop costs exceed threshold" \
    --metric-name EstimatedCharges \
    --namespace AWS/Billing \
    --statistic Maximum \
    --period 86400 \
    --threshold 50 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=Currency,Value=USD \
    --evaluation-periods 1 \
    --alarm-actions $ALERT_TOPIC_ARN

echo "Cost monitoring alarm created"
```

## Step 9: Update Environment Variables

```bash
# Update environment variables file
cat >> workshop-resources.env << EOF
export ALB_LOGS_BUCKET=$ALB_LOGS_BUCKET
export ALERT_TOPIC_ARN=$ALERT_TOPIC_ARN
export NAMESPACE=$NAMESPACE
EOF

echo "Monitoring resources added to workshop-resources.env"
```

## Troubleshooting Guide

### Common ECS Networking Issues

#### 1. Service Discovery Not Working
**Symptoms**: Services cannot resolve each other via DNS names

**Troubleshooting Steps**:
```bash
# Check service discovery configuration
aws servicediscovery get-service --id $WEB_SERVICE_ID

# Check if instances are registered
aws servicediscovery list-instances --service-id $WEB_SERVICE_ID

# Test DNS resolution from within a task
# aws ecs execute-command --cluster $CLUSTER_NAME --task TASK_ARN --container CONTAINER_NAME --interactive --command "/bin/bash"
# nslookup web.workshop.local
```

**Common Causes**:
- VPC DNS resolution not enabled
- Service registry misconfiguration
- Network connectivity issues

#### 2. Load Balancer Health Check Failures
**Symptoms**: Targets showing as unhealthy in target groups

**Troubleshooting Steps**:
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn $WEB_TG_ARN

# Check security group rules
aws ec2 describe-security-groups --group-ids $ECS_SG

# Check health check configuration
aws elbv2 describe-target-groups --target-group-arns $WEB_TG_ARN
```

**Common Causes**:
- Security group blocking health check traffic
- Application not responding on health check path
- Health check timeout too short

#### 3. Tasks Cannot Pull Images
**Symptoms**: Tasks fail to start with image pull errors

**Troubleshooting Steps**:
```bash
# Check VPC endpoints
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $ECR_API_ENDPOINT $ECR_DKR_ENDPOINT

# Check NAT Gateway connectivity
aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_1

# Check task execution role permissions
aws iam get-role --role-name ecsTaskExecutionRole
```

**Common Causes**:
- Missing VPC endpoints for ECR
- NAT Gateway issues
- Insufficient IAM permissions

#### 4. High Network Latency
**Symptoms**: Slow response times between services

**Troubleshooting Steps**:
```bash
# Check VPC Flow Logs for network patterns
aws logs start-query \
    --log-group-name /aws/vpc/flowlogs \
    --start-time $(date -d '1 hour ago' +%s) \
    --end-time $(date +%s) \
    --query-string 'fields @timestamp, srcaddr, dstaddr, bytes | filter bytes > 1000 | sort @timestamp desc'

# Monitor ALB metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name TargetResponseTime \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-) \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average
```

**Common Causes**:
- Cross-AZ traffic
- Network congestion
- Application performance issues

### Monitoring Best Practices

1. **Set Up Comprehensive Dashboards**
   - Include infrastructure, application, and business metrics
   - Use appropriate time ranges and aggregations
   - Create role-based dashboards

2. **Implement Effective Alerting**
   - Set meaningful thresholds based on baselines
   - Use composite alarms for complex conditions
   - Implement escalation procedures

3. **Log Management**
   - Use structured logging
   - Set appropriate retention policies
   - Implement log aggregation and analysis

4. **Performance Monitoring**
   - Monitor key performance indicators (KPIs)
   - Set up synthetic monitoring
   - Track user experience metrics

## Next Steps

Excellent! You've implemented comprehensive monitoring and troubleshooting capabilities for your ECS networking setup. Your monitoring stack now includes:

- ✅ Enhanced CloudWatch logging and metrics
- ✅ Custom dashboards for visualization
- ✅ Proactive alerting system
- ✅ Network performance monitoring
- ✅ Cost monitoring and optimization
- ✅ Troubleshooting guides and procedures

Finally, let's move on to [Clean up Resources](../8-cleanup/) where we'll properly clean up all the resources we've created to avoid ongoing charges.

---

**Monitoring Resources Created:**
- Enhanced CloudWatch log groups with retention policies
- ALB access logs to S3
- Custom CloudWatch dashboard
- 8+ CloudWatch alarms for proactive monitoring
- SNS topic for alert notifications
- VPC Flow Logs analysis queries
- Cost monitoring alarms

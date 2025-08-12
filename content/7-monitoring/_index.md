---
title : "Monitoring và Logging"
date : "`r Sys.Date()`"
weight : 7
chapter : false
pre : " <b> 7. </b> "
---

# Monitoring và Logging

## Tại sao Monitoring quan trọng?

Monitoring giống như bảng điều khiển xe hơi - giúp bạn biết hệ thống đang hoạt động như thế nào và cảnh báo khi có vấn đề.

**Lợi ích:**
- **Proactive:** Phát hiện vấn đề trước khi user phàn nàn
- **Performance:** Tối ưu hóa hiệu suất dựa trên data
- **Troubleshooting:** Nhanh chóng tìm ra nguyên nhân sự cố
- **Capacity Planning:** Dự đoán nhu cầu tài nguyên

## Monitoring Stack Overview

```
Applications → CloudWatch → Dashboards
     ↓             ↓           ↓
   Logs        Metrics     Alerts
     ↓             ↓           ↓
 Log Groups   Custom      SNS
              Metrics   Notifications
```

## Bước 1: Chuẩn bị

### 1.1 Load environment

```bash
cd ~/ecs-workshop
source workshop-env.sh

# Kiểm tra resources
echo "Cluster: $CLUSTER_NAME"
echo "ALB ARN: $ALB_ARN"
echo "Services: frontend-service, api-service, db-service"
```

### 1.2 Kiểm tra Log Groups hiện tại

```bash
echo "📋 Log Groups hiện tại:"
aws logs describe-log-groups \
    --log-group-name-prefix "/ecs/" \
    --query 'logGroups[].{Name:logGroupName,Size:storedBytes,Retention:retentionInDays}' \
    --output table
```

## Bước 2: Cấu hình CloudWatch Logs

### 2.1 Tạo thêm Log Groups

```bash
echo "📝 Tạo thêm Log Groups..."

# Application logs
aws logs create-log-group --log-group-name /ecs/application-logs
aws logs create-log-group --log-group-name /ecs/error-logs
aws logs create-log-group --log-group-name /ecs/access-logs

# Set retention policy (30 days)
for log_group in "/ecs/application-logs" "/ecs/error-logs" "/ecs/access-logs" "/ecs/frontend" "/ecs/api" "/ecs/database"; do
    aws logs put-retention-policy \
        --log-group-name $log_group \
        --retention-in-days 30
    echo "✅ Set retention cho $log_group"
done
```

### 2.2 Cấu hình Log Insights Queries

```bash
echo "🔍 Tạo Log Insights queries..."

# Tạo file với các queries hữu ích
cat > log-insights-queries.txt << 'EOF'
# Top 10 error messages
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by @message
| sort count desc
| limit 10

# Request latency analysis
fields @timestamp, @duration
| filter @type = "REPORT"
| stats avg(@duration), max(@duration), min(@duration) by bin(5m)

# Failed requests by IP
fields @timestamp, @message
| filter @message like /4[0-9][0-9]/ or @message like /5[0-9][0-9]/
| parse @message /(?<ip>\d+\.\d+\.\d+\.\d+)/
| stats count() by ip
| sort count desc

# Memory usage over time
fields @timestamp, @maxMemoryUsed
| filter @type = "REPORT"
| stats avg(@maxMemoryUsed) by bin(5m)
EOF

echo "✅ Log Insights queries đã được tạo trong file log-insights-queries.txt"
```

## Bước 3: Custom Metrics

### 3.1 Tạo Custom Metrics Script

```bash
echo "📊 Tạo Custom Metrics script..."

cat > custom-metrics.sh << 'EOF'
#!/bin/bash

# Function to send custom metric
send_metric() {
    local metric_name=$1
    local value=$2
    local unit=$3
    local namespace=$4
    
    aws cloudwatch put-metric-data \
        --namespace "$namespace" \
        --metric-data MetricName="$metric_name",Value="$value",Unit="$unit"
}

# Get ECS service metrics
get_ecs_metrics() {
    local cluster_name=$1
    local service_name=$2
    
    # Get running task count
    running_tasks=$(aws ecs describe-services \
        --cluster $cluster_name \
        --services $service_name \
        --query 'services[0].runningCount' \
        --output text)
    
    # Get desired task count
    desired_tasks=$(aws ecs describe-services \
        --cluster $cluster_name \
        --services $service_name \
        --query 'services[0].desiredCount' \
        --output text)
    
    # Send metrics
    send_metric "RunningTasks" $running_tasks "Count" "ECS/Workshop"
    send_metric "DesiredTasks" $desired_tasks "Count" "ECS/Workshop"
    
    # Calculate availability percentage
    if [ $desired_tasks -gt 0 ]; then
        availability=$(echo "scale=2; $running_tasks * 100 / $desired_tasks" | bc)
        send_metric "ServiceAvailability" $availability "Percent" "ECS/Workshop"
    fi
}

# Get ALB metrics
get_alb_metrics() {
    local alb_arn=$1
    
    # Get healthy target count
    healthy_targets=$(aws elbv2 describe-target-health \
        --target-group-arn $(aws elbv2 describe-target-groups --load-balancer-arn $alb_arn --query 'TargetGroups[0].TargetGroupArn' --output text) \
        --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
        --output text)
    
    send_metric "HealthyTargets" $healthy_targets "Count" "ALB/Workshop"
}

# Main execution
if [ "$1" = "run" ]; then
    source workshop-env.sh
    get_ecs_metrics $CLUSTER_NAME "frontend-service"
    get_ecs_metrics $CLUSTER_NAME "api-service"
    get_alb_metrics $ALB_ARN
    echo "✅ Custom metrics sent"
fi
EOF

chmod +x custom-metrics.sh
echo "✅ Custom metrics script đã tạo"
```

### 3.2 Test Custom Metrics

```bash
echo "🧪 Test custom metrics..."
./custom-metrics.sh run
```

## Bước 4: CloudWatch Dashboards

### 4.1 Tạo ECS Dashboard

```bash
echo "📊 Tạo ECS Dashboard..."

cat > ecs-dashboard.json << EOF
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
                    [ "AWS/ECS", "CPUUtilization", "ServiceName", "frontend-service", "ClusterName", "$CLUSTER_NAME" ],
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
                "title": "ALB Metrics",
                "period": 300
            }
        },
        {
            "type": "log",
            "x": 0,
            "y": 6,
            "width": 24,
            "height": 6,
            "properties": {
                "query": "SOURCE '/ecs/frontend' | SOURCE '/ecs/api'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 20",
                "region": "$(aws configure get region)",
                "title": "Recent Errors",
                "view": "table"
            }
        }
    ]
}
EOF

# Tạo dashboard
aws cloudwatch put-dashboard \
    --dashboard-name "ECS-Workshop-Dashboard" \
    --dashboard-body file://ecs-dashboard.json

echo "✅ ECS Dashboard đã tạo"
```

### 4.2 Tạo Network Dashboard

```bash
echo "🌐 Tạo Network Dashboard..."

cat > network-dashboard.json << EOF
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
                    [ "AWS/ECS", "NetworkRxBytes", "ServiceName", "frontend-service", "ClusterName", "$CLUSTER_NAME" ],
                    [ ".", "NetworkTxBytes", ".", ".", ".", "." ],
                    [ ".", "NetworkRxBytes", "ServiceName", "api-service", "ClusterName", "$CLUSTER_NAME" ],
                    [ ".", "NetworkTxBytes", ".", ".", ".", "." ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$(aws configure get region)",
                "title": "Network Traffic",
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
                    [ "AWS/ApplicationELB", "ActiveConnectionCount", "LoadBalancer", "$(echo $ALB_ARN | cut -d'/' -f2-)" ],
                    [ ".", "NewConnectionCount", ".", "." ],
                    [ ".", "ConsumedLCUs", ".", "." ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$(aws configure get region)",
                "title": "Connection Metrics",
                "period": 300
            }
        }
    ]
}
EOF

aws cloudwatch put-dashboard \
    --dashboard-name "ECS-Network-Dashboard" \
    --dashboard-body file://network-dashboard.json

echo "✅ Network Dashboard đã tạo"
```

## Bước 5: CloudWatch Alarms

### 5.1 Tạo ECS Service Alarms

```bash
echo "🚨 Tạo ECS Service Alarms..."

# High CPU alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ECS-Frontend-High-CPU" \
    --alarm-description "Frontend service high CPU utilization" \
    --metric-name CPUUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=ServiceName,Value=frontend-service Name=ClusterName,Value=$CLUSTER_NAME \
    --alarm-actions arn:aws:sns:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):ecs-workshop-alerts

# High Memory alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ECS-Frontend-High-Memory" \
    --alarm-description "Frontend service high memory utilization" \
    --metric-name MemoryUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 300 \
    --threshold 85 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=ServiceName,Value=frontend-service Name=ClusterName,Value=$CLUSTER_NAME

# Service task count alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ECS-Frontend-Low-Task-Count" \
    --alarm-description "Frontend service running fewer tasks than desired" \
    --metric-name RunningTaskCount \
    --namespace ECS/Workshop \
    --statistic Average \
    --period 300 \
    --threshold 1 \
    --comparison-operator LessThanThreshold \
    --evaluation-periods 1

echo "✅ ECS Service alarms đã tạo"
```

### 5.2 Tạo ALB Alarms

```bash
echo "🚨 Tạo ALB Alarms..."

# High error rate alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ALB-High-4XX-Error-Rate" \
    --alarm-description "High 4XX error rate on ALB" \
    --metric-name HTTPCode_Target_4XX_Count \
    --namespace AWS/ApplicationELB \
    --statistic Sum \
    --period 300 \
    --threshold 10 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-)

# High response time alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ALB-High-Response-Time" \
    --alarm-description "High response time on ALB" \
    --metric-name TargetResponseTime \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 300 \
    --threshold 2.0 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 3 \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-)

# Unhealthy targets alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "ALB-Unhealthy-Targets" \
    --alarm-description "Unhealthy targets detected" \
    --metric-name UnHealthyHostCount \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 300 \
    --threshold 1 \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --evaluation-periods 1 \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-)

echo "✅ ALB alarms đã tạo"
```

## Bước 6: Log Analysis và Monitoring

### 6.1 Tạo Log Metric Filters

```bash
echo "📈 Tạo Log Metric Filters..."

# Error count metric filter
aws logs put-metric-filter \
    --log-group-name "/ecs/frontend" \
    --filter-name "ErrorCount" \
    --filter-pattern "ERROR" \
    --metric-transformations \
        metricName=ErrorCount,metricNamespace=ECS/Workshop,metricValue=1

# 404 errors metric filter
aws logs put-metric-filter \
    --log-group-name "/ecs/frontend" \
    --filter-name "404Errors" \
    --filter-pattern "[timestamp, request_id, level=\"ERROR\", message=\"*404*\"]" \
    --metric-transformations \
        metricName=404Errors,metricNamespace=ECS/Workshop,metricValue=1

# Response time metric filter (giả định log format)
aws logs put-metric-filter \
    --log-group-name "/ecs/api" \
    --filter-name "ResponseTime" \
    --filter-pattern "[timestamp, request_id, level, message, response_time]" \
    --metric-transformations \
        metricName=ResponseTime,metricNamespace=ECS/Workshop,metricValue='$response_time'

echo "✅ Log metric filters đã tạo"
```

### 6.2 Tạo Log Subscription Filter

```bash
echo "📡 Tạo Log Subscription Filter..."

# Tạo Lambda function để process logs (optional)
cat > log-processor.py << 'EOF'
import json
import gzip
import base64
import boto3

def lambda_handler(event, context):
    # Decode CloudWatch Logs data
    cw_data = event['awslogs']['data']
    compressed_payload = base64.b64decode(cw_data)
    uncompressed_payload = gzip.decompress(compressed_payload)
    log_data = json.loads(uncompressed_payload)
    
    # Process log events
    for log_event in log_data['logEvents']:
        message = log_event['message']
        timestamp = log_event['timestamp']
        
        # Custom processing logic here
        if 'ERROR' in message:
            print(f"Error detected at {timestamp}: {message}")
            # Send to SNS, store in DynamoDB, etc.
    
    return {'statusCode': 200}
EOF

echo "✅ Log processor template đã tạo"
```

## Bước 7: Performance Monitoring

### 7.1 Tạo Performance Monitoring Script

```bash
echo "⚡ Tạo Performance Monitoring script..."

cat > performance-monitor.sh << 'EOF'
#!/bin/bash

# Load environment
source workshop-env.sh

echo "🔍 ECS Performance Report - $(date)"
echo "=================================="

# ECS Service Status
echo "📊 ECS Service Status:"
aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services frontend-service api-service db-service \
    --query 'services[].{
        Name:serviceName,
        Status:status,
        Running:runningCount,
        Desired:desiredCount,
        Pending:pendingCount
    }' --output table

# ALB Target Health
echo "🎯 ALB Target Health:"
for tg_arn in $FRONTEND_TG_ARN $API_TG_ARN; do
    tg_name=$(aws elbv2 describe-target-groups --target-group-arns $tg_arn --query 'TargetGroups[0].TargetGroupName' --output text)
    echo "Target Group: $tg_name"
    aws elbv2 describe-target-health --target-group-arn $tg_arn \
        --query 'TargetHealthDescriptions[].{
            Target:Target.Id,
            Port:Target.Port,
            Health:TargetHealth.State,
            Reason:TargetHealth.Reason
        }' --output table
    echo ""
done

# Recent CloudWatch Metrics
echo "📈 Recent Metrics (Last 5 minutes):"
end_time=$(date -u +%Y-%m-%dT%H:%M:%S)
start_time=$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S)

# CPU Utilization
echo "CPU Utilization:"
aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name CPUUtilization \
    --dimensions Name=ServiceName,Value=frontend-service Name=ClusterName,Value=$CLUSTER_NAME \
    --start-time $start_time \
    --end-time $end_time \
    --period 300 \
    --statistics Average \
    --query 'Datapoints[0].Average' \
    --output text

# Memory Utilization
echo "Memory Utilization:"
aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name MemoryUtilization \
    --dimensions Name=ServiceName,Value=frontend-service Name=ClusterName,Value=$CLUSTER_NAME \
    --start-time $start_time \
    --end-time $end_time \
    --period 300 \
    --statistics Average \
    --query 'Datapoints[0].Average' \
    --output text

# ALB Request Count
echo "ALB Request Count:"
aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-) \
    --start-time $start_time \
    --end-time $end_time \
    --period 300 \
    --statistics Sum \
    --query 'Datapoints[0].Sum' \
    --output text

echo "=================================="
EOF

chmod +x performance-monitor.sh
echo "✅ Performance monitoring script đã tạo"
```

### 7.2 Test Performance Monitor

```bash
echo "🧪 Test performance monitor..."
./performance-monitor.sh
```

## Bước 8: Automated Monitoring

### 8.1 Tạo CloudWatch Events Rule

```bash
echo "⏰ Tạo CloudWatch Events Rule..."

# Tạo rule để chạy performance monitor mỗi 5 phút
aws events put-rule \
    --name "ECS-Performance-Monitor" \
    --description "Run performance monitoring every 5 minutes" \
    --schedule-expression "rate(5 minutes)" \
    --state ENABLED

echo "✅ CloudWatch Events rule đã tạo"
```

### 8.2 Tạo Health Check Script

```bash
echo "🏥 Tạo Health Check script..."

cat > health-check.sh << 'EOF'
#!/bin/bash

# Load environment
source workshop-env.sh

# Health check function
check_service_health() {
    local service_name=$1
    local expected_count=$2
    
    running_count=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $service_name \
        --query 'services[0].runningCount' \
        --output text)
    
    if [ "$running_count" -eq "$expected_count" ]; then
        echo "✅ $service_name: $running_count/$expected_count tasks running"
        return 0
    else
        echo "❌ $service_name: $running_count/$expected_count tasks running"
        return 1
    fi
}

# Check ALB health
check_alb_health() {
    response=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/health)
    if [ "$response" -eq 200 ]; then
        echo "✅ ALB health check: OK"
        return 0
    else
        echo "❌ ALB health check: Failed (HTTP $response)"
        return 1
    fi
}

# Main health check
echo "🏥 Health Check Report - $(date)"
echo "================================"

health_status=0

check_service_health "frontend-service" 2 || health_status=1
check_service_health "api-service" 2 || health_status=1
check_service_health "db-service" 1 || health_status=1
check_alb_health || health_status=1

if [ $health_status -eq 0 ]; then
    echo "✅ All systems healthy"
else
    echo "❌ Some systems unhealthy"
    # Send alert (implement SNS notification here)
fi

echo "================================"
exit $health_status
EOF

chmod +x health-check.sh
echo "✅ Health check script đã tạo"
```

## Bước 9: Xem Monitoring Results

### 9.1 Xem Dashboards

```bash
echo "📊 Dashboard URLs:"
REGION=$(aws configure get region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "ECS Dashboard: https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=ECS-Workshop-Dashboard"
echo "Network Dashboard: https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=ECS-Network-Dashboard"
```

### 9.2 Xem Alarms

```bash
echo "🚨 Current Alarms Status:"
aws cloudwatch describe-alarms \
    --alarm-names "ECS-Frontend-High-CPU" "ALB-High-4XX-Error-Rate" "ALB-High-Response-Time" \
    --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Reason:StateReason}' \
    --output table
```

### 9.3 Test Monitoring với Load

```bash
echo "⚡ Tạo load để test monitoring..."

# Tạo load test script
cat > load-test.sh << 'EOF'
#!/bin/bash
source workshop-env.sh

echo "🚀 Starting load test..."
for i in {1..100}; do
    curl -s http://$ALB_DNS/ > /dev/null &
    curl -s http://$ALB_DNS/api/ > /dev/null &
    
    if [ $((i % 10)) -eq 0 ]; then
        echo "Sent $i requests..."
    fi
    
    sleep 0.1
done

wait
echo "✅ Load test completed"
EOF

chmod +x load-test.sh

# Chạy load test
./load-test.sh
```

## Bước 10: Monitoring Best Practices

### 10.1 Monitoring Checklist

```bash
echo "📋 Monitoring Best Practices Checklist:"
cat << 'EOF'
✅ Monitoring Checklist:
□ CloudWatch Logs configured with retention policies
□ Custom metrics for business KPIs
□ Dashboards for different stakeholders
□ Alarms for critical metrics
□ Log metric filters for error tracking
□ Performance monitoring automation
□ Health checks for all services
□ Network monitoring (VPC Flow Logs)
□ Security monitoring (failed logins, unusual patterns)
□ Cost monitoring and alerts
□ Documentation for runbooks
□ Regular review and optimization of metrics
EOF
```

### 10.2 Monitoring Summary

```bash
echo "📊 Monitoring Summary:"
echo "====================="

echo "Log Groups:"
aws logs describe-log-groups --log-group-name-prefix "/ecs/" --query 'length(logGroups)'

echo "Dashboards:"
aws cloudwatch list-dashboards --query 'length(DashboardEntries)'

echo "Alarms:"
aws cloudwatch describe-alarms --query 'length(MetricAlarms)'

echo "Metric Filters:"
aws logs describe-metric-filters --query 'length(metricFilters)'
```

## Troubleshooting Monitoring

### Vấn đề thường gặp:

**Metrics không hiển thị:**
```bash
# Kiểm tra metric namespace
aws cloudwatch list-metrics --namespace "ECS/Workshop"

# Kiểm tra IAM permissions
aws iam simulate-principal-policy \
    --policy-source-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskRole \
    --action-names cloudwatch:PutMetricData
```

**Alarms không trigger:**
```bash
# Kiểm tra alarm history
aws cloudwatch describe-alarm-history --alarm-name "ECS-Frontend-High-CPU"

# Test alarm manually
aws cloudwatch set-alarm-state \
    --alarm-name "ECS-Frontend-High-CPU" \
    --state-value ALARM \
    --state-reason "Testing alarm"
```

**Logs không xuất hiện:**
```bash
# Kiểm tra log group permissions
aws logs describe-log-groups --log-group-name-prefix "/ecs/"

# Kiểm tra task definition log configuration
aws ecs describe-task-definition --task-definition frontend-app --query 'taskDefinition.containerDefinitions[0].logConfiguration'
```

## Tóm tắt

Bạn đã thiết lập thành công hệ thống monitoring toàn diện:

- ✅ **CloudWatch Logs:** Centralized logging với retention policies
- ✅ **Custom Metrics:** Business và technical KPIs
- ✅ **Dashboards:** Visual monitoring cho ECS và Network
- ✅ **Alarms:** Proactive alerting cho critical issues
- ✅ **Log Analysis:** Metric filters và Log Insights queries
- ✅ **Performance Monitoring:** Automated health checks
- ✅ **Load Testing:** Scripts để validate monitoring

**Monitoring Coverage:**
- **Infrastructure:** ECS, ALB, VPC
- **Application:** Logs, errors, performance
- **Network:** Traffic, connections, latency
- **Security:** Failed requests, unusual patterns

## Bước tiếp theo

Monitoring đã hoàn tất! Cuối cùng chúng ta sẽ học cách [Cleanup Resources](../8-cleanup/) để tránh chi phí không cần thiết.

---

**💡 Monitoring Tip:** "You can't improve what you don't measure" - luôn monitor những metrics quan trọng nhất trước.

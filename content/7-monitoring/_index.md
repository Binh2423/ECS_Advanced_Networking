---
title : "Advanced Monitoring và Troubleshooting"
date : "2024-08-13"
weight : 7
chapter : false
pre : " <b> 7. </b> "
---

# Advanced Monitoring và Troubleshooting

## Tổng quan

{{< workshop-image src="{{ "images/advanced-monitoring.png" | absURL }}" alt="Advanced Monitoring" caption="Advanced monitoring và troubleshooting tools cho ECS" >}}

### Chúng ta sẽ tìm hiểu:

📊 **Container Insights** cho deep monitoring  
🔍 **X-Ray Tracing** cho distributed tracing  
🚨 **Advanced Alerting** với SNS  
🛠️ **Troubleshooting** common issues  
📈 **Performance Optimization** tips  

## Bước 1: Enable Container Insights

### 1.1 Truy cập CloudWatch Console

{{< console-screenshot src="{{ "images/container-insights.png" | absURL }}" alt="Container Insights" caption="Container Insights cung cấp detailed metrics cho containers" service="CloudWatch Console" >}}

**Các bước:**
1. Mở CloudWatch Console
2. Click "Insights" → "Container Insights"
3. Chọn "Performance monitoring"

### 1.2 Enable Container Insights

```bash
# Load environment
source workshop-env.sh

# Enable Container Insights cho ECS cluster
aws ecs put-account-setting \
    --name containerInsights \
    --value enabled

# Update cluster với Container Insights
aws ecs update-cluster-settings \
    --cluster $CLUSTER_NAME \
    --settings name=containerInsights,value=enabled

echo "✅ Container Insights enabled"
```

### 1.3 Xem Container Insights Data

{{< console-screenshot src="{{ "images/container-insights-data.png" | absURL }}" alt="Container Insights Data" caption="Container Insights hiển thị detailed performance metrics" service="CloudWatch Console" >}}

```bash
# Kiểm tra Container Insights metrics
aws logs describe-log-groups --log-group-name-prefix "/aws/containerinsights/$CLUSTER_NAME"

echo "✅ Container Insights data available"
```

## Bước 2: AWS X-Ray Tracing

### 2.1 Tạo X-Ray Service Map

{{< console-screenshot src="{{ "images/xray-service-map.png" | absURL }}" alt="X-Ray Service Map" caption="X-Ray Service Map hiển thị service dependencies" service="X-Ray Console" >}}

```bash
# Tạo X-Ray sampling rule
cat > xray-sampling-rule.json << 'EOF'
{
  "version": 2,
  "default": {
    "fixed_target": 1,
    "rate": 0.1
  },
  "rules": [
    {
      "description": "ECS Workshop sampling",
      "service_name": "workshop-*",
      "http_method": "*",
      "url_path": "*",
      "fixed_target": 2,
      "rate": 0.2
    }
  ]
}
EOF

# Create sampling rule
aws xray create-sampling-rule --sampling-rule file://xray-sampling-rule.json

echo "✅ X-Ray sampling rule created"
```

### 2.2 Update Task Definition với X-Ray

```bash
# Tạo updated task definition với X-Ray sidecar
cat > frontend-xray-task-def.json << 'EOF'
{
  "family": "workshop-frontend-xray",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "frontend",
      "image": "nginx:latest",
      "portMappings": [{"containerPort": 80}],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/workshop-frontend",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    },
    {
      "name": "xray-daemon",
      "image": "amazon/aws-xray-daemon:latest",
      "portMappings": [{"containerPort": 2000, "protocol": "udp"}],
      "essential": false,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/workshop-xray",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "xray"
        }
      }
    }
  ]
}
EOF

# Thay thế ACCOUNT_ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
sed -i "s/ACCOUNT_ID/$ACCOUNT_ID/g" frontend-xray-task-def.json

# Tạo log group cho X-Ray
aws logs create-log-group --log-group-name /ecs/workshop-xray

echo "✅ X-Ray task definition prepared"
```

## Bước 3: Advanced Alerting

### 3.1 Tạo SNS Topic

{{< console-screenshot src="{{ "images/sns-topic.png" | absURL }}" alt="SNS Topic" caption="SNS Topic để gửi alerts qua email/SMS" service="SNS Console" >}}

```bash
# Tạo SNS topic cho alerts
TOPIC_ARN=$(aws sns create-topic \
    --name ecs-workshop-alerts \
    --query 'TopicArn' --output text)

# Subscribe email (thay YOUR_EMAIL bằng email thật)
# aws sns subscribe \
#     --topic-arn $TOPIC_ARN \
#     --protocol email \
#     --notification-endpoint your-email@example.com

echo "✅ SNS Topic created: $TOPIC_ARN"
echo "export TOPIC_ARN=$TOPIC_ARN" >> workshop-env.sh
```

### 3.2 Tạo Advanced Alarms

```bash
# Composite alarm cho service health
aws cloudwatch put-composite-alarm \
    --alarm-name "ECS-Service-Health-Composite" \
    --alarm-description "Composite alarm for ECS service health" \
    --alarm-rule "(ALARM('ALB-UnhealthyTargets') OR ALARM('ECS-HighCPU'))" \
    --actions-enabled \
    --alarm-actions $TOPIC_ARN

# Anomaly detector cho ALB requests
aws cloudwatch put-anomaly-detector \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-) \
    --stat Average

echo "✅ Advanced alarms created"
```

## Bước 4: Performance Monitoring

### 4.1 Custom Metrics Dashboard

{{< console-screenshot src="{{ "images/performance-dashboard.png" | absURL }}" alt="Performance Dashboard" caption="Custom dashboard cho performance monitoring" service="CloudWatch Console" >}}

```bash
# Tạo advanced dashboard
cat > advanced-dashboard.json << EOF
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ECS", "CPUUtilization", "ServiceName", "workshop-frontend", "ClusterName", "$CLUSTER_NAME"],
          [".", "MemoryUtilization", ".", ".", ".", "."],
          ["AWS/ECS", "CPUUtilization", "ServiceName", "workshop-backend", "ClusterName", "$CLUSTER_NAME"],
          [".", "MemoryUtilization", ".", ".", ".", "."]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-1",
        "title": "ECS Resource Utilization",
        "period": 300
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "$(echo $ALB_ARN | cut -d'/' -f2-)"],
          [".", "TargetResponseTime", ".", "."],
          [".", "HTTPCode_Target_2XX_Count", ".", "."],
          [".", "HTTPCode_Target_4XX_Count", ".", "."],
          [".", "HTTPCode_Target_5XX_Count", ".", "."]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-1",
        "title": "ALB Performance Metrics",
        "period": 300
      }
    }
  ]
}
EOF

# Update dashboard
aws cloudwatch put-dashboard \
    --dashboard-name "ECS-Workshop-Advanced-Dashboard" \
    --dashboard-body file://advanced-dashboard.json

echo "✅ Advanced dashboard created"
```

## Bước 5: Troubleshooting Tools

### 5.1 ECS Exec Setup

{{< console-screenshot src="{{ "images/ecs-exec.png" | absURL }}" alt="ECS Exec" caption="ECS Exec cho phép debug containers trực tiếp" service="ECS Console" >}}

```bash
# Enable ECS Exec cho service
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service workshop-frontend \
    --enable-execute-command

echo "✅ ECS Exec enabled"
```

### 5.2 Common Troubleshooting Commands

```bash
echo "🛠️ Troubleshooting Commands:"
echo "============================"

# 1. Check service status
echo "1. Service Status:"
aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services workshop-frontend \
    --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Events:events[0:3].message}'

# 2. Check task health
echo "2. Task Health:"
aws ecs list-tasks --cluster $CLUSTER_NAME --service-name workshop-frontend
TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name workshop-frontend --query 'taskArns[0]' --output text)

if [ "$TASK_ARN" != "None" ]; then
    aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN \
        --query 'tasks[0].{LastStatus:lastStatus,HealthStatus:healthStatus,CreatedAt:createdAt}'
fi

# 3. Check target group health
echo "3. Target Group Health:"
aws elbv2 describe-target-health --target-group-arn $FRONTEND_TG_ARN

echo "✅ Troubleshooting commands executed"
```

## Bước 6: Log Analysis

### 6.1 CloudWatch Insights Queries

{{< console-screenshot src="{{ "images/cloudwatch-insights.png" | absURL }}" alt="CloudWatch Insights" caption="CloudWatch Insights để query và analyze logs" service="CloudWatch Console" >}}

```bash
# Tạo sample CloudWatch Insights queries
echo "📊 Sample CloudWatch Insights Queries:"
echo "======================================"

cat << 'EOF'
# Query 1: Error rate analysis
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by bin(5m)

# Query 2: Response time analysis  
fields @timestamp, @message
| filter @message like /response_time/
| parse @message "response_time=*" as response_time
| stats avg(response_time), max(response_time) by bin(5m)

# Query 3: Top error messages
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by @message
| sort count desc
| limit 10
EOF

echo "✅ Sample queries provided"
```

## Bước 7: Performance Optimization

### 7.1 Auto Scaling Configuration

{{< console-screenshot src="{{ "images/auto-scaling.png" | absURL }}" alt="Auto Scaling" caption="ECS Auto Scaling để tự động scale services" service="ECS Console" >}}

```bash
# Tạo Application Auto Scaling target
aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --resource-id service/$CLUSTER_NAME/workshop-frontend \
    --scalable-dimension ecs:service:DesiredCount \
    --min-capacity 2 \
    --max-capacity 10

# Tạo scaling policy
aws application-autoscaling put-scaling-policy \
    --service-namespace ecs \
    --resource-id service/$CLUSTER_NAME/workshop-frontend \
    --scalable-dimension ecs:service:DesiredCount \
    --policy-name workshop-frontend-cpu-scaling \
    --policy-type TargetTrackingScaling \
    --target-tracking-scaling-policy-configuration '{
        "TargetValue": 70.0,
        "PredefinedMetricSpecification": {
            "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
        },
        "ScaleOutCooldown": 300,
        "ScaleInCooldown": 300
    }'

echo "✅ Auto Scaling configured"
```

## Kiểm tra kết quả

### 7.2 Monitoring Health Check

{{< console-screenshot src="{{ "images/monitoring-health.png" | absURL }}" alt="Monitoring Health" caption="Tổng quan health status của monitoring infrastructure" service="CloudWatch Console" >}}

```bash
echo "📋 Advanced Monitoring Summary:"
echo "==============================="
echo "Container Insights: Enabled"
echo "X-Ray Tracing: Configured"
echo "SNS Alerts: $TOPIC_ARN"
echo "Advanced Dashboard: ECS-Workshop-Advanced-Dashboard"
echo "Auto Scaling: Enabled for frontend service"
echo ""
echo "✅ Advanced Monitoring setup completed!"
```

{{< alert type="success" title="Hoàn thành!" >}}
🎉 **Advanced Monitoring đã sẵn sàng!**  
✅ Container Insights cho deep monitoring  
✅ X-Ray tracing cho distributed systems  
✅ Advanced alerting với SNS  
✅ Performance optimization với Auto Scaling  
✅ Troubleshooting tools đã cấu hình  
{{< /alert >}}

## Troubleshooting Guide

{{< alert type="info" title="Common Issues & Solutions" >}}
🔧 **Service không start:** Check task definition, IAM roles, và security groups  
📊 **High CPU/Memory:** Review resource allocation và optimize application  
🌐 **Network issues:** Verify VPC configuration, route tables, và NACLs  
🚨 **Health check failures:** Check application health endpoint và target group settings  
📝 **Missing logs:** Verify CloudWatch Logs configuration và IAM permissions  
{{< /alert >}}

## Performance Tips

{{< alert type="tip" title="Performance Optimization" >}}
⚡ **Right-size containers:** Monitor và adjust CPU/memory based on usage  
🔄 **Use Auto Scaling:** Implement target tracking scaling policies  
📊 **Monitor key metrics:** Focus on CPU, memory, response time, error rate  
🎯 **Optimize health checks:** Use lightweight health check endpoints  
🚀 **Container optimization:** Use multi-stage builds và minimal base images  
{{< /alert >}}

## Bước tiếp theo

Advanced Monitoring đã hoàn tất. Cuối cùng chúng ta sẽ cleanup resources!

{{< button href="../8-cleanup/" >}}Tiếp theo: Cleanup Resources →{{< /button >}}

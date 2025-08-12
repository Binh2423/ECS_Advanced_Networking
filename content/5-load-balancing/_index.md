---
title : "Cấu hình Load Balancing"
date : "`r Sys.Date()`"
weight : 5
chapter : false
pre : " <b> 5. </b> "
---

# Cấu hình Load Balancing

## Load Balancer là gì?

Load Balancer giống như nhân viên tiếp tân tại khách sạn - phân phối khách hàng đến các phòng trống, đảm bảo không có phòng nào quá tải.

**Lợi ích:**
- **High Availability:** Nếu 1 server down, traffic chuyển sang server khác
- **Scalability:** Tự động phân phối load khi có nhiều instances
- **Health Checking:** Chỉ gửi traffic đến healthy instances

## Tổng quan Architecture

```
Internet → ALB → Target Groups → ECS Services
    ↓         ↓         ↓           ↓
  Users   Load      Frontend    Container
         Balancer   API Tasks    Instances
```

## Bước 1: Chuẩn bị

### 1.1 Load environment

```bash
cd ~/ecs-workshop
source workshop-env.sh

# Kiểm tra variables cần thiết
echo "VPC ID: $VPC_ID"
echo "Public Subnets: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"
echo "ALB Security Group: $ALB_SG"
```

### 1.2 Kiểm tra services đang chạy

```bash
aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services frontend-service api-service \
    --query 'services[].{Name:serviceName,Status:status,Running:runningCount}' \
    --output table
```

## Bước 2: Tạo Application Load Balancer

### 2.1 Tạo ALB

```bash
echo "🚀 Tạo Application Load Balancer..."

ALB_ARN=$(aws elbv2 create-load-balancer \
    --name ecs-workshop-alb \
    --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 \
    --security-groups $ALB_SG \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --tags Key=Name,Value="ECS Workshop ALB" Key=Environment,Value=Workshop \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

echo "✅ ALB ARN: $ALB_ARN"
echo "export ALB_ARN=$ALB_ARN" >> workshop-env.sh
```

### 2.2 Lấy ALB DNS Name

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "🌐 ALB DNS Name: $ALB_DNS"
echo "export ALB_DNS=$ALB_DNS" >> workshop-env.sh
```

### 2.3 Xem trong Console

1. Mở [EC2 Console](https://console.aws.amazon.com/ec2/)
2. Chọn "Load Balancers" ở sidebar trái
3. Tìm "ecs-workshop-alb"
4. Kiểm tra State = "active"

![ALB Overview](/images/alb-overview.png)

## Bước 3: Tạo Target Groups

### 3.1 Frontend Target Group

```bash
echo "🎯 Tạo Frontend Target Group..."

FRONTEND_TG_ARN=$(aws elbv2 create-target-group \
    --name frontend-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-path / \
    --health-check-protocol HTTP \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --matcher HttpCode=200 \
    --tags Key=Name,Value="Frontend Target Group" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "✅ Frontend TG ARN: $FRONTEND_TG_ARN"
echo "export FRONTEND_TG_ARN=$FRONTEND_TG_ARN" >> workshop-env.sh
```

### 3.2 API Target Group

```bash
echo "🎯 Tạo API Target Group..."

API_TG_ARN=$(aws elbv2 create-target-group \
    --name api-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-path / \
    --health-check-protocol HTTP \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --matcher HttpCode=200,403 \
    --tags Key=Name,Value="API Target Group" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "✅ API TG ARN: $API_TG_ARN"
echo "export API_TG_ARN=$API_TG_ARN" >> workshop-env.sh
```

### 3.3 Xem Target Groups

```bash
echo "📊 Target Groups đã tạo:"
aws elbv2 describe-target-groups \
    --target-group-arns $FRONTEND_TG_ARN $API_TG_ARN \
    --query 'TargetGroups[].{Name:TargetGroupName,Port:Port,Protocol:Protocol,HealthCheck:HealthCheckPath}' \
    --output table
```

## Bước 4: Tạo Listeners và Routing Rules

### 4.1 Tạo Default Listener (Frontend)

```bash
echo "👂 Tạo ALB Listener..."

LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$FRONTEND_TG_ARN \
    --tags Key=Name,Value="HTTP Listener" \
    --query 'Listeners[0].ListenerArn' \
    --output text)

echo "✅ Listener ARN: $LISTENER_ARN"
echo "export LISTENER_ARN=$LISTENER_ARN" >> workshop-env.sh
```

### 4.2 Tạo API Path Rule

```bash
echo "🛣️ Tạo API routing rule..."

aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 100 \
    --conditions Field=path-pattern,Values="/api/*" \
    --actions Type=forward,TargetGroupArn=$API_TG_ARN \
    --tags Key=Name,Value="API Path Rule"

echo "✅ API routing rule đã tạo"
```

### 4.3 Tạo Health Check Rule

```bash
echo "🏥 Tạo health check rule..."

aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 200 \
    --conditions Field=path-pattern,Values="/health" \
    --actions Type=fixed-response,FixedResponseConfig='{StatusCode=200,ContentType=text/plain,MessageBody=OK}' \
    --tags Key=Name,Value="Health Check Rule"

echo "✅ Health check rule đã tạo"
```

### 4.4 Xem Routing Rules

```bash
echo "📋 Routing Rules:"
aws elbv2 describe-rules --listener-arn $LISTENER_ARN \
    --query 'Rules[].{Priority:Priority,Conditions:Conditions[0].Values,Actions:Actions[0].Type}' \
    --output table
```

## Bước 5: Cập nhật ECS Services với Load Balancer

### 5.1 Cập nhật Frontend Service

```bash
echo "🔄 Cập nhật Frontend Service với ALB..."

aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service frontend-service \
    --load-balancers targetGroupArn=$FRONTEND_TG_ARN,containerName=frontend,containerPort=80 \
    --health-check-grace-period-seconds 60

echo "✅ Frontend service đã được cập nhật"
```

### 5.2 Cập nhật API Service

```bash
echo "🔄 Cập nhật API Service với ALB..."

aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service api-service \
    --load-balancers targetGroupArn=$API_TG_ARN,containerName=api,containerPort=80 \
    --health-check-grace-period-seconds 60

echo "✅ API service đã được cập nhật"
```

### 5.3 Chờ services ổn định

```bash
echo "⏳ Chờ services cập nhật..."

aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services frontend-service api-service

echo "✅ Services đã ổn định"
```

## Bước 6: Kiểm tra Health Status

### 6.1 Kiểm tra Target Health

```bash
echo "🏥 Kiểm tra Target Health..."

echo "Frontend targets:"
aws elbv2 describe-target-health --target-group-arn $FRONTEND_TG_ARN \
    --query 'TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,Health:TargetHealth.State}' \
    --output table

echo "API targets:"
aws elbv2 describe-target-health --target-group-arn $API_TG_ARN \
    --query 'TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,Health:TargetHealth.State}' \
    --output table
```

### 6.2 Chờ targets healthy

```bash
echo "⏳ Chờ targets healthy..."

# Function để check target health
check_target_health() {
    local tg_arn=$1
    local tg_name=$2
    
    while true; do
        healthy_count=$(aws elbv2 describe-target-health --target-group-arn $tg_arn \
            --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text)
        total_count=$(aws elbv2 describe-target-health --target-group-arn $tg_arn \
            --query 'length(TargetHealthDescriptions)' --output text)
        
        echo "$tg_name: $healthy_count/$total_count healthy"
        
        if [ "$healthy_count" -gt 0 ]; then
            echo "✅ $tg_name có targets healthy!"
            break
        fi
        
        sleep 15
    done
}

check_target_health $FRONTEND_TG_ARN "Frontend"
check_target_health $API_TG_ARN "API"
```

## Bước 7: Test Load Balancer

### 7.1 Test Frontend

```bash
echo "🧪 Test Frontend endpoint..."

curl -s -o /dev/null -w "Status: %{http_code}\nTime: %{time_total}s\n" http://$ALB_DNS/

echo "🌐 Frontend URL: http://$ALB_DNS/"
```

### 7.2 Test API

```bash
echo "🧪 Test API endpoint..."

curl -s -o /dev/null -w "Status: %{http_code}\nTime: %{time_total}s\n" http://$ALB_DNS/api/

echo "🌐 API URL: http://$ALB_DNS/api/"
```

### 7.3 Test Health Check

```bash
echo "🧪 Test Health Check endpoint..."

curl -s http://$ALB_DNS/health
echo ""
```

### 7.4 Load Test (Optional)

```bash
echo "⚡ Chạy load test đơn giản..."

for i in {1..10}; do
    echo "Request $i:"
    curl -s -o /dev/null -w "Status: %{http_code} - Time: %{time_total}s\n" http://$ALB_DNS/
    sleep 1
done
```

## Bước 8: Monitoring và Metrics

### 8.1 Xem ALB Metrics

```bash
echo "📊 ALB Metrics (5 phút gần nhất):"

aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-) \
    --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum \
    --query 'Datapoints[0].Sum' \
    --output text
```

### 8.2 Xem Target Group Metrics

```bash
echo "📈 Target Group Health:"

aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name HealthyHostCount \
    --dimensions Name=TargetGroup,Value=$(echo $FRONTEND_TG_ARN | cut -d'/' -f2-) \
    --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average \
    --query 'Datapoints[0].Average' \
    --output text
```

## Bước 9: Xem kết quả trong Console

### 9.1 Load Balancer Console

1. Mở [EC2 Console](https://console.aws.amazon.com/ec2/)
2. Chọn "Load Balancers"
3. Click vào "ecs-workshop-alb"
4. Xem tabs:
   - **Description:** Basic info
   - **Listeners:** Routing rules
   - **Monitoring:** Metrics và graphs

![ALB Details](/images/alb-details.png)

### 9.2 Target Groups Console

1. Chọn "Target Groups"
2. Click vào "frontend-tg" hoặc "api-tg"
3. Tab "Targets" - xem health status
4. Tab "Monitoring" - xem metrics

![Target Groups Health](/images/target-groups-health.png)

### 9.3 CloudWatch Metrics

1. Mở [CloudWatch Console](https://console.aws.amazon.com/cloudwatch/)
2. Chọn "Metrics" → "All metrics"
3. Chọn "AWS/ApplicationELB"
4. Xem metrics như RequestCount, ResponseTime, HealthyHostCount

## Troubleshooting

### Vấn đề thường gặp:

**Targets không healthy:**
```bash
# Kiểm tra security groups
aws ec2 describe-security-groups --group-ids $ECS_SG $ALB_SG

# Kiểm tra task health
aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name frontend-service --query 'taskArns[0]' --output text)
```

**ALB không accessible:**
```bash
# Kiểm tra ALB security group
aws ec2 describe-security-groups --group-ids $ALB_SG --query 'SecurityGroups[0].IpPermissions'

# Kiểm tra subnets
aws ec2 describe-subnets --subnet-ids $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2
```

**503 Service Unavailable:**
```bash
# Kiểm tra target registration
aws elbv2 describe-target-health --target-group-arn $FRONTEND_TG_ARN

# Xem ECS service events
aws ecs describe-services --cluster $CLUSTER_NAME --services frontend-service --query 'services[0].events[0:5]'
```

## Advanced Configuration

### Sticky Sessions (nếu cần)

```bash
# Enable sticky sessions cho frontend
aws elbv2 modify-target-group-attributes \
    --target-group-arn $FRONTEND_TG_ARN \
    --attributes Key=stickiness.enabled,Value=true Key=stickiness.type,Value=lb_cookie Key=stickiness.lb_cookie.duration_seconds,Value=86400
```

### Custom Health Check

```bash
# Thay đổi health check path
aws elbv2 modify-target-group \
    --target-group-arn $API_TG_ARN \
    --health-check-path /api/health \
    --health-check-interval-seconds 15
```

## Tóm tắt

Bạn đã cấu hình thành công:

- ✅ Application Load Balancer với public access
- ✅ Target Groups cho Frontend và API services  
- ✅ Path-based routing (/api/* → API, /* → Frontend)
- ✅ Health checking và monitoring
- ✅ Integration với ECS services
- ✅ Load balancing across multiple AZs

**Kết quả:** 
- Frontend: `http://$ALB_DNS/`
- API: `http://$ALB_DNS/api/`
- Health: `http://$ALB_DNS/health`

## Bước tiếp theo

Load Balancer đã hoạt động! Tiếp theo chúng ta sẽ tăng cường bảo mật với [Security và Network Policies](../6-security/).

---

**💡 Tip:** ALB tự động phân phối traffic đến healthy targets và có thể handle hàng nghìn requests/second.

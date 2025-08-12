---
title : "Load Balancing nâng cao"
date : "`r Sys.Date()`"
weight : 5
chapter : false
pre : " <b> 5. </b> "
---

# Load Balancing nâng cao

Trong phần này, chúng ta sẽ triển khai các chiến lược load balancing nâng cao cho ECS services sử dụng Application Load Balancer (ALB) với các quy tắc routing phức tạp, health checks, và các mẫu phân phối traffic.

## Tổng quan Load Balancing

Application Load Balancer cung cấp khả năng load balancing Layer 7 cho phép:
- **Path-based routing**: Định tuyến traffic dựa trên URL paths
- **Host-based routing**: Định tuyến traffic dựa trên host headers
- **Health checks**: Giám sát sức khỏe ứng dụng và định tuyến traffic tương ứng
- **SSL/TLS termination**: Xử lý mã hóa/giải mã tại load balancer
- **WebSocket support**: Hỗ trợ cho các ứng dụng real-time

## Kiến trúc

Chúng ta sẽ tạo setup load balancing như sau:

```
                    ┌─────────────────────┐
                    │   Internet Gateway  │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │ Application Load    │
                    │     Balancer        │
                    └──────────┬──────────┘
                               │
        ┌──────────────────────┼─────────────────────┐
        │                      │                     │
┌───────▼────────┐    ┌────────▼────────┐    ┌───────▼────────┐
│  Web Service   │    │  API Service    │    │  Admin Service │
│ Target Group   │    │ Target Group    │    │ Target Group   │
└────────────────┘    └─────────────────┘    └────────────────┘
```

## Bước 1: Load Environment Variables

```bash
# Load environment variables
source workshop-resources.env

# Verify variables are loaded
echo "VPC ID: $VPC_ID"
echo "Public Subnets: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"
echo "ALB Security Group: $ALB_SG"
```

## Bước 2: Tạo Application Load Balancer

### 2.1 Tạo Application Load Balancer
```bash
# Tạo Application Load Balancer
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name ecs-workshop-alb \
    --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 \
    --security-groups $ALB_SG \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --tags Key=Name,Value=ECS-Workshop-ALB \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

echo "ALB ARN: $ALB_ARN"

# Lấy ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "ALB DNS Name: $ALB_DNS"
```

### 2.2 Chờ ALB Active
```bash
# Chờ ALB active
echo "Đang chờ ALB active..."
aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN
echo "ALB đã active"
```

## Bước 3: Tạo Target Groups

### 3.1 Tạo Web Service Target Group
```bash
# Tạo target group cho web service
WEB_TG_ARN=$(aws elbv2 create-target-group \
    --name ecs-web-targets \
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
    --tags Key=Name,Value=ECS-Web-Targets \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "Web Target Group ARN: $WEB_TG_ARN"
```

### 3.2 Tạo API Service Target Group
```bash
# Tạo target group cho API service
API_TG_ARN=$(aws elbv2 create-target-group \
    --name ecs-api-targets \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-path /health \
    --health-check-protocol HTTP \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --matcher HttpCode=200 \
    --tags Key=Name,Value=ECS-API-Targets \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "API Target Group ARN: $API_TG_ARN"
```

### 3.3 Tạo Admin Service Target Group
```bash
# Tạo target group cho admin service
ADMIN_TG_ARN=$(aws elbv2 create-target-group \
    --name ecs-admin-targets \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-path /admin/health \
    --health-check-protocol HTTP \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --matcher HttpCode=200 \
    --tags Key=Name,Value=ECS-Admin-Targets \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "Admin Target Group ARN: $ADMIN_TG_ARN"
```

## Bước 4: Tạo Listeners và Rules

### 4.1 Tạo Default Listener
```bash
# Tạo default listener (HTTP)
LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$WEB_TG_ARN \
    --tags Key=Name,Value=ECS-HTTP-Listener \
    --query 'Listeners[0].ListenerArn' \
    --output text)

echo "Listener ARN: $LISTENER_ARN"
```

### 4.2 Tạo Path-based Routing Rules
```bash
# Tạo rule cho API path
aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 100 \
    --conditions Field=path-pattern,Values="/api/*" \
    --actions Type=forward,TargetGroupArn=$API_TG_ARN \
    --tags Key=Name,Value=API-Path-Rule

# Tạo rule cho admin path
aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 200 \
    --conditions Field=path-pattern,Values="/admin/*" \
    --actions Type=forward,TargetGroupArn=$ADMIN_TG_ARN \
    --tags Key=Name,Value=Admin-Path-Rule

echo "Routing rules đã được tạo"
```

## Bước 5: Cập nhật ECS Services với Load Balancer

### 5.1 Cập nhật Web Service
```bash
# Cập nhật web service để sử dụng load balancer
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service web-service \
    --load-balancers targetGroupArn=$WEB_TG_ARN,containerName=web,containerPort=80

echo "Web service đã được cập nhật với load balancer"
```

### 5.2 Tạo API Service với Load Balancer
```bash
# Tạo enhanced API task definition
cat > api-enhanced-task-definition.json << EOF
{
    "family": "api-enhanced",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole",
    "taskRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskRole",
    "containerDefinitions": [
        {
            "name": "api",
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
                    "awslogs-group": "/ecs/api-enhanced",
                    "awslogs-region": "$(aws configure get region)",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "environment": [
                {
                    "name": "SERVICE_NAME",
                    "value": "api"
                },
                {
                    "name": "DB_ENDPOINT",
                    "value": "db.workshop.local"
                }
            ]
        }
    ]
}
EOF

# Tạo log group và register task definition
aws logs create-log-group --log-group-name /ecs/api-enhanced
aws ecs register-task-definition --cli-input-json file://api-enhanced-task-definition.json

# Cập nhật API service
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service api-service \
    --task-definition api-enhanced \
    --load-balancers targetGroupArn=$API_TG_ARN,containerName=api,containerPort=80

echo "API service đã được cập nhật với load balancer"
```

### 5.3 Tạo Admin Service
```bash
# Tạo admin task definition
cat > admin-task-definition.json << EOF
{
    "family": "admin-app",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole",
    "taskRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskRole",
    "containerDefinitions": [
        {
            "name": "admin",
            "image": "httpd:latest",
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
                    "awslogs-group": "/ecs/admin-app",
                    "awslogs-region": "$(aws configure get region)",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "environment": [
                {
                    "name": "SERVICE_NAME",
                    "value": "admin"
                }
            ]
        }
    ]
}
EOF

# Tạo log group và register task definition
aws logs create-log-group --log-group-name /ecs/admin-app
aws ecs register-task-definition --cli-input-json file://admin-task-definition.json

# Tạo admin service
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name admin-service \
    --task-definition admin-app \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --load-balancers targetGroupArn=$ADMIN_TG_ARN,containerName=admin,containerPort=80

echo "Admin service đã được tạo với load balancer"
```

## Bước 6: Tính năng Load Balancer nâng cao

### 6.1 Cấu hình Sticky Sessions
```bash
# Bật sticky sessions cho web service
aws elbv2 modify-target-group-attributes \
    --target-group-arn $WEB_TG_ARN \
    --attributes Key=stickiness.enabled,Value=true \
                Key=stickiness.type,Value=lb_cookie \
                Key=stickiness.lb_cookie.duration_seconds,Value=86400

echo "Sticky sessions đã được bật cho web service"
```

### 6.2 Cấu hình Connection Draining
```bash
# Cấu hình connection draining
aws elbv2 modify-target-group-attributes \
    --target-group-arn $API_TG_ARN \
    --attributes Key=deregistration_delay.timeout_seconds,Value=30

echo "Connection draining đã được cấu hình"
```

### 6.3 Cấu hình Health Check Settings
```bash
# Tối ưu health check settings cho API service
aws elbv2 modify-target-group \
    --target-group-arn $API_TG_ARN \
    --health-check-interval-seconds 15 \
    --health-check-timeout-seconds 3 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2

echo "Health check settings đã được tối ưu"
```

## Bước 7: Cấu hình SSL/TLS (Tùy chọn)

### 7.1 Request SSL Certificate
```bash
# Request SSL certificate (thay thế bằng domain của bạn)
CERT_ARN=$(aws acm request-certificate \
    --domain-name workshop.example.com \
    --subject-alternative-names "*.workshop.example.com" \
    --validation-method DNS \
    --query 'CertificateArn' \
    --output text)

echo "Certificate ARN: $CERT_ARN"
echo "Lưu ý: Bạn cần validate certificate qua DNS trước khi sử dụng"
```

### 7.2 Tạo HTTPS Listener (sau khi certificate validation)
```bash
# Tạo HTTPS listener (uncomment sau khi certificate validation)
# HTTPS_LISTENER_ARN=$(aws elbv2 create-listener \
#     --load-balancer-arn $ALB_ARN \
#     --protocol HTTPS \
#     --port 443 \
#     --certificates CertificateArn=$CERT_ARN \
#     --ssl-policy ELBSecurityPolicy-TLS-1-2-2017-01 \
#     --default-actions Type=forward,TargetGroupArn=$WEB_TG_ARN \
#     --query 'Listeners[0].ListenerArn' \
#     --output text)

# echo "HTTPS Listener ARN: $HTTPS_LISTENER_ARN"
```

## Bước 8: Test Load Balancer

### 8.1 Test Basic Connectivity
```bash
# Test web service (default path)
echo "Testing web service:"
curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/

# Test API service
echo "Testing API service:"
curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/api/

# Test admin service
echo "Testing admin service:"
curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/admin/
```

### 8.2 Test Load Distribution
```bash
# Test load distribution với multiple requests
echo "Testing load distribution:"
for i in {1..10}; do
    curl -s http://$ALB_DNS/ | head -1
    sleep 1
done
```

### 8.3 Monitor Target Health
```bash
# Kiểm tra target health cho tất cả target groups
echo "Web service target health:"
aws elbv2 describe-target-health --target-group-arn $WEB_TG_ARN

echo "API service target health:"
aws elbv2 describe-target-health --target-group-arn $API_TG_ARN

echo "Admin service target health:"
aws elbv2 describe-target-health --target-group-arn $ADMIN_TG_ARN
```

## Bước 9: Các tình huống Routing nâng cao

### 9.1 Header-based Routing
```bash
# Tạo rule cho mobile clients
aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 50 \
    --conditions Field=http-header,HttpHeaderConfig='{HttpHeaderName=User-Agent,Values=["*Mobile*","*Android*","*iPhone*"]}' \
    --actions Type=forward,TargetGroupArn=$WEB_TG_ARN \
    --tags Key=Name,Value=Mobile-Header-Rule

echo "Header-based routing rule đã được tạo"
```

### 9.2 Query String Routing
```bash
# Tạo rule cho API version routing
aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 75 \
    --conditions Field=query-string,QueryStringConfig='{Values=[{Key=version,Value=v2}]}' \
    --actions Type=forward,TargetGroupArn=$API_TG_ARN \
    --tags Key=Name,Value=Version-Query-Rule

echo "Query string routing rule đã được tạo"
```

## Bước 10: Cập nhật Environment Variables

```bash
# Cập nhật environment variables file
cat >> workshop-resources.env << EOF
export ALB_ARN=$ALB_ARN
export ALB_DNS=$ALB_DNS
export LISTENER_ARN=$LISTENER_ARN
export WEB_TG_ARN=$WEB_TG_ARN
export API_TG_ARN=$API_TG_ARN
export ADMIN_TG_ARN=$ADMIN_TG_ARN
EOF

echo "Load balancer resources đã được thêm vào workshop-resources.env"
```

## Monitoring và Troubleshooting

### Các vấn đề thường gặp

1. **Target Health Check Failures**
   - Xác minh security group rules cho phép ALB reach targets
   - Kiểm tra health check path và expected response codes
   - Đảm bảo application đang listen trên port đúng

2. **Routing Rules không hoạt động**
   - Kiểm tra rule priority (số thấp hơn có priority cao hơn)
   - Xác minh condition syntax và values
   - Test với curl sử dụng specific headers hoặc paths

3. **SSL Certificate Issues**
   - Đảm bảo certificate được validated và issued
   - Kiểm tra certificate covers domain đang được sử dụng
   - Xác minh SSL policy compatibility

### Verification Commands
```bash
# Kiểm tra ALB status
aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN

# List tất cả target groups
aws elbv2 describe-target-groups --load-balancer-arn $ALB_ARN

# Kiểm tra listener rules
aws elbv2 describe-rules --listener-arn $LISTENER_ARN

# Monitor ALB metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-) \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum
```

## Best Practices

1. **Health Checks**
   - Sử dụng dedicated health check endpoints
   - Đặt timeout và interval values phù hợp
   - Monitor health check metrics

2. **Security**
   - Sử dụng HTTPS cho production workloads
   - Triển khai proper security group rules
   - Cân nhắc WAF integration cho additional protection

3. **Performance**
   - Bật connection draining cho graceful shutdowns
   - Sử dụng appropriate target group attributes
   - Monitor và optimize dựa trên metrics

4. **Cost Optimization**
   - Sử dụng appropriate instance types cho targets
   - Monitor unused target groups
   - Cân nhắc cross-zone load balancing costs

## Bước tiếp theo

Tuyệt vời! Bạn đã triển khai thành công advanced load balancing cho ECS services. Setup của bạn bây giờ bao gồm:

- ✅ Application Load Balancer với multiple target groups
- ✅ Path-based routing cho different services
- ✅ Health checks và monitoring
- ✅ Advanced routing rules
- ✅ SSL/TLS configuration (tùy chọn)

Tiếp theo, chúng ta sẽ chuyển đến [Best Practices bảo mật](../6-security/) nơi chúng ta sẽ triển khai các biện pháp bảo mật toàn diện cho ECS networking setup.

---

**Resources đã tạo:**
- 1 Application Load Balancer
- 3 Target Groups (Web, API, Admin)
- 1 HTTP Listener với routing rules
- 3 ECS Services với load balancer integration
- Advanced routing rules và health checks

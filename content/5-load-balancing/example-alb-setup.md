---
title : "Ví dụ: Setup ALB với Advanced Routing"
date : "`r Sys.Date()`"
weight : 51
chapter : false
pre : " <b> 5.1 </b> "
---

# Ví dụ: Setup ALB với Advanced Routing

## Tình huống thực tế

Chúng ta có một ứng dụng web với các requirements sau:
- **Frontend**: Serve static files và React app
- **API**: REST API endpoints tại `/api/*`
- **Admin Panel**: Admin interface tại `/admin/*`
- **Health Checks**: Health endpoints cho monitoring
- **SSL/TLS**: HTTPS support với certificate

## Kiến trúc Load Balancing

```
                    Internet
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                Application Load Balancer                   │
│                     (Port 80/443)                         │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
        ▼             ▼             ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│  Frontend   │ │  API Server │ │ Admin Panel │
│ Target Group│ │Target Group │ │Target Group │
│   (Port 80) │ │ (Port 3000) │ │  (Port 80)  │
└─────────────┘ └─────────────┘ └─────────────┘
        │             │             │
        ▼             ▼             ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│   Frontend  │ │  API Tasks  │ │ Admin Tasks │
│    Tasks    │ │             │ │             │
└─────────────┘ └─────────────┘ └─────────────┘
```

## Bước 1: Tạo Application Load Balancer

### Chuẩn bị Environment Variables

```bash
# Load environment từ các bước trước
source workshop-resources.env

# Thêm variables cho ALB
export ALB_NAME="ecommerce-alb"
export CERTIFICATE_DOMAIN="workshop.example.com"

echo "VPC ID: $VPC_ID"
echo "Public Subnets: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"
echo "ALB Security Group: $ALB_SG"
```

### Tạo ALB

```bash
# Tạo Application Load Balancer
echo "🚀 Đang tạo Application Load Balancer..."

ALB_ARN=$(aws elbv2 create-load-balancer \
    --name $ALB_NAME \
    --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 \
    --security-groups $ALB_SG \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --tags Key=Name,Value=$ALB_NAME Key=Environment,Value=workshop \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

echo "✅ ALB ARN: $ALB_ARN"

# Lấy ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "✅ ALB DNS Name: $ALB_DNS"

# Lưu vào environment file
echo "export ALB_ARN=$ALB_ARN" >> workshop-resources.env
echo "export ALB_DNS=$ALB_DNS" >> workshop-resources.env
```

### Chờ ALB Available

```bash
echo "⏳ Đang chờ ALB available..."
aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN
echo "✅ ALB đã sẵn sàng!"
```

### Xác minh ALB trong Console

**Tương tác với Console:**
1. Truy cập [EC2 Console - Load Balancers](https://console.aws.amazon.com/ec2/#LoadBalancers)
2. Tìm ALB với tên `ecommerce-alb`
3. Kiểm tra:
   - State: Active
   - Scheme: Internet-facing
   - VPC: Đúng VPC ID
   - Availability Zones: 2 AZs với public subnets

## Bước 2: Tạo Target Groups

### Frontend Target Group

```bash
echo "🎯 Đang tạo Frontend Target Group..."

FRONTEND_TG_ARN=$(aws elbv2 create-target-group \
    --name ecommerce-frontend-tg \
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
    --tags Key=Name,Value=ecommerce-frontend-tg Key=Service,Value=frontend \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "✅ Frontend Target Group: $FRONTEND_TG_ARN"
```

### API Target Group

```bash
echo "🎯 Đang tạo API Target Group..."

API_TG_ARN=$(aws elbv2 create-target-group \
    --name ecommerce-api-tg \
    --protocol HTTP \
    --port 3000 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-path /health \
    --health-check-protocol HTTP \
    --health-check-interval-seconds 15 \
    --health-check-timeout-seconds 3 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2 \
    --matcher HttpCode=200 \
    --tags Key=Name,Value=ecommerce-api-tg Key=Service,Value=api \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "✅ API Target Group: $API_TG_ARN"
```

### Admin Target Group

```bash
echo "🎯 Đang tạo Admin Target Group..."

ADMIN_TG_ARN=$(aws elbv2 create-target-group \
    --name ecommerce-admin-tg \
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
    --tags Key=Name,Value=ecommerce-admin-tg Key=Service,Value=admin \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "✅ Admin Target Group: $ADMIN_TG_ARN"

# Lưu Target Group ARNs
echo "export FRONTEND_TG_ARN=$FRONTEND_TG_ARN" >> workshop-resources.env
echo "export API_TG_ARN=$API_TG_ARN" >> workshop-resources.env
echo "export ADMIN_TG_ARN=$ADMIN_TG_ARN" >> workshop-resources.env
```

### Xác minh Target Groups

```bash
# List tất cả target groups
aws elbv2 describe-target-groups \
    --target-group-arns $FRONTEND_TG_ARN $API_TG_ARN $ADMIN_TG_ARN \
    --query 'TargetGroups[].{
        Name:TargetGroupName,
        Port:Port,
        Protocol:Protocol,
        HealthCheckPath:HealthCheckPath,
        HealthyThreshold:HealthyThresholdCount
    }'
```

**Output mẫu:**
```json
[
    {
        "Name": "ecommerce-frontend-tg",
        "Port": 80,
        "Protocol": "HTTP", 
        "HealthCheckPath": "/",
        "HealthyThreshold": 2
    },
    {
        "Name": "ecommerce-api-tg",
        "Port": 3000,
        "Protocol": "HTTP",
        "HealthCheckPath": "/health", 
        "HealthyThreshold": 2
    },
    {
        "Name": "ecommerce-admin-tg",
        "Port": 80,
        "Protocol": "HTTP",
        "HealthCheckPath": "/admin/health",
        "HealthyThreshold": 2
    }
]
```

## Bước 3: Tạo Listeners và Routing Rules

### HTTP Listener (Port 80)

```bash
echo "👂 Đang tạo HTTP Listener..."

HTTP_LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$FRONTEND_TG_ARN \
    --tags Key=Name,Value=ecommerce-http-listener \
    --query 'Listeners[0].ListenerArn' \
    --output text)

echo "✅ HTTP Listener: $HTTP_LISTENER_ARN"
echo "export HTTP_LISTENER_ARN=$HTTP_LISTENER_ARN" >> workshop-resources.env
```

### Path-based Routing Rules

#### Rule cho API endpoints (/api/*)

```bash
echo "📋 Đang tạo API routing rule..."

aws elbv2 create-rule \
    --listener-arn $HTTP_LISTENER_ARN \
    --priority 100 \
    --conditions Field=path-pattern,Values="/api/*" \
    --actions Type=forward,TargetGroupArn=$API_TG_ARN \
    --tags Key=Name,Value=api-path-rule Key=Service,Value=api

echo "✅ API routing rule đã được tạo (Priority: 100)"
```

#### Rule cho Admin panel (/admin/*)

```bash
echo "📋 Đang tạo Admin routing rule..."

aws elbv2 create-rule \
    --listener-arn $HTTP_LISTENER_ARN \
    --priority 200 \
    --conditions Field=path-pattern,Values="/admin/*" \
    --actions Type=forward,TargetGroupArn=$ADMIN_TG_ARN \
    --tags Key=Name,Value=admin-path-rule Key=Service,Value=admin

echo "✅ Admin routing rule đã được tạo (Priority: 200)"
```

#### Rule cho Health checks

```bash
echo "📋 Đang tạo Health check routing rule..."

aws elbv2 create-rule \
    --listener-arn $HTTP_LISTENER_ARN \
    --priority 50 \
    --conditions Field=path-pattern,Values="/health" \
    --actions Type=fixed-response,FixedResponseConfig='{
        StatusCode=200,
        ContentType=application/json,
        MessageBody="{\"status\":\"healthy\",\"service\":\"load-balancer\"}"
    }' \
    --tags Key=Name,Value=health-check-rule

echo "✅ Health check rule đã được tạo (Priority: 50)"
```

### Advanced Routing Rules

#### Header-based Routing (Mobile clients)

```bash
echo "📋 Đang tạo Mobile routing rule..."

aws elbv2 create-rule \
    --listener-arn $HTTP_LISTENER_ARN \
    --priority 25 \
    --conditions Field=http-header,HttpHeaderConfig='{
        HttpHeaderName=User-Agent,
        Values=["*Mobile*","*Android*","*iPhone*","*iPad*"]
    }' \
    --actions Type=forward,TargetGroupArn=$FRONTEND_TG_ARN \
    --tags Key=Name,Value=mobile-header-rule Key=Client,Value=mobile

echo "✅ Mobile routing rule đã được tạo (Priority: 25)"
```

#### Query String Routing (API versioning)

```bash
echo "📋 Đang tạo API version routing rule..."

aws elbv2 create-rule \
    --listener-arn $HTTP_LISTENER_ARN \
    --priority 75 \
    --conditions Field=query-string,QueryStringConfig='{
        Values=[{Key=version,Value=v2},{Key=api_version,Value=2.0}]
    }' \
    --actions Type=forward,TargetGroupArn=$API_TG_ARN \
    --tags Key=Name,Value=api-version-rule Key=Version,Value=v2

echo "✅ API version routing rule đã được tạo (Priority: 75)"
```

### Xác minh Routing Rules

```bash
# List tất cả rules cho listener
aws elbv2 describe-rules --listener-arn $HTTP_LISTENER_ARN \
    --query 'Rules[].{
        Priority:Priority,
        Conditions:Conditions[0],
        Actions:Actions[0].Type
    }' | jq '.'
```

**Output mẫu:**
```json
[
    {
        "Priority": "25",
        "Conditions": {
            "Field": "http-header",
            "HttpHeaderConfig": {
                "HttpHeaderName": "User-Agent",
                "Values": ["*Mobile*", "*Android*", "*iPhone*", "*iPad*"]
            }
        },
        "Actions": "forward"
    },
    {
        "Priority": "50", 
        "Conditions": {
            "Field": "path-pattern",
            "Values": ["/health"]
        },
        "Actions": "fixed-response"
    },
    {
        "Priority": "100",
        "Conditions": {
            "Field": "path-pattern", 
            "Values": ["/api/*"]
        },
        "Actions": "forward"
    }
]
```

## Bước 4: SSL/TLS Configuration

### Request SSL Certificate

```bash
echo "🔒 Đang request SSL certificate..."

# Request certificate cho domain
CERT_ARN=$(aws acm request-certificate \
    --domain-name $CERTIFICATE_DOMAIN \
    --subject-alternative-names "*.${CERTIFICATE_DOMAIN}" \
    --validation-method DNS \
    --tags Key=Name,Value=ecommerce-ssl-cert Key=Domain,Value=$CERTIFICATE_DOMAIN \
    --query 'CertificateArn' \
    --output text)

echo "✅ Certificate ARN: $CERT_ARN"
echo "export CERT_ARN=$CERT_ARN" >> workshop-resources.env

# Lấy DNS validation records
aws acm describe-certificate --certificate-arn $CERT_ARN \
    --query 'Certificate.DomainValidationOptions[].ResourceRecord' \
    --output table

echo "📝 Thêm DNS records trên để validate certificate"
echo "⏳ Certificate sẽ được issued sau khi DNS validation hoàn thành"
```

### HTTPS Listener (sau khi certificate được issued)

```bash
# Chờ certificate được issued (có thể mất 5-30 phút)
echo "⏳ Đang chờ certificate được issued..."

# Monitor certificate status
while true; do
    STATUS=$(aws acm describe-certificate --certificate-arn $CERT_ARN \
        --query 'Certificate.Status' --output text)
    echo "$(date): Certificate status: $STATUS"
    
    if [ "$STATUS" = "ISSUED" ]; then
        echo "✅ Certificate đã được issued!"
        break
    elif [ "$STATUS" = "FAILED" ]; then
        echo "❌ Certificate validation failed!"
        exit 1
    fi
    
    sleep 60
done

# Tạo HTTPS listener
echo "👂 Đang tạo HTTPS Listener..."

HTTPS_LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTPS \
    --port 443 \
    --certificates CertificateArn=$CERT_ARN \
    --ssl-policy ELBSecurityPolicy-TLS-1-2-2017-01 \
    --default-actions Type=forward,TargetGroupArn=$FRONTEND_TG_ARN \
    --tags Key=Name,Value=ecommerce-https-listener \
    --query 'Listeners[0].ListenerArn' \
    --output text)

echo "✅ HTTPS Listener: $HTTPS_LISTENER_ARN"
echo "export HTTPS_LISTENER_ARN=$HTTPS_LISTENER_ARN" >> workshop-resources.env
```

### HTTP to HTTPS Redirect

```bash
# Cập nhật HTTP listener để redirect sang HTTPS
aws elbv2 modify-listener \
    --listener-arn $HTTP_LISTENER_ARN \
    --default-actions Type=redirect,RedirectConfig='{
        Protocol=HTTPS,
        Port=443,
        StatusCode=HTTP_301
    }'

echo "✅ HTTP to HTTPS redirect đã được cấu hình"
```

## Bước 5: Advanced Target Group Configuration

### Sticky Sessions cho Frontend

```bash
echo "🍪 Đang cấu hình sticky sessions cho Frontend..."

aws elbv2 modify-target-group-attributes \
    --target-group-arn $FRONTEND_TG_ARN \
    --attributes \
        Key=stickiness.enabled,Value=true \
        Key=stickiness.type,Value=lb_cookie \
        Key=stickiness.lb_cookie.duration_seconds,Value=86400

echo "✅ Sticky sessions enabled cho Frontend (24 hours)"
```

### Connection Draining

```bash
echo "🔄 Đang cấu hình connection draining..."

# API target group - fast draining
aws elbv2 modify-target-group-attributes \
    --target-group-arn $API_TG_ARN \
    --attributes Key=deregistration_delay.timeout_seconds,Value=30

# Frontend target group - longer draining
aws elbv2 modify-target-group-attributes \
    --target-group-arn $FRONTEND_TG_ARN \
    --attributes Key=deregistration_delay.timeout_seconds,Value=60

echo "✅ Connection draining configured"
```

### Health Check Optimization

```bash
echo "🏥 Đang tối ưu health check settings..."

# Optimize API health checks (faster response)
aws elbv2 modify-target-group \
    --target-group-arn $API_TG_ARN \
    --health-check-interval-seconds 10 \
    --health-check-timeout-seconds 2 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2

# Custom health check cho Admin
aws elbv2 modify-target-group \
    --target-group-arn $ADMIN_TG_ARN \
    --health-check-path /admin/health \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --matcher HttpCode="200,202"

echo "✅ Health check settings optimized"
```

## Bước 6: Testing Load Balancer

### Basic Connectivity Tests

```bash
echo "🧪 Đang test basic connectivity..."

# Test default route (Frontend)
echo "Testing Frontend (default route):"
curl -s -o /dev/null -w "HTTP Status: %{http_code}, Response Time: %{time_total}s\n" \
    http://$ALB_DNS/

# Test API route
echo "Testing API route:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}, Response Time: %{time_total}s\n" \
    http://$ALB_DNS/api/health

# Test Admin route
echo "Testing Admin route:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}, Response Time: %{time_total}s\n" \
    http://$ALB_DNS/admin/health

# Test Health endpoint
echo "Testing Health endpoint:"
curl -s http://$ALB_DNS/health | jq '.'
```

### Advanced Routing Tests

```bash
echo "🧪 Đang test advanced routing..."

# Test Mobile User-Agent routing
echo "Testing Mobile routing:"
curl -s -H "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)" \
    -o /dev/null -w "HTTP Status: %{http_code}\n" \
    http://$ALB_DNS/

# Test API versioning
echo "Testing API versioning:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
    "http://$ALB_DNS/api/products?version=v2"

# Test HTTPS redirect
echo "Testing HTTPS redirect:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}, Redirect URL: %{redirect_url}\n" \
    http://$ALB_DNS/
```

### Load Distribution Test

```bash
echo "🧪 Đang test load distribution..."

# Test multiple requests để xem load balancing
echo "Testing load distribution (10 requests):"
for i in {1..10}; do
    RESPONSE=$(curl -s -w "Request $i: %{time_total}s\n" \
        -H "X-Request-ID: test-$i" \
        http://$ALB_DNS/api/health)
    echo "$RESPONSE"
    sleep 1
done
```

## Bước 7: Monitor Target Health

### Check Target Health Status

```bash
echo "🏥 Đang kiểm tra target health..."

# Frontend targets
echo "=== Frontend Target Health ==="
aws elbv2 describe-target-health --target-group-arn $FRONTEND_TG_ARN \
    --query 'TargetHealthDescriptions[].{
        Target:Target.Id,
        Port:Target.Port,
        Health:TargetHealth.State,
        Description:TargetHealth.Description
    }'

# API targets  
echo "=== API Target Health ==="
aws elbv2 describe-target-health --target-group-arn $API_TG_ARN \
    --query 'TargetHealthDescriptions[].{
        Target:Target.Id,
        Port:Target.Port, 
        Health:TargetHealth.State,
        Description:TargetHealth.Description
    }'

# Admin targets
echo "=== Admin Target Health ==="
aws elbv2 describe-target-health --target-group-arn $ADMIN_TG_ARN \
    --query 'TargetHealthDescriptions[].{
        Target:Target.Id,
        Port:Target.Port,
        Health:TargetHealth.State, 
        Description:TargetHealth.Description
    }'
```

### Monitor ALB Metrics

```bash
echo "📊 Đang lấy ALB metrics..."

# Request count trong 1 giờ qua
aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-) \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum \
    --query 'Datapoints[].{Time:Timestamp,Requests:Sum}' \
    --output table

# Response time
aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name TargetResponseTime \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-) \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average \
    --query 'Datapoints[].{Time:Timestamp,ResponseTime:Average}' \
    --output table
```

## Troubleshooting Common Issues

### Issue 1: Target Health Check Failures

**Symptoms**: Targets showing as unhealthy

**Debug Steps**:
```bash
# Kiểm tra target health details
aws elbv2 describe-target-health --target-group-arn $API_TG_ARN

# Kiểm tra security group rules
aws ec2 describe-security-groups --group-ids $ECS_SG \
    --query 'SecurityGroups[0].IpPermissions[?FromPort==`3000`]'

# Test health check endpoint directly
curl -v http://TASK_PRIVATE_IP:3000/health
```

**Common Solutions**:
- Verify security group allows ALB to reach targets
- Check health check path returns 200 status
- Adjust health check timeout/interval

### Issue 2: Routing Rules Not Working

**Symptoms**: Requests không route đến đúng target group

**Debug Steps**:
```bash
# Kiểm tra rule priority và conditions
aws elbv2 describe-rules --listener-arn $HTTP_LISTENER_ARN \
    --query 'Rules[].{Priority:Priority,Conditions:Conditions}'

# Test với specific headers/paths
curl -v -H "User-Agent: iPhone" http://$ALB_DNS/
curl -v http://$ALB_DNS/api/test
```

**Common Solutions**:
- Check rule priority (lower number = higher priority)
- Verify condition syntax
- Test conditions với curl

### Issue 3: SSL Certificate Issues

**Symptoms**: HTTPS listener không hoạt động

**Debug Steps**:
```bash
# Kiểm tra certificate status
aws acm describe-certificate --certificate-arn $CERT_ARN \
    --query 'Certificate.{Status:Status,DomainValidationOptions:DomainValidationOptions}'

# Test SSL connection
openssl s_client -connect $ALB_DNS:443 -servername $CERTIFICATE_DOMAIN
```

**Common Solutions**:
- Complete DNS validation cho certificate
- Verify domain name matches certificate
- Check SSL policy compatibility

## Performance Optimization

### Connection Settings

```bash
# Optimize connection handling
aws elbv2 modify-load-balancer-attributes \
    --load-balancer-arn $ALB_ARN \
    --attributes \
        Key=idle_timeout.timeout_seconds,Value=60 \
        Key=routing.http2.enabled,Value=true \
        Key=access_logs.s3.enabled,Value=true \
        Key=access_logs.s3.bucket,Value=my-alb-logs-bucket
```

### Target Group Optimization

```bash
# Optimize target group settings
aws elbv2 modify-target-group-attributes \
    --target-group-arn $API_TG_ARN \
    --attributes \
        Key=slow_start.duration_seconds,Value=30 \
        Key=load_balancing.algorithm.type,Value=least_outstanding_requests
```

## Summary

Trong ví dụ này, chúng ta đã:

1. ✅ Tạo Application Load Balancer với multi-AZ setup
2. ✅ Setup 3 target groups cho different services
3. ✅ Cấu hình advanced routing rules (path, header, query string)
4. ✅ Implement SSL/TLS với ACM certificate
5. ✅ Configure sticky sessions và connection draining
6. ✅ Optimize health checks cho từng service
7. ✅ Test load balancing và routing functionality
8. ✅ Monitor target health và ALB metrics

**Kết quả**: Một production-ready load balancer với advanced routing capabilities, SSL termination, và comprehensive health monitoring.

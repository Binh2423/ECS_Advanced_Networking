---
title : "Cấu hình Load Balancing"
date : "`r Sys.Date()`"
weight : 5
chapter : false
pre : " <b> 5. </b> "
---

## Tổng quan Load Balancing

Application Load Balancer (ALB) sẽ distribute traffic từ internet đến các ECS services. ALB hoạt động ở Layer 7 và hỗ trợ path-based routing, health checks, và SSL termination.

{{< alert type="info" title="Lợi ích của ALB" >}}
- **Layer 7 Load Balancing:** HTTP/HTTPS traffic distribution
- **Path-based Routing:** Route traffic dựa trên URL paths
- **Health Checks:** Automatic health monitoring
- **SSL Termination:** Handle SSL certificates
- **Integration:** Native integration với ECS services
{{< /alert >}}

## Bước 1: Load Environment

```bash
# Load workshop environment
cd ~/ecs-workshop
source workshop-env.sh

# Verify required variables
for var in VPC_ID ALB_SG PUBLIC_SUBNET_1 PUBLIC_SUBNET_2 ECS_SG; do
    if [ -z "${!var}" ]; then
        echo "❌ $var not found. Please complete previous steps."
        exit 1
    fi
done

echo "✅ Environment loaded successfully"
```

## Bước 2: Tạo Application Load Balancer

### 2.1 Create ALB

{{< console-screenshot src="images/alb-console-overview.png" alt="ALB Console Overview" caption="Application Load Balancer console hiển thị load balancers và configuration details" service="EC2 Console" >}}

```bash
echo "⚖️ Creating Application Load Balancer..."

# Create ALB
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name ecs-workshop-alb \
    --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 \
    --security-groups $ALB_SG \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --tags Key=Environment,Value=workshop Key=Project,Value=ecs-networking \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

echo "✅ ALB created: $ALB_ARN"
echo "export ALB_ARN=$ALB_ARN" >> workshop-env.sh

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "✅ ALB DNS Name: $ALB_DNS"
echo "export ALB_DNS=$ALB_DNS" >> workshop-env.sh
```

### 2.2 Wait for ALB to be Active

```bash
echo "⏳ Waiting for ALB to be active..."

# Wait for ALB to be active
aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN

echo "✅ ALB is now active"
```

## Bước 3: Tạo Target Groups

### 3.1 Frontend Target Group

{{< console-screenshot src="images/alb-target-groups.png" alt="ALB Target Groups" caption="Target Groups console hiển thị health check status và registered targets" service="EC2 Console" >}}

```bash
echo "🎯 Creating Target Groups..."

# Create target group cho frontend
FRONTEND_TG_ARN=$(aws elbv2 create-target-group \
    --name ecs-workshop-frontend-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-protocol HTTP \
    --health-check-path / \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --tags Key=Environment,Value=workshop Key=Service,Value=frontend \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "✅ Frontend Target Group: $FRONTEND_TG_ARN"
echo "export FRONTEND_TG_ARN=$FRONTEND_TG_ARN" >> workshop-env.sh
```

### 3.2 API Target Group

```bash
# Create target group cho API
API_TG_ARN=$(aws elbv2 create-target-group \
    --name ecs-workshop-api-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-protocol HTTP \
    --health-check-path / \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --tags Key=Environment,Value=workshop Key=Service,Value=api \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "✅ API Target Group: $API_TG_ARN"
echo "export API_TG_ARN=$API_TG_ARN" >> workshop-env.sh
```

### 3.3 Default Target Group

```bash
# Create default target group (for unmatched requests)
DEFAULT_TG_ARN=$(aws elbv2 create-target-group \
    --name ecs-workshop-default-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-protocol HTTP \
    --health-check-path / \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --tags Key=Environment,Value=workshop Key=Service,Value=default \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "✅ Default Target Group: $DEFAULT_TG_ARN"
echo "export DEFAULT_TG_ARN=$DEFAULT_TG_ARN" >> workshop-env.sh
```

## Bước 4: Tạo ALB Listeners và Rules

### 4.1 Create HTTP Listener

```bash
echo "👂 Creating ALB Listener..."

# Create HTTP listener với default action
LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$FRONTEND_TG_ARN \
    --tags Key=Environment,Value=workshop \
    --query 'Listeners[0].ListenerArn' \
    --output text)

echo "✅ HTTP Listener created: $LISTENER_ARN"
echo "export LISTENER_ARN=$LISTENER_ARN" >> workshop-env.sh
```

### 4.2 Create Listener Rules

```bash
echo "📋 Creating Listener Rules..."

# Rule cho API path
API_RULE_ARN=$(aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 100 \
    --conditions Field=path-pattern,Values="/api/*" \
    --actions Type=forward,TargetGroupArn=$API_TG_ARN \
    --tags Key=Environment,Value=workshop Key=Service,Value=api \
    --query 'Rules[0].RuleArn' \
    --output text)

echo "✅ API Rule created: $API_RULE_ARN"

# Rule cho health check
HEALTH_RULE_ARN=$(aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 200 \
    --conditions Field=path-pattern,Values="/health" \
    --actions Type=fixed-response,FixedResponseConfig='{StatusCode=200,ContentType=text/plain,MessageBody=OK}' \
    --tags Key=Environment,Value=workshop Key=Service,Value=health \
    --query 'Rules[0].RuleArn' \
    --output text)

echo "✅ Health Rule created: $HEALTH_RULE_ARN"
```

## Bước 5: Update ECS Services với Load Balancer

### 5.1 Update Frontend Service

```bash
echo "🔄 Updating ECS Services với Load Balancer..."

# Update frontend service với target group
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service workshop-frontend \
    --load-balancers targetGroupArn=$FRONTEND_TG_ARN,containerName=frontend,containerPort=80

echo "✅ Frontend service updated với ALB"
```

### 5.2 Update API Service

```bash
# Update API service với target group
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service workshop-api \
    --load-balancers targetGroupArn=$API_TG_ARN,containerName=api,containerPort=80

echo "✅ API service updated với ALB"
```

### 5.3 Wait for Service Updates

```bash
echo "⏳ Waiting for service updates to complete..."

# Wait for services to be stable
aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services workshop-frontend workshop-api

echo "✅ All services are stable với load balancer"
```

## Bước 6: Verify Target Health

### 6.1 Check Target Group Health

```bash
echo "🏥 Checking target group health..."

# Check frontend targets
echo "=== Frontend Target Health ==="
aws elbv2 describe-target-health \
    --target-group-arn $FRONTEND_TG_ARN \
    --query 'TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,Health:TargetHealth.State,Description:TargetHealth.Description}'

# Check API targets
echo "=== API Target Health ==="
aws elbv2 describe-target-health \
    --target-group-arn $API_TG_ARN \
    --query 'TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,Health:TargetHealth.State,Description:TargetHealth.Description}'
```

### 6.2 Wait for Healthy Targets

```bash
echo "⏳ Waiting for targets to become healthy..."

# Function to check if targets are healthy
check_target_health() {
    local tg_arn=$1
    local healthy_count=$(aws elbv2 describe-target-health \
        --target-group-arn $tg_arn \
        --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])')
    echo $healthy_count
}

# Wait for at least 1 healthy target in each group
while true; do
    frontend_healthy=$(check_target_health $FRONTEND_TG_ARN)
    api_healthy=$(check_target_health $API_TG_ARN)
    
    echo "Frontend healthy targets: $frontend_healthy"
    echo "API healthy targets: $api_healthy"
    
    if [ "$frontend_healthy" -gt 0 ] && [ "$api_healthy" -gt 0 ]; then
        echo "✅ All target groups have healthy targets"
        break
    fi
    
    echo "⏳ Waiting for targets to become healthy..."
    sleep 30
done
```

## Bước 7: Test Load Balancer

### 7.1 Test HTTP Endpoints

```bash
echo "🧪 Testing Load Balancer endpoints..."

# Test frontend endpoint
echo "=== Testing Frontend ==="
curl -s -o /dev/null -w "HTTP Status: %{http_code}\nResponse Time: %{time_total}s\n" http://$ALB_DNS/

# Test API endpoint
echo "=== Testing API ==="
curl -s -o /dev/null -w "HTTP Status: %{http_code}\nResponse Time: %{time_total}s\n" http://$ALB_DNS/api/

# Test health endpoint
echo "=== Testing Health Check ==="
curl -s -w "HTTP Status: %{http_code}\n" http://$ALB_DNS/health
```

### 7.2 Load Testing

```bash
echo "🔄 Running basic load test..."

# Simple load test với curl
for i in {1..10}; do
    echo "Request $i:"
    curl -s -o /dev/null -w "Status: %{http_code}, Time: %{time_total}s\n" http://$ALB_DNS/
    sleep 1
done

echo "✅ Load test completed"
```

## Bước 8: Advanced Load Balancer Features

### 8.1 Enable Access Logs

```bash
echo "📊 Enabling ALB Access Logs..."

# Create S3 bucket cho access logs
BUCKET_NAME="ecs-workshop-alb-logs-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region $AWS_DEFAULT_REGION

# Set bucket policy cho ALB access logs
cat > alb-logs-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::$(aws elbv2 describe-load-balancer-attributes --load-balancer-arn $ALB_ARN --query 'Attributes[?Key==`access_logs.s3.bucket`].Value' --output text | xargs aws sts get-caller-identity --query Account --output text):root"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::$BUCKET_NAME/AWSLogs/$(aws sts get-caller-identity --query Account --output text)/*"
        }
    ]
}
EOF

aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy file://alb-logs-policy.json

# Enable access logs
aws elbv2 modify-load-balancer-attributes \
    --load-balancer-arn $ALB_ARN \
    --attributes Key=access_logs.s3.enabled,Value=true Key=access_logs.s3.bucket,Value=$BUCKET_NAME

echo "✅ Access logs enabled: s3://$BUCKET_NAME"
echo "export ALB_LOGS_BUCKET=$BUCKET_NAME" >> workshop-env.sh
```

### 8.2 Configure Connection Draining

```bash
echo "🔄 Configuring connection draining..."

# Set deregistration delay
aws elbv2 modify-target-group-attributes \
    --target-group-arn $FRONTEND_TG_ARN \
    --attributes Key=deregistration_delay.timeout_seconds,Value=30

aws elbv2 modify-target-group-attributes \
    --target-group-arn $API_TG_ARN \
    --attributes Key=deregistration_delay.timeout_seconds,Value=30

echo "✅ Connection draining configured (30 seconds)"
```

### 8.3 Enable Sticky Sessions (if needed)

```bash
echo "🍪 Configuring sticky sessions cho frontend..."

# Enable sticky sessions cho frontend
aws elbv2 modify-target-group-attributes \
    --target-group-arn $FRONTEND_TG_ARN \
    --attributes Key=stickiness.enabled,Value=true Key=stickiness.type,Value=lb_cookie Key=stickiness.lb_cookie.duration_seconds,Value=86400

echo "✅ Sticky sessions enabled cho frontend"
```

## Bước 9: Monitoring và Metrics

### 9.1 CloudWatch Metrics

```bash
echo "📈 Setting up CloudWatch metrics..."

# Get ALB metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-) \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum \
    --query 'Datapoints[].{Time:Timestamp,Requests:Sum}'
```

### 9.2 Create CloudWatch Dashboard

```bash
echo "📊 Creating ALB Dashboard..."

# Create dashboard cho ALB metrics
cat > alb-dashboard.json << EOF
{
    "widgets": [
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
                "period": 300,
                "stat": "Sum",
                "region": "$AWS_DEFAULT_REGION",
                "title": "ALB Metrics"
            }
        },
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", "$(echo $FRONTEND_TG_ARN | cut -d'/' -f2-)"],
                    [".", "UnHealthyHostCount", ".", "."],
                    [".", "HealthyHostCount", ".", "$(echo $API_TG_ARN | cut -d'/' -f2-)"],
                    [".", "UnHealthyHostCount", ".", "."]
                ],
                "period": 300,
                "stat": "Average",
                "region": "$AWS_DEFAULT_REGION",
                "title": "Target Health"
            }
        }
    ]
}
EOF

aws cloudwatch put-dashboard \
    --dashboard-name "ECS-Workshop-ALB" \
    --dashboard-body file://alb-dashboard.json

echo "✅ ALB Dashboard created"
```

## Bước 10: SSL/TLS Configuration (Optional)

### 10.1 Request SSL Certificate

```bash
echo "🔒 Requesting SSL Certificate (optional)..."

# Request certificate từ ACM (requires domain validation)
# CERT_ARN=$(aws acm request-certificate \
#     --domain-name your-domain.com \
#     --validation-method DNS \
#     --query 'CertificateArn' \
#     --output text)

# echo "✅ Certificate requested: $CERT_ARN"
# echo "export CERT_ARN=$CERT_ARN" >> workshop-env.sh

echo "ℹ️  SSL certificate setup skipped (requires domain ownership)"
```

## Troubleshooting

### Common Issues

**1. Targets unhealthy:**
```bash
# Check target health details
aws elbv2 describe-target-health --target-group-arn $FRONTEND_TG_ARN

# Check security group rules
aws ec2 describe-security-groups --group-ids $ECS_SG $ALB_SG
```

**2. ALB not accessible:**
```bash
# Check ALB state
aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN

# Check security group rules
aws ec2 describe-security-groups --group-ids $ALB_SG --query 'SecurityGroups[0].IpPermissions'
```

**3. 503 Service Unavailable:**
```bash
# Check if targets are registered
aws elbv2 describe-target-health --target-group-arn $FRONTEND_TG_ARN

# Check ECS service status
aws ecs describe-services --cluster $CLUSTER_NAME --services workshop-frontend
```

**4. Path routing not working:**
```bash
# Check listener rules
aws elbv2 describe-rules --listener-arn $LISTENER_ARN

# Test specific paths
curl -v http://$ALB_DNS/api/
```

## Tóm tắt

Bạn đã thành công cấu hình Load Balancing với:

- ✅ **Application Load Balancer** trong public subnets
- ✅ **Target Groups** cho frontend và API services
- ✅ **Path-based Routing** (/api/* → API service)
- ✅ **Health Checks** và monitoring
- ✅ **ECS Integration** với automatic target registration
- ✅ **CloudWatch Metrics** và dashboard
- ✅ **Access Logs** và advanced features

**Load Balancing Architecture:**
```
Internet → ALB (Public Subnets)
├── / → Frontend Target Group → Frontend ECS Tasks
├── /api/* → API Target Group → API ECS Tasks
└── /health → Fixed Response (200 OK)

Traffic Flow:
Client → ALB → Target Group → Healthy ECS Tasks
```

## Bước tiếp theo

Load Balancer đã hoạt động! Tiếp theo chúng ta sẽ [tăng cường Security](../6-security/) với advanced security groups, secrets management, và network monitoring.

---

{{< alert type="tip" title="Pro Tip" >}}
Sử dụng `curl -v http://$ALB_DNS/` để test load balancer và xem response headers!
{{< /alert >}}

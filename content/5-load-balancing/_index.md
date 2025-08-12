---
title : "Advanced Load Balancing"
date : "`r Sys.Date()`"
weight : 5
chapter : false
pre : " <b> 5. </b> "
---

# Advanced Load Balancing

In this section, we'll implement advanced load balancing strategies for our ECS services using Application Load Balancer (ALB) with sophisticated routing rules, health checks, and traffic distribution patterns.

## Load Balancing Overview

Application Load Balancer provides Layer 7 load balancing capabilities that enable:
- **Path-based routing**: Route traffic based on URL paths
- **Host-based routing**: Route traffic based on host headers
- **Health checks**: Monitor application health and route traffic accordingly
- **SSL/TLS termination**: Handle encryption/decryption at the load balancer
- **WebSocket support**: Support for real-time applications

## Architecture

We'll create the following load balancing setup:

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

## Step 1: Load Environment Variables

```bash
# Load environment variables
source workshop-resources.env

# Verify variables are loaded
echo "VPC ID: $VPC_ID"
echo "Public Subnets: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"
echo "ALB Security Group: $ALB_SG"
```

## Step 2: Create Application Load Balancer

### 2.1 Create Application Load Balancer
```bash
# Create Application Load Balancer
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

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "ALB DNS Name: $ALB_DNS"
```

### 2.2 Wait for ALB to be Active
```bash
# Wait for ALB to be active
echo "Waiting for ALB to be active..."
aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN
echo "ALB is now active"
```

## Step 3: Create Target Groups

### 3.1 Create Web Service Target Group
```bash
# Create target group for web service
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

### 3.2 Create API Service Target Group
```bash
# Create target group for API service
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

### 3.3 Create Admin Service Target Group
```bash
# Create target group for admin service
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

## Step 4: Create Listeners and Rules

### 4.1 Create Default Listener
```bash
# Create default listener (HTTP)
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

### 4.2 Create Path-based Routing Rules
```bash
# Create rule for API path
aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 100 \
    --conditions Field=path-pattern,Values="/api/*" \
    --actions Type=forward,TargetGroupArn=$API_TG_ARN \
    --tags Key=Name,Value=API-Path-Rule

# Create rule for admin path
aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 200 \
    --conditions Field=path-pattern,Values="/admin/*" \
    --actions Type=forward,TargetGroupArn=$ADMIN_TG_ARN \
    --tags Key=Name,Value=Admin-Path-Rule

echo "Routing rules created"
```

## Step 5: Update ECS Services with Load Balancer

### 5.1 Update Web Service
```bash
# Update web service to use load balancer
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service web-service \
    --load-balancers targetGroupArn=$WEB_TG_ARN,containerName=web,containerPort=80

echo "Web service updated with load balancer"
```

### 5.2 Create API Service with Load Balancer
```bash
# Create enhanced API task definition
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

# Create log group and register task definition
aws logs create-log-group --log-group-name /ecs/api-enhanced
aws ecs register-task-definition --cli-input-json file://api-enhanced-task-definition.json

# Update API service
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service api-service \
    --task-definition api-enhanced \
    --load-balancers targetGroupArn=$API_TG_ARN,containerName=api,containerPort=80

echo "API service updated with load balancer"
```

### 5.3 Create Admin Service
```bash
# Create admin task definition
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

# Create log group and register task definition
aws logs create-log-group --log-group-name /ecs/admin-app
aws ecs register-task-definition --cli-input-json file://admin-task-definition.json

# Create admin service
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name admin-service \
    --task-definition admin-app \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --load-balancers targetGroupArn=$ADMIN_TG_ARN,containerName=admin,containerPort=80

echo "Admin service created with load balancer"
```

## Step 6: Advanced Load Balancer Features

### 6.1 Configure Sticky Sessions
```bash
# Enable sticky sessions for web service
aws elbv2 modify-target-group-attributes \
    --target-group-arn $WEB_TG_ARN \
    --attributes Key=stickiness.enabled,Value=true \
                Key=stickiness.type,Value=lb_cookie \
                Key=stickiness.lb_cookie.duration_seconds,Value=86400

echo "Sticky sessions enabled for web service"
```

### 6.2 Configure Connection Draining
```bash
# Configure connection draining
aws elbv2 modify-target-group-attributes \
    --target-group-arn $API_TG_ARN \
    --attributes Key=deregistration_delay.timeout_seconds,Value=30

echo "Connection draining configured"
```

### 6.3 Configure Health Check Settings
```bash
# Optimize health check settings for API service
aws elbv2 modify-target-group \
    --target-group-arn $API_TG_ARN \
    --health-check-interval-seconds 15 \
    --health-check-timeout-seconds 3 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2

echo "Health check settings optimized"
```

## Step 7: SSL/TLS Configuration (Optional)

### 7.1 Request SSL Certificate
```bash
# Request SSL certificate (replace with your domain)
CERT_ARN=$(aws acm request-certificate \
    --domain-name workshop.example.com \
    --subject-alternative-names "*.workshop.example.com" \
    --validation-method DNS \
    --query 'CertificateArn' \
    --output text)

echo "Certificate ARN: $CERT_ARN"
echo "Note: You need to validate the certificate via DNS before using it"
```

### 7.2 Create HTTPS Listener (after certificate validation)
```bash
# Create HTTPS listener (uncomment after certificate validation)
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

## Step 8: Testing Load Balancer

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
# Test load distribution with multiple requests
echo "Testing load distribution:"
for i in {1..10}; do
    curl -s http://$ALB_DNS/ | head -1
    sleep 1
done
```

### 8.3 Monitor Target Health
```bash
# Check target health for all target groups
echo "Web service target health:"
aws elbv2 describe-target-health --target-group-arn $WEB_TG_ARN

echo "API service target health:"
aws elbv2 describe-target-health --target-group-arn $API_TG_ARN

echo "Admin service target health:"
aws elbv2 describe-target-health --target-group-arn $ADMIN_TG_ARN
```

## Step 9: Advanced Routing Scenarios

### 9.1 Header-based Routing
```bash
# Create rule for mobile clients
aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 50 \
    --conditions Field=http-header,HttpHeaderConfig='{HttpHeaderName=User-Agent,Values=["*Mobile*","*Android*","*iPhone*"]}' \
    --actions Type=forward,TargetGroupArn=$WEB_TG_ARN \
    --tags Key=Name,Value=Mobile-Header-Rule

echo "Header-based routing rule created"
```

### 9.2 Query String Routing
```bash
# Create rule for API version routing
aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 75 \
    --conditions Field=query-string,QueryStringConfig='{Values=[{Key=version,Value=v2}]}' \
    --actions Type=forward,TargetGroupArn=$API_TG_ARN \
    --tags Key=Name,Value=Version-Query-Rule

echo "Query string routing rule created"
```

## Step 10: Update Environment Variables

```bash
# Update environment variables file
cat >> workshop-resources.env << EOF
export ALB_ARN=$ALB_ARN
export ALB_DNS=$ALB_DNS
export LISTENER_ARN=$LISTENER_ARN
export WEB_TG_ARN=$WEB_TG_ARN
export API_TG_ARN=$API_TG_ARN
export ADMIN_TG_ARN=$ADMIN_TG_ARN
EOF

echo "Load balancer resources added to workshop-resources.env"
```

## Monitoring and Troubleshooting

### Common Issues

1. **Target Health Check Failures**
   - Verify security group rules allow ALB to reach targets
   - Check health check path and expected response codes
   - Ensure application is listening on the correct port

2. **Routing Rules Not Working**
   - Check rule priority (lower numbers have higher priority)
   - Verify condition syntax and values
   - Test with curl using specific headers or paths

3. **SSL Certificate Issues**
   - Ensure certificate is validated and issued
   - Check that certificate covers the domain being used
   - Verify SSL policy compatibility

### Verification Commands
```bash
# Check ALB status
aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN

# List all target groups
aws elbv2 describe-target-groups --load-balancer-arn $ALB_ARN

# Check listener rules
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
   - Use dedicated health check endpoints
   - Set appropriate timeout and interval values
   - Monitor health check metrics

2. **Security**
   - Use HTTPS for production workloads
   - Implement proper security group rules
   - Consider WAF integration for additional protection

3. **Performance**
   - Enable connection draining for graceful shutdowns
   - Use appropriate target group attributes
   - Monitor and optimize based on metrics

4. **Cost Optimization**
   - Use appropriate instance types for targets
   - Monitor unused target groups
   - Consider cross-zone load balancing costs

## Next Steps

Excellent! You've successfully implemented advanced load balancing for your ECS services. Your setup now includes:

- ✅ Application Load Balancer with multiple target groups
- ✅ Path-based routing for different services
- ✅ Health checks and monitoring
- ✅ Advanced routing rules
- ✅ SSL/TLS configuration (optional)

Next, we'll move on to [Security Best Practices](../6-security/) where we'll implement comprehensive security measures for our ECS networking setup.

---

**Resources Created:**
- 1 Application Load Balancer
- 3 Target Groups (Web, API, Admin)
- 1 HTTP Listener with routing rules
- 3 ECS Services with load balancer integration
- Advanced routing rules and health checks

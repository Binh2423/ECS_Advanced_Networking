---
title : "Triển khai Service Discovery"
date : "`r Sys.Date()`"
weight : 4
chapter : false
pre : " <b> 4. </b> "
---

## Tổng quan Service Discovery

Service Discovery cho phép các services tự động tìm thấy và kết nối với nhau thông qua DNS names thay vì hard-coded IP addresses. AWS Cloud Map tích hợp với ECS để cung cấp service discovery tự động.

{{< alert type="info" title="Lợi ích của Service Discovery" >}}
- **Dynamic Discovery:** Services tự động register/deregister
- **DNS-based:** Sử dụng DNS names thay vì IP addresses
- **Health Checking:** Automatic health monitoring
- **Load Distribution:** Automatic load balancing across healthy instances
{{< /alert >}}

## Bước 1: Load Environment

```bash
# Load workshop environment
cd ~/ecs-workshop
source workshop-env.sh

# Verify required variables
for var in VPC_ID CLUSTER_NAME NAMESPACE_ID; do
    if [ -z "${!var}" ]; then
        echo "❌ $var not found. Please complete previous steps."
        exit 1
    fi
done

echo "✅ Environment loaded successfully"
```

## Bước 2: Kiểm tra Route53 Private Hosted Zone

### 2.1 Verify Private DNS Namespace

{{< console-screenshot src="images/route53-hosted-zones.png" alt="Route53 Hosted Zones" caption="Route53 console hiển thị private hosted zones được tạo bởi Service Discovery" service="Route53 Console" >}}

```bash
echo "🔍 Checking Service Discovery namespace..."

# List namespaces
aws servicediscovery list-namespaces \
    --query 'Namespaces[].{Name:Name,Id:Id,Type:Type,Description:Description}'

# Get namespace details
aws servicediscovery get-namespace \
    --id $NAMESPACE_ID \
    --query '{Name:Namespace.Name,Id:Namespace.Id,HostedZoneId:Namespace.Properties.DnsProperties.HostedZoneId}'

# Get hosted zone ID for later use
HOSTED_ZONE_ID=$(aws servicediscovery get-namespace \
    --id $NAMESPACE_ID \
    --query 'Namespace.Properties.DnsProperties.HostedZoneId' \
    --output text)

echo "✅ Hosted Zone ID: $HOSTED_ZONE_ID"
echo "export HOSTED_ZONE_ID=$HOSTED_ZONE_ID" >> workshop-env.sh
```

### 2.2 Check DNS Records

{{< console-screenshot src="images/route53-dns-records.png" alt="Route53 DNS Records" caption="Route53 DNS records được tạo tự động bởi Service Discovery cho các ECS services" service="Route53 Console" >}}

```bash
echo "📋 Checking DNS records..."

# List DNS records in the hosted zone
aws route53 list-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --query 'ResourceRecordSets[].{Name:Name,Type:Type,TTL:TTL,Records:ResourceRecords[].Value}'
```

## Bước 3: Update ECS Services với Service Discovery

### 3.1 Update Frontend Service

```bash
echo "🔄 Updating Frontend Service với Service Discovery..."

# Update frontend service để enable service discovery
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service workshop-frontend \
    --service-registries registryArn=arn:aws:servicediscovery:$AWS_DEFAULT_REGION:$(aws sts get-caller-identity --query Account --output text):service/$FRONTEND_DISCOVERY_ID

echo "✅ Frontend service updated với service discovery"
```

### 3.2 Update API Service

```bash
echo "🔄 Updating API Service với Service Discovery..."

# Update API service
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service workshop-api \
    --service-registries registryArn=arn:aws:servicediscovery:$AWS_DEFAULT_REGION:$(aws sts get-caller-identity --query Account --output text):service/$API_DISCOVERY_ID

echo "✅ API service updated với service discovery"
```

### 3.3 Update Database Service

```bash
echo "🔄 Updating Database Service với Service Discovery..."

# Update database service
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service workshop-database \
    --service-registries registryArn=arn:aws:servicediscovery:$AWS_DEFAULT_REGION:$(aws sts get-caller-identity --query Account --output text):service/$DATABASE_DISCOVERY_ID

echo "✅ Database service updated với service discovery"
```

## Bước 4: Verify Service Registration

### 4.1 Check Service Discovery Instances

```bash
echo "🔍 Checking service discovery instances..."

# Check registered instances for each service
for service_name in frontend api database; do
    service_id_var="${service_name^^}_DISCOVERY_ID"
    service_id=${!service_id_var}
    
    echo "=== $service_name instances ==="
    aws servicediscovery list-instances \
        --service-id $service_id \
        --query 'Instances[].{Id:Id,IPv4:Attributes.AWS_INSTANCE_IPV4,Port:Attributes.AWS_INSTANCE_PORT,HealthStatus:HealthStatus}'
done
```

### 4.2 Wait for Registration

```bash
echo "⏳ Waiting for service registration to complete..."

# Wait a bit for registration
sleep 30

# Check registration status
for service_name in frontend api database; do
    service_id_var="${service_name^^}_DISCOVERY_ID"
    service_id=${!service_id_var}
    
    instance_count=$(aws servicediscovery list-instances \
        --service-id $service_id \
        --query 'length(Instances)')
    
    echo "✅ $service_name: $instance_count instances registered"
done
```

## Bước 5: Test DNS Resolution

### 5.1 Create Test Task

```bash
echo "🧪 Creating test task để test DNS resolution..."

# Create test task definition
cat > test-task-definition.json << EOF
{
    "family": "workshop-test",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole",
    "containerDefinitions": [
        {
            "name": "test",
            "image": "alpine:latest",
            "command": ["sleep", "3600"],
            "essential": true,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/workshop-test",
                    "awslogs-region": "$AWS_DEFAULT_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ]
}
EOF

# Create log group
aws logs create-log-group \
    --log-group-name "/ecs/workshop-test" \
    --tags Environment=workshop,Project=ecs-networking

# Register task definition
TEST_TASK_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://test-task-definition.json \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "✅ Test Task Definition: $TEST_TASK_ARN"
```

### 5.2 Run Test Task

```bash
echo "🚀 Running test task..."

# Run test task
TEST_TASK=$(aws ecs run-task \
    --cluster $CLUSTER_NAME \
    --task-definition workshop-test \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --query 'tasks[0].taskArn' \
    --output text)

echo "✅ Test task started: $TEST_TASK"

# Wait for task to be running
echo "⏳ Waiting for test task to be running..."
aws ecs wait tasks-running --cluster $CLUSTER_NAME --tasks $TEST_TASK
echo "✅ Test task is running"
```

### 5.3 Test DNS Resolution

```bash
echo "🔍 Testing DNS resolution..."

# Execute commands in test task để test DNS
for service in frontend api database; do
    echo "=== Testing $service.workshop.local ==="
    
    # Test nslookup
    aws ecs execute-command \
        --cluster $CLUSTER_NAME \
        --task $TEST_TASK \
        --container test \
        --interactive \
        --command "nslookup $service.workshop.local" || echo "nslookup failed for $service"
    
    # Test ping (if available)
    aws ecs execute-command \
        --cluster $CLUSTER_NAME \
        --task $TEST_TASK \
        --container test \
        --interactive \
        --command "ping -c 3 $service.workshop.local" || echo "ping failed for $service"
done
```

## Bước 6: Advanced Service Discovery Features

### 6.1 Health Checks Configuration

```bash
echo "🏥 Configuring health checks..."

# Update service discovery services với custom health checks
for service_name in frontend api database; do
    service_id_var="${service_name^^}_DISCOVERY_ID"
    service_id=${!service_id_var}
    
    # Update health check configuration
    aws servicediscovery update-service \
        --id $service_id \
        --service DnsConfig='{NamespaceId='$NAMESPACE_ID',DnsRecords=[{Type=A,TTL=60}]}',HealthCheckCustomConfig='{FailureThreshold=2}'
    
    echo "✅ Health check updated for $service_name"
done
```

### 6.2 Service Discovery Metrics

```bash
echo "📊 Checking Service Discovery metrics..."

# Get service discovery metrics từ CloudWatch
aws cloudwatch get-metric-statistics \
    --namespace AWS/Cloud9 \
    --metric-name InstanceCount \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average \
    --query 'Datapoints[].{Time:Timestamp,Value:Average}'
```

## Bước 7: Service-to-Service Communication

### 7.1 Update Task Definitions với Service Discovery

```bash
echo "🔄 Updating task definitions để sử dụng service discovery..."

# Update frontend task definition để connect tới API
cat > frontend-updated-task-definition.json << EOF
{
    "family": "workshop-frontend",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole",
    "containerDefinitions": [
        {
            "name": "frontend",
            "image": "nginx:alpine",
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
                    "awslogs-group": "/ecs/workshop-frontend",
                    "awslogs-region": "$AWS_DEFAULT_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "environment": [
                {
                    "name": "SERVICE_NAME",
                    "value": "frontend"
                },
                {
                    "name": "API_ENDPOINT",
                    "value": "http://api.workshop.local"
                },
                {
                    "name": "DATABASE_ENDPOINT",
                    "value": "database.workshop.local:6379"
                }
            ]
        }
    ]
}
EOF

# Register updated task definition
FRONTEND_UPDATED_TASK_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://frontend-updated-task-definition.json \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "✅ Updated Frontend Task Definition: $FRONTEND_UPDATED_TASK_ARN"
```

### 7.2 Update API Task Definition

```bash
# Update API task definition
cat > api-updated-task-definition.json << EOF
{
    "family": "workshop-api",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole",
    "containerDefinitions": [
        {
            "name": "api",
            "image": "httpd:alpine",
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
                    "awslogs-group": "/ecs/workshop-api",
                    "awslogs-region": "$AWS_DEFAULT_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "environment": [
                {
                    "name": "SERVICE_NAME",
                    "value": "api"
                },
                {
                    "name": "DATABASE_ENDPOINT",
                    "value": "database.workshop.local:6379"
                }
            ]
        }
    ]
}
EOF

# Register updated task definition
API_UPDATED_TASK_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://api-updated-task-definition.json \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "✅ Updated API Task Definition: $API_UPDATED_TASK_ARN"
```

### 7.3 Update Services với New Task Definitions

```bash
echo "🔄 Updating services với new task definitions..."

# Update frontend service
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service workshop-frontend \
    --task-definition workshop-frontend

# Update API service
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service workshop-api \
    --task-definition workshop-api

echo "✅ Services updated với service discovery endpoints"
```

## Bước 8: Monitoring Service Discovery

### 8.1 CloudWatch Logs Analysis

```bash
echo "📊 Analyzing service discovery logs..."

# Check logs for DNS resolution
aws logs filter-log-events \
    --log-group-name "/ecs/workshop-frontend" \
    --start-time $(date -d '10 minutes ago' +%s)000 \
    --filter-pattern "api.workshop.local" \
    --query 'events[].message'
```

### 8.2 Service Discovery Dashboard

```bash
echo "📈 Creating CloudWatch dashboard cho service discovery..."

# Create dashboard
cat > service-discovery-dashboard.json << EOF
{
    "widgets": [
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["AWS/ServiceDiscovery", "InstanceCount", "ServiceName", "frontend"],
                    [".", ".", ".", "api"],
                    [".", ".", ".", "database"]
                ],
                "period": 300,
                "stat": "Average",
                "region": "$AWS_DEFAULT_REGION",
                "title": "Service Discovery Instance Count"
            }
        }
    ]
}
EOF

aws cloudwatch put-dashboard \
    --dashboard-name "ECS-Workshop-ServiceDiscovery" \
    --dashboard-body file://service-discovery-dashboard.json

echo "✅ Service Discovery dashboard created"
```

## Bước 9: Cleanup Test Resources

```bash
echo "🧹 Cleaning up test resources..."

# Stop test task
aws ecs stop-task \
    --cluster $CLUSTER_NAME \
    --task $TEST_TASK \
    --reason "Test completed"

# Delete test log group
aws logs delete-log-group \
    --log-group-name "/ecs/workshop-test"

echo "✅ Test resources cleaned up"
```

## Troubleshooting

### Common Issues

**1. DNS resolution không hoạt động:**
```bash
# Check namespace và hosted zone
aws servicediscovery get-namespace --id $NAMESPACE_ID
aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID
```

**2. Services không register:**
```bash
# Check service discovery service
aws servicediscovery get-service --id $FRONTEND_DISCOVERY_ID

# Check ECS service configuration
aws ecs describe-services --cluster $CLUSTER_NAME --services workshop-frontend
```

**3. Health checks failing:**
```bash
# Check instance health
aws servicediscovery list-instances --service-id $FRONTEND_DISCOVERY_ID

# Check task health
aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name workshop-frontend --query 'taskArns[0]' --output text)
```

**4. Network connectivity issues:**
```bash
# Check security groups
aws ec2 describe-security-groups --group-ids $ECS_SG

# Check VPC DNS settings
aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsHostnames
aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsSupport
```

## Tóm tắt

Bạn đã thành công triển khai Service Discovery với:

- ✅ **Private DNS Namespace** (workshop.local)
- ✅ **Service Discovery Services** cho tất cả ECS services
- ✅ **Automatic Registration** của ECS tasks
- ✅ **DNS-based Communication** giữa services
- ✅ **Health Checking** và monitoring
- ✅ **CloudWatch Integration** cho metrics

**Service Discovery Architecture:**
```
Route53 Private Hosted Zone (workshop.local)
├── frontend.workshop.local → Frontend ECS Tasks
├── api.workshop.local → API ECS Tasks
└── database.workshop.local → Database ECS Tasks

DNS Resolution Flow:
Task → VPC DNS → Route53 → Service Discovery → Healthy Task IPs
```

## Bước tiếp theo

Service Discovery đã hoạt động! Tiếp theo chúng ta sẽ [cấu hình Load Balancing](../5-load-balancing/) để expose services ra internet và distribute traffic.

---

{{< alert type="tip" title="Pro Tip" >}}
Sử dụng `nslookup service.workshop.local` từ bên trong tasks để test DNS resolution!
{{< /alert >}}

---
title : "Xây dựng VPC và ECS Cluster"
date : "`r Sys.Date()`"
weight : 3
chapter : false
pre : " <b> 3. </b> "
---

## Tổng quan

Trong phần này, chúng ta sẽ tạo ECS Cluster và deploy các containerized applications. Cluster sẽ chạy trên VPC đã tạo ở phần trước.

{{< alert type="info" title="Điều kiện tiên quyết" >}}
Đảm bảo bạn đã hoàn thành [Thiết lập VPC](../1-introduction/) và có file `workshop-env.sh` với tất cả environment variables.
{{< /alert >}}

## Bước 1: Load Environment

```bash
# Load workshop environment
cd ~/ecs-workshop
source workshop-env.sh

# Verify VPC exists
if [ -z "$VPC_ID" ]; then
    echo "❌ VPC_ID not found. Please complete VPC setup first."
    exit 1
fi

echo "✅ Using VPC: $VPC_ID"
```

## Bước 2: Tạo ECS Cluster

### 2.1 Tạo ECS Cluster với Fargate

{{< console-screenshot src="images/ecs-console-clusters.png" alt="ECS Console Clusters" caption="ECS Console hiển thị danh sách clusters và tình trạng hoạt động" service="ECS Console" >}}

```bash
echo "🐳 Tạo ECS Cluster..."

# Tạo ECS Cluster
CLUSTER_NAME="ecs-workshop-cluster"
aws ecs create-cluster \
    --cluster-name $CLUSTER_NAME \
    --capacity-providers FARGATE \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
    --tags key=Environment,value=workshop key=Project,value=ecs-networking

echo "✅ ECS Cluster created: $CLUSTER_NAME"
echo "export CLUSTER_NAME=$CLUSTER_NAME" >> workshop-env.sh
```

### 2.2 Verify Cluster Creation

```bash
# Kiểm tra cluster status
aws ecs describe-clusters --clusters $CLUSTER_NAME --query 'clusters[0].{Name:clusterName,Status:status,ActiveServices:activeServicesCount,RunningTasks:runningTasksCount}'

# Wait for cluster to be active
echo "⏳ Waiting for cluster to be active..."
aws ecs wait clusters-active --clusters $CLUSTER_NAME
echo "✅ Cluster is active"
```

### 2.3 Xem Cluster Details trong Console

{{< console-screenshot src="images/ecs-cluster-details.png" alt="ECS Cluster Details" caption="Chi tiết ECS cluster với thông tin về capacity providers, services và tasks" service="ECS Console" >}}

## Bước 3: Tạo Task Definitions

### 3.1 Frontend Service Task Definition

```bash
echo "📝 Tạo Task Definition cho Frontend Service..."

# Tạo task definition cho frontend
cat > frontend-task-definition.json << EOF
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
                }
            ]
        }
    ]
}
EOF

# Register task definition
FRONTEND_TASK_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://frontend-task-definition.json \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "✅ Frontend Task Definition: $FRONTEND_TASK_ARN"
echo "export FRONTEND_TASK_ARN=$FRONTEND_TASK_ARN" >> workshop-env.sh
```

### 3.2 API Service Task Definition

```bash
echo "📝 Tạo Task Definition cho API Service..."

# Tạo task definition cho API
cat > api-task-definition.json << EOF
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
                }
            ]
        }
    ]
}
EOF

# Register task definition
API_TASK_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://api-task-definition.json \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "✅ API Task Definition: $API_TASK_ARN"
echo "export API_TASK_ARN=$API_TASK_ARN" >> workshop-env.sh
```

### 3.3 Database Service Task Definition

```bash
echo "📝 Tạo Task Definition cho Database Service..."

# Tạo task definition cho database
cat > database-task-definition.json << EOF
{
    "family": "workshop-database",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole",
    "containerDefinitions": [
        {
            "name": "database",
            "image": "redis:alpine",
            "portMappings": [
                {
                    "containerPort": 6379,
                    "protocol": "tcp"
                }
            ],
            "essential": true,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/workshop-database",
                    "awslogs-region": "$AWS_DEFAULT_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "environment": [
                {
                    "name": "SERVICE_NAME",
                    "value": "database"
                }
            ]
        }
    ]
}
EOF

# Register task definition
DATABASE_TASK_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://database-task-definition.json \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "✅ Database Task Definition: $DATABASE_TASK_ARN"
echo "export DATABASE_TASK_ARN=$DATABASE_TASK_ARN" >> workshop-env.sh
```

### 3.4 Xem Task Definitions trong Console

{{< console-screenshot src="images/ecs-task-definitions.png" alt="ECS Task Definitions" caption="ECS Task Definitions console hiển thị các task definitions đã tạo với cấu hình chi tiết" service="ECS Console" >}}

## Bước 4: Tạo CloudWatch Log Groups

```bash
echo "📊 Tạo CloudWatch Log Groups..."

# Tạo log groups cho các services
for service in frontend api database; do
    aws logs create-log-group \
        --log-group-name "/ecs/workshop-$service" \
        --tags Environment=workshop,Project=ecs-networking
    
    # Set retention policy
    aws logs put-retention-policy \
        --log-group-name "/ecs/workshop-$service" \
        --retention-in-days 7
    
    echo "✅ Log group created: /ecs/workshop-$service"
done
```

## Bước 5: Deploy Services

### 5.1 Deploy Frontend Service

```bash
echo "🚀 Deploy Frontend Service..."

# Deploy frontend service
FRONTEND_SERVICE=$(aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name workshop-frontend \
    --task-definition workshop-frontend \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --tags key=Environment,value=workshop key=Service,value=frontend \
    --query 'service.serviceName' \
    --output text)

echo "✅ Frontend Service deployed: $FRONTEND_SERVICE"
echo "export FRONTEND_SERVICE=$FRONTEND_SERVICE" >> workshop-env.sh
```

### 5.2 Deploy API Service

```bash
echo "🚀 Deploy API Service..."

# Deploy API service
API_SERVICE=$(aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name workshop-api \
    --task-definition workshop-api \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --tags key=Environment,value=workshop key=Service,value=api \
    --query 'service.serviceName' \
    --output text)

echo "✅ API Service deployed: $API_SERVICE"
echo "export API_SERVICE=$API_SERVICE" >> workshop-env.sh
```

### 5.3 Deploy Database Service

```bash
echo "🚀 Deploy Database Service..."

# Deploy database service
DATABASE_SERVICE=$(aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name workshop-database \
    --task-definition workshop-database \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --tags key=Environment,value=workshop key=Service,value=database \
    --query 'service.serviceName' \
    --output text)

echo "✅ Database Service deployed: $DATABASE_SERVICE"
echo "export DATABASE_SERVICE=$DATABASE_SERVICE" >> workshop-env.sh
```

## Bước 6: Verify Deployments

### 6.1 Check Service Status

```bash
echo "🔍 Checking service status..."

# Check all services
aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services workshop-frontend workshop-api workshop-database \
    --query 'services[].{Name:serviceName,Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}'
```

### 6.2 Wait for Services to be Stable

```bash
echo "⏳ Waiting for services to be stable..."

# Wait for services to be stable
aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services workshop-frontend workshop-api workshop-database

echo "✅ All services are stable"
```

### 6.3 Check Running Tasks

```bash
echo "📋 Listing running tasks..."

# List running tasks
aws ecs list-tasks \
    --cluster $CLUSTER_NAME \
    --query 'taskArns[]' \
    --output table

# Get task details
TASK_ARNS=$(aws ecs list-tasks --cluster $CLUSTER_NAME --query 'taskArns' --output text)
if [ ! -z "$TASK_ARNS" ]; then
    aws ecs describe-tasks \
        --cluster $CLUSTER_NAME \
        --tasks $TASK_ARNS \
        --query 'tasks[].{TaskArn:taskArn,LastStatus:lastStatus,HealthStatus:healthStatus,CreatedAt:createdAt}'
fi
```

## Bước 7: Monitoring và Logs

### 7.1 Check CloudWatch Logs

{{< console-screenshot src="images/cloudwatch-logs.png" alt="CloudWatch Logs" caption="CloudWatch Logs console hiển thị log streams từ các ECS containers" service="CloudWatch Console" >}}

```bash
echo "📊 Checking CloudWatch logs..."

# List log streams
for service in frontend api database; do
    echo "=== $service logs ==="
    aws logs describe-log-streams \
        --log-group-name "/ecs/workshop-$service" \
        --order-by LastEventTime \
        --descending \
        --max-items 3 \
        --query 'logStreams[].{Stream:logStreamName,LastEvent:lastEventTime}'
done
```

### 7.2 View Recent Logs

```bash
# View recent logs from frontend service
echo "📝 Recent frontend logs:"
aws logs tail "/ecs/workshop-frontend" --since 10m --follow &
TAIL_PID=$!

# Let it run for a few seconds then stop
sleep 5
kill $TAIL_PID 2>/dev/null
```

## Bước 8: Service Discovery Setup

### 8.1 Tạo Service Discovery Namespace

```bash
echo "🔍 Setting up Service Discovery..."

# Tạo private DNS namespace
NAMESPACE_ID=$(aws servicediscovery create-private-dns-namespace \
    --name "workshop.local" \
    --vpc $VPC_ID \
    --description "Private namespace for ECS workshop" \
    --query 'OperationId' \
    --output text)

# Wait for namespace creation
echo "⏳ Waiting for namespace creation..."
aws servicediscovery get-operation --operation-id $NAMESPACE_ID

# Get namespace ID
NAMESPACE_ID=$(aws servicediscovery list-namespaces \
    --filters Name=TYPE,Values=DNS_PRIVATE \
    --query 'Namespaces[?Name==`workshop.local`].Id' \
    --output text)

echo "✅ Service Discovery Namespace: $NAMESPACE_ID"
echo "export NAMESPACE_ID=$NAMESPACE_ID" >> workshop-env.sh
```

### 8.2 Tạo Service Discovery Services

```bash
echo "🔍 Creating Service Discovery services..."

# Tạo service discovery cho từng service
for service_name in frontend api database; do
    SERVICE_ID=$(aws servicediscovery create-service \
        --name $service_name \
        --dns-config NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=60}] \
        --health-check-custom-config FailureThreshold=1 \
        --description "Service discovery for $service_name" \
        --query 'Service.Id' \
        --output text)
    
    echo "✅ Service Discovery created for $service_name: $SERVICE_ID"
    echo "export ${service_name^^}_DISCOVERY_ID=$SERVICE_ID" >> workshop-env.sh
done
```

## Bước 9: Test Connectivity

### 9.1 Test Internal Connectivity

```bash
echo "🧪 Testing internal connectivity..."

# Get task IPs
FRONTEND_TASK=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name workshop-frontend --query 'taskArns[0]' --output text)
if [ "$FRONTEND_TASK" != "None" ]; then
    FRONTEND_IP=$(aws ecs describe-tasks \
        --cluster $CLUSTER_NAME \
        --tasks $FRONTEND_TASK \
        --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value' \
        --output text)
    
    echo "✅ Frontend Task IP: $FRONTEND_IP"
fi

# Test từ một task khác (nếu có)
API_TASK=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name workshop-api --query 'taskArns[0]' --output text)
if [ "$API_TASK" != "None" ]; then
    API_IP=$(aws ecs describe-tasks \
        --cluster $CLUSTER_NAME \
        --tasks $API_TASK \
        --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value' \
        --output text)
    
    echo "✅ API Task IP: $API_IP"
fi
```

### 9.2 Verify Security Groups

{{< console-screenshot src="images/security-groups-console.png" alt="Security Groups Console" caption="Security Groups console hiển thị rules cho ECS services và ALB" service="EC2 Console" >}}

```bash
echo "🔒 Verifying security group rules..."

# Check ECS security group rules
aws ec2 describe-security-groups \
    --group-ids $ECS_SG \
    --query 'SecurityGroups[0].{GroupId:GroupId,InboundRules:IpPermissions[].{Protocol:IpProtocol,Port:FromPort,Source:UserIdGroupPairs[0].GroupId}}'
```

## Troubleshooting

### Common Issues

**1. Task fails to start:**
```bash
# Check task definition
aws ecs describe-task-definition --task-definition workshop-frontend

# Check service events
aws ecs describe-services --cluster $CLUSTER_NAME --services workshop-frontend --query 'services[0].events[0:5]'
```

**2. Tasks stuck in PENDING:**
```bash
# Check subnet và security group
aws ec2 describe-subnets --subnet-ids $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2
aws ec2 describe-security-groups --group-ids $ECS_SG
```

**3. No logs appearing:**
```bash
# Check log group exists
aws logs describe-log-groups --log-group-name-prefix "/ecs/workshop"

# Check task execution role
aws iam get-role --role-name ecsTaskExecutionRole
```

**4. Service discovery not working:**
```bash
# Check namespace
aws servicediscovery list-namespaces

# Check services
aws servicediscovery list-services --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID
```

## Tóm tắt

Bạn đã thành công tạo và deploy:

- ✅ **ECS Cluster** với Fargate capacity provider
- ✅ **3 Task Definitions** (frontend, api, database)
- ✅ **3 ECS Services** running trong private subnets
- ✅ **CloudWatch Log Groups** cho monitoring
- ✅ **Service Discovery** namespace và services
- ✅ **Security Groups** configured properly

**Current Architecture:**
```
ECS Cluster (workshop-cluster)
├── Frontend Service (2 tasks) → nginx:alpine
├── API Service (2 tasks) → httpd:alpine
└── Database Service (1 task) → redis:alpine

All running in Private Subnets với Service Discovery
```

## Bước tiếp theo

ECS Cluster đã sẵn sàng! Tiếp theo chúng ta sẽ [triển khai Service Discovery](../4-service-discovery/) để các services có thể tìm thấy nhau qua DNS.

---

{{< alert type="tip" title="Pro Tip" >}}
Sử dụng `aws ecs describe-services` để monitor service health và `aws logs tail` để xem real-time logs!
{{< /alert >}}

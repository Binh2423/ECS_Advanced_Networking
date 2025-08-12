---
title : "Ví dụ: Service Discovery Thực tế"
date : "`r Sys.Date()`"
weight : 41
chapter : false
pre : " <b> 4.1 </b> "
---

# Ví dụ: Service Discovery Thực tế

## Tình huống thực tế

Giả sử chúng ta có một ứng dụng e-commerce với 3 services:
- **Frontend**: Web UI (React app)
- **Backend API**: REST API (Node.js)
- **Database**: Redis cache

Chúng ta sẽ thiết lập service discovery để các services có thể tìm và giao tiếp với nhau.

## Bước 1: Tạo Private DNS Namespace

### Tại sao cần Private DNS Namespace?

- **Internal Communication**: Services chỉ giao tiếp nội bộ
- **Security**: Không expose ra internet
- **Automatic DNS**: AWS quản lý DNS records

### Command và Giải thích:

```bash
# Tạo private DNS namespace
NAMESPACE_ID=$(aws servicediscovery create-private-dns-namespace \
    --name ecommerce.local \
    --vpc $VPC_ID \
    --description "Private DNS namespace for e-commerce application" \
    --query 'OperationId' \
    --output text)

echo "Namespace creation operation: $NAMESPACE_ID"
```

### Giải thích tham số:
- **`--name ecommerce.local`**: Domain name cho internal services
- **`--vpc $VPC_ID`**: Chỉ hoạt động trong VPC này
- **`--description`**: Mô tả để dễ quản lý

### Monitor Namespace Creation:

```bash
# Kiểm tra operation status
aws servicediscovery get-operation --operation-id $NAMESPACE_ID

# Output mẫu:
{
    "Operation": {
        "Id": "op-123456789",
        "Type": "CREATE_NAMESPACE",
        "Status": "SUCCESS",
        "CreateDate": "2024-01-15T10:30:00Z",
        "UpdateDate": "2024-01-15T10:31:00Z"
    }
}
```

### Lấy Namespace ID:

```bash
# Lấy namespace ID sau khi tạo xong
NAMESPACE_ID=$(aws servicediscovery list-namespaces \
    --filters Name=TYPE,Values=DNS_PRIVATE \
    --query 'Namespaces[?Name==`ecommerce.local`].Id' \
    --output text)

echo "Namespace ID: $NAMESPACE_ID"
```

## Bước 2: Tạo Service Registry cho từng Service

### Frontend Service Registry

```bash
# Tạo service registry cho frontend
FRONTEND_SERVICE_ID=$(aws servicediscovery create-service \
    --name frontend \
    --namespace-id $NAMESPACE_ID \
    --dns-config NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=60}] \
    --health-check-custom-config FailureThreshold=1 \
    --description "Frontend web application service" \
    --query 'Service.Id' \
    --output text)

echo "Frontend Service ID: $FRONTEND_SERVICE_ID"
```

### Backend API Service Registry

```bash
# Tạo service registry cho backend API
BACKEND_SERVICE_ID=$(aws servicediscovery create-service \
    --name api \
    --namespace-id $NAMESPACE_ID \
    --dns-config NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=60}] \
    --health-check-custom-config FailureThreshold=1 \
    --description "Backend API service" \
    --query 'Service.Id' \
    --output text)

echo "Backend Service ID: $BACKEND_SERVICE_ID"
```

### Redis Service Registry

```bash
# Tạo service registry cho Redis
REDIS_SERVICE_ID=$(aws servicediscovery create-service \
    --name redis \
    --namespace-id $NAMESPACE_ID \
    --dns-config NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=60}] \
    --health-check-custom-config FailureThreshold=1 \
    --description "Redis cache service" \
    --query 'Service.Id' \
    --output text)

echo "Redis Service ID: $REDIS_SERVICE_ID"
```

### Xác minh Service Registry:

```bash
# List tất cả services trong namespace
aws servicediscovery list-services \
    --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID \
    --query 'Services[].{Name:Name,Id:Id,Description:Description}'

# Output mẫu:
[
    {
        "Name": "frontend",
        "Id": "srv-123456789",
        "Description": "Frontend web application service"
    },
    {
        "Name": "api", 
        "Id": "srv-987654321",
        "Description": "Backend API service"
    },
    {
        "Name": "redis",
        "Id": "srv-456789123", 
        "Description": "Redis cache service"
    }
]
```

## Bước 3: Tạo Task Definitions với Service Discovery

### Frontend Task Definition

```bash
# Tạo task definition cho frontend
cat > frontend-task-definition.json << EOF
{
    "family": "ecommerce-frontend",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ecsTaskExecutionRole",
    "taskRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ecsTaskRole",
    "containerDefinitions": [
        {
            "name": "frontend",
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
                    "awslogs-group": "/ecs/ecommerce-frontend",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "environment": [
                {
                    "name": "API_ENDPOINT",
                    "value": "http://api.ecommerce.local"
                },
                {
                    "name": "REDIS_ENDPOINT", 
                    "value": "redis.ecommerce.local"
                }
            ]
        }
    ]
}
EOF

# Register task definition
aws ecs register-task-definition --cli-input-json file://frontend-task-definition.json
```

### Backend API Task Definition

```bash
# Tạo task definition cho backend API
cat > backend-task-definition.json << EOF
{
    "family": "ecommerce-backend",
    "networkMode": "awsvpc", 
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "512",
    "memory": "1024",
    "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ecsTaskExecutionRole",
    "taskRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ecsTaskRole",
    "containerDefinitions": [
        {
            "name": "api",
            "image": "node:16-alpine",
            "command": ["node", "server.js"],
            "portMappings": [
                {
                    "containerPort": 3000,
                    "protocol": "tcp"
                }
            ],
            "essential": true,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/ecommerce-backend",
                    "awslogs-region": "$AWS_REGION", 
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "environment": [
                {
                    "name": "REDIS_URL",
                    "value": "redis://redis.ecommerce.local:6379"
                },
                {
                    "name": "NODE_ENV",
                    "value": "production"
                }
            ]
        }
    ]
}
EOF

# Register task definition
aws ecs register-task-definition --cli-input-json file://backend-task-definition.json
```

### Redis Task Definition

```bash
# Tạo task definition cho Redis
cat > redis-task-definition.json << EOF
{
    "family": "ecommerce-redis",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"], 
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ecsTaskExecutionRole",
    "taskRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ecsTaskRole",
    "containerDefinitions": [
        {
            "name": "redis",
            "image": "redis:7-alpine",
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
                    "awslogs-group": "/ecs/ecommerce-redis",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "command": [
                "redis-server",
                "--appendonly", "yes",
                "--maxmemory", "256mb",
                "--maxmemory-policy", "allkeys-lru"
            ]
        }
    ]
}
EOF

# Register task definition
aws ecs register-task-definition --cli-input-json file://redis-task-definition.json
```

## Bước 4: Tạo ECS Services với Service Discovery

### Tạo Redis Service (Database tier)

```bash
# Tạo Redis service trước (dependencies)
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name ecommerce-redis \
    --task-definition ecommerce-redis \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={
        subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],
        securityGroups=[$ECS_SG],
        assignPublicIp=DISABLED
    }" \
    --service-registries "registryArn=arn:aws:servicediscovery:$AWS_REGION:$ACCOUNT_ID:service/$REDIS_SERVICE_ID"

echo "✅ Redis service đã được tạo"
```

### Tạo Backend API Service

```bash
# Tạo backend API service
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name ecommerce-backend \
    --task-definition ecommerce-backend \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={
        subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],
        securityGroups=[$ECS_SG],
        assignPublicIp=DISABLED
    }" \
    --service-registries "registryArn=arn:aws:servicediscovery:$AWS_REGION:$ACCOUNT_ID:service/$BACKEND_SERVICE_ID"

echo "✅ Backend API service đã được tạo"
```

### Tạo Frontend Service

```bash
# Tạo frontend service
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name ecommerce-frontend \
    --task-definition ecommerce-frontend \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={
        subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],
        securityGroups=[$ECS_SG],
        assignPublicIp=DISABLED
    }" \
    --service-registries "registryArn=arn:aws:servicediscovery:$AWS_REGION:$ACCOUNT_ID:service/$FRONTEND_SERVICE_ID"

echo "✅ Frontend service đã được tạo"
```

## Bước 5: Test Service Discovery

### Kiểm tra Service Registration

```bash
# Kiểm tra instances đã được register
echo "=== Frontend Instances ==="
aws servicediscovery list-instances --service-id $FRONTEND_SERVICE_ID

echo "=== Backend API Instances ==="
aws servicediscovery list-instances --service-id $BACKEND_SERVICE_ID

echo "=== Redis Instances ==="
aws servicediscovery list-instances --service-id $REDIS_SERVICE_ID
```

### Output mẫu:

```json
{
    "Instances": [
        {
            "Id": "frontend-task-1",
            "Attributes": {
                "AWS_INSTANCE_IPV4": "10.0.3.100",
                "AWS_INSTANCE_PORT": "80"
            }
        },
        {
            "Id": "frontend-task-2", 
            "Attributes": {
                "AWS_INSTANCE_IPV4": "10.0.4.150",
                "AWS_INSTANCE_PORT": "80"
            }
        }
    ]
}
```

### Test DNS Resolution

```bash
# Tạo test task để test DNS resolution
cat > dns-test-task.json << EOF
{
    "family": "dns-test",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256", 
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ecsTaskExecutionRole",
    "containerDefinitions": [
        {
            "name": "dns-test",
            "image": "alpine:latest",
            "command": ["sleep", "3600"],
            "essential": true,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/dns-test",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ]
}
EOF

# Register và run test task
aws ecs register-task-definition --cli-input-json file://dns-test-task.json

TEST_TASK_ARN=$(aws ecs run-task \
    --cluster $CLUSTER_NAME \
    --task-definition dns-test \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={
        subnets=[$PRIVATE_SUBNET_1],
        securityGroups=[$ECS_SG],
        assignPublicIp=DISABLED
    }" \
    --query 'tasks[0].taskArn' \
    --output text)

echo "Test task ARN: $TEST_TASK_ARN"
```

### Execute DNS Tests

```bash
# Chờ task running
aws ecs wait tasks-running --cluster $CLUSTER_NAME --tasks $TEST_TASK_ARN

# Test DNS resolution (cần ECS Exec enabled)
# Trong thực tế, bạn sẽ exec vào container và chạy:
# nslookup frontend.ecommerce.local
# nslookup api.ecommerce.local  
# nslookup redis.ecommerce.local

# Kết quả mong đợi:
# frontend.ecommerce.local -> 10.0.3.100, 10.0.4.150
# api.ecommerce.local -> 10.0.3.200, 10.0.4.250
# redis.ecommerce.local -> 10.0.3.50
```

## Bước 6: Monitor Service Health

### Health Check Status

```bash
# Kiểm tra health status của tất cả services
echo "=== Frontend Health ==="
aws servicediscovery get-instances-health-status --service-id $FRONTEND_SERVICE_ID

echo "=== Backend API Health ==="
aws servicediscovery get-instances-health-status --service-id $BACKEND_SERVICE_ID

echo "=== Redis Health ==="
aws servicediscovery get-instances-health-status --service-id $REDIS_SERVICE_ID
```

### Output mẫu:

```json
{
    "Status": {
        "frontend-task-1": "SUCCESS",
        "frontend-task-2": "SUCCESS"
    }
}
```

### ECS Service Status

```bash
# Kiểm tra ECS service status
aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services ecommerce-frontend ecommerce-backend ecommerce-redis \
    --query 'services[].{
        Name:serviceName,
        Status:status,
        Running:runningCount,
        Desired:desiredCount,
        Pending:pendingCount
    }'
```

## Bước 7: Application Communication Flow

### Communication Pattern

```
┌─────────────────┐    HTTP/80     ┌─────────────────┐
│    Frontend     │──────────────→ │   Backend API   │
│ frontend.       │                │ api.ecommerce.  │
│ ecommerce.local │                │ local:3000      │
└─────────────────┘                └─────────────────┘
                                            │
                                            │ Redis/6379
                                            ▼
                                   ┌─────────────────┐
                                   │     Redis       │
                                   │ redis.ecommerce.│
                                   │ local:6379      │
                                   └─────────────────┘
```

### Example Application Code

**Frontend (nginx.conf):**
```nginx
upstream api_backend {
    server api.ecommerce.local:3000;
}

server {
    listen 80;
    
    location /api/ {
        proxy_pass http://api_backend/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
```

**Backend API (Node.js):**
```javascript
const express = require('express');
const redis = require('redis');

const app = express();
const client = redis.createClient({
    url: 'redis://redis.ecommerce.local:6379'
});

app.get('/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date() });
});

app.get('/api/products', async (req, res) => {
    try {
        const cached = await client.get('products');
        if (cached) {
            return res.json(JSON.parse(cached));
        }
        
        // Fetch from database
        const products = await fetchProducts();
        await client.setex('products', 300, JSON.stringify(products));
        
        res.json(products);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.listen(3000, () => {
    console.log('API server running on port 3000');
});
```

## Troubleshooting Common Issues

### Issue 1: Service Not Registering

**Symptoms**: Service instances không xuất hiện trong service discovery

**Debug Steps**:
```bash
# Kiểm tra ECS service status
aws ecs describe-services --cluster $CLUSTER_NAME --services ecommerce-frontend

# Kiểm tra task definition có service registry không
aws ecs describe-task-definition --task-definition ecommerce-frontend

# Kiểm tra service registry ARN
aws servicediscovery get-service --id $FRONTEND_SERVICE_ID
```

**Common Causes**:
- Service registry ARN sai
- Task không start được
- Network configuration issues

### Issue 2: DNS Resolution Failed

**Symptoms**: `nslookup` không resolve được service names

**Debug Steps**:
```bash
# Kiểm tra VPC DNS settings
aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsHostnames
aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsSupport

# Kiểm tra namespace
aws servicediscovery get-namespace --id $NAMESPACE_ID

# Kiểm tra instances trong cùng VPC
aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC_ID"
```

**Solutions**:
- Enable DNS resolution và hostnames trong VPC
- Đảm bảo tasks trong cùng VPC với namespace
- Kiểm tra security group rules

### Issue 3: Health Check Failures

**Symptoms**: Instances hiển thị unhealthy

**Debug Steps**:
```bash
# Kiểm tra health check config
aws servicediscovery get-service --id $FRONTEND_SERVICE_ID \
    --query 'Service.HealthCheckCustomConfig'

# Kiểm tra ECS task health
aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN
```

**Solutions**:
- Adjust failure threshold
- Kiểm tra application health endpoint
- Review container logs

## Best Practices

### 1. Service Naming Convention
```bash
# Consistent naming pattern
NAMESPACE="myapp.local"
SERVICE_NAMES=("frontend" "api" "cache" "worker")

# DNS names sẽ là:
# frontend.myapp.local
# api.myapp.local  
# cache.myapp.local
# worker.myapp.local
```

### 2. Health Check Configuration
```bash
# Reasonable failure threshold
--health-check-custom-config FailureThreshold=3

# TTL cho DNS records
DnsRecords=[{Type=A,TTL=60}]  # 60 seconds for dynamic environments
```

### 3. Security Groups
```bash
# Specific port access between services
# Frontend -> API: port 3000
# API -> Redis: port 6379
# ALB -> Frontend: port 80
```

## Summary

Trong ví dụ này, chúng ta đã:

1. ✅ Tạo private DNS namespace cho internal communication
2. ✅ Setup service registry cho 3 services (frontend, API, Redis)
3. ✅ Tạo task definitions với environment variables sử dụng DNS names
4. ✅ Deploy ECS services với service discovery integration
5. ✅ Test DNS resolution và service communication
6. ✅ Monitor service health và troubleshoot issues

**Kết quả**: Các services có thể giao tiếp với nhau qua DNS names thay vì hard-coded IPs, tự động scale và maintain service registry.

---
title : "Triển khai Service Discovery"
date : "`r Sys.Date()`"
weight : 4
chapter : false
pre : " <b> 4. </b> "
---

# Triển khai Service Discovery

Trong phần này, chúng ta sẽ triển khai service discovery sử dụng AWS Cloud Map, cho phép ECS services tìm và giao tiếp với nhau sử dụng DNS names thay vì hard-coded IP addresses.

## Service Discovery là gì?

Service discovery là cơ chế cho phép services tìm và giao tiếp với nhau mà không cần hard-code network locations. Trong môi trường container động như ECS, services có thể được tạo, hủy và di chuyển thường xuyên, làm cho service discovery trở nên thiết yếu cho reliable communication.

## Tổng quan AWS Cloud Map

AWS Cloud Map là cloud resource discovery service cung cấp:
- **DNS-based service discovery**
- **Health checking**
- **Automatic registration/deregistration**
- **Integration với ECS services**

## Kiến trúc

Chúng ta sẽ tạo service discovery setup sau:

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Cloud Map                            │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │            Private DNS Namespace                        ││
│  │              workshop.local                             ││
│  │                                                         ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      ││
│  │  │   web.      │  │   api.      │  │   db.       │      ││
│  │  │ workshop.   │  │ workshop.   │  │ workshop.   │      ││
│  │  │   local     │  │   local     │  │   local     │      ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘      ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Bước 1: Load Environment Variables

Đầu tiên, load environment variables từ phần trước:

```bash
# Load environment variables
source workshop-resources.env

# Xác minh variables được load
echo "VPC ID: $VPC_ID"
echo "Cluster Name: $CLUSTER_NAME"
```

## Bước 2: Tạo Cloud Map Namespace

### 2.1 Tạo Private DNS Namespace
```bash
# Tạo private DNS namespace
NAMESPACE_ID=$(aws servicediscovery create-private-dns-namespace \
    --name workshop.local \
    --vpc $VPC_ID \
    --description "Private DNS namespace for ECS workshop" \
    --query 'OperationId' \
    --output text)

echo "Namespace creation operation ID: $NAMESPACE_ID"

# Chờ namespace creation hoàn thành
echo "Đang chờ namespace creation hoàn thành..."
aws servicediscovery get-operation --operation-id $NAMESPACE_ID

# Lấy namespace ID khi đã tạo
NAMESPACE_ID=$(aws servicediscovery list-namespaces \
    --filters Name=TYPE,Values=DNS_PRIVATE \
    --query 'Namespaces[?Name==`workshop.local`].Id' \
    --output text)

echo "Namespace ID: $NAMESPACE_ID"
```

### 2.2 Xác minh Namespace Creation
```bash
# Describe namespace
aws servicediscovery get-namespace --id $NAMESPACE_ID
```

## Bước 3: Tạo Service Registry Services

### 3.1 Tạo Web Service Registry
```bash
# Tạo service registry cho web service
WEB_SERVICE_ID=$(aws servicediscovery create-service \
    --name web \
    --namespace-id $NAMESPACE_ID \
    --dns-config NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=60}] \
    --health-check-custom-config FailureThreshold=1 \
    --description "Web service registry" \
    --query 'Service.Id' \
    --output text)

echo "Web Service Registry ID: $WEB_SERVICE_ID"
```

### 3.2 Tạo API Service Registry
```bash
# Tạo service registry cho API service
API_SERVICE_ID=$(aws servicediscovery create-service \
    --name api \
    --namespace-id $NAMESPACE_ID \
    --dns-config NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=60}] \
    --health-check-custom-config FailureThreshold=1 \
    --description "API service registry" \
    --query 'Service.Id' \
    --output text)

echo "API Service Registry ID: $API_SERVICE_ID"
```

### 3.3 Tạo Database Service Registry
```bash
# Tạo service registry cho database service
DB_SERVICE_ID=$(aws servicediscovery create-service \
    --name db \
    --namespace-id $NAMESPACE_ID \
    --dns-config NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=60}] \
    --health-check-custom-config FailureThreshold=1 \
    --description "Database service registry" \
    --query 'Service.Id' \
    --output text)

echo "Database Service Registry ID: $DB_SERVICE_ID"
```

## Bước 4: Tạo Sample Applications

### 4.1 Tạo Web Application Task Definition
```bash
# Tạo task definition cho web application
cat > web-task-definition.json << EOF
{
    "family": "web-app",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole",
    "taskRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskRole",
    "containerDefinitions": [
        {
            "name": "web",
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
                    "awslogs-group": "/ecs/web-app",
                    "awslogs-region": "$(aws configure get region)",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "environment": [
                {
                    "name": "API_ENDPOINT",
                    "value": "http://api.workshop.local"
                }
            ]
        }
    ]
}
EOF

# Tạo CloudWatch log group
aws logs create-log-group --log-group-name /ecs/web-app

# Register task definition
aws ecs register-task-definition --cli-input-json file://web-task-definition.json
```

### 4.2 Tạo API Application Task Definition
```bash
# Tạo task definition cho API application
cat > api-task-definition.json << EOF
{
    "family": "api-app",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole",
    "taskRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskRole",
    "containerDefinitions": [
        {
            "name": "api",
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
                    "awslogs-group": "/ecs/api-app",
                    "awslogs-region": "$(aws configure get region)",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "environment": [
                {
                    "name": "DB_ENDPOINT",
                    "value": "db.workshop.local"
                }
            ]
        }
    ]
}
EOF

# Tạo CloudWatch log group
aws logs create-log-group --log-group-name /ecs/api-app

# Register task definition
aws ecs register-task-definition --cli-input-json file://api-task-definition.json
```

### 4.3 Tạo Database Task Definition
```bash
# Tạo task definition cho database
cat > db-task-definition.json << EOF
{
    "family": "db-app",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole",
    "taskRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskRole",
    "containerDefinitions": [
        {
            "name": "db",
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
                    "awslogs-group": "/ecs/db-app",
                    "awslogs-region": "$(aws configure get region)",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ]
}
EOF

# Tạo CloudWatch log group
aws logs create-log-group --log-group-name /ecs/db-app

# Register task definition
aws ecs register-task-definition --cli-input-json file://db-task-definition.json
```

## Bước 5: Tạo ECS Services với Service Discovery

### 5.1 Tạo Web Service
```bash
# Tạo web service với service discovery
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name web-service \
    --task-definition web-app \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --service-registries registryArn=arn:aws:servicediscovery:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):service/$WEB_SERVICE_ID

echo "Web service đã được tạo"
```

### 5.2 Tạo API Service
```bash
# Tạo API service với service discovery
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name api-service \
    --task-definition api-app \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --service-registries registryArn=arn:aws:servicediscovery:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):service/$API_SERVICE_ID

echo "API service đã được tạo"
```

### 5.3 Tạo Database Service
```bash
# Tạo database service với service discovery
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name db-service \
    --task-definition db-app \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --service-registries registryArn=arn:aws:servicediscovery:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):service/$DB_SERVICE_ID

echo "Database service đã được tạo"
```

## Bước 6: Xác minh Service Discovery

### 6.1 Kiểm tra Service Status
```bash
# Kiểm tra tất cả services status
aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services web-service api-service db-service \
    --query 'services[].{Name:serviceName,Status:status,Running:runningCount,Desired:desiredCount}'
```

### 6.2 List Service Discovery Instances
```bash
# List instances cho web service
echo "Web service instances:"
aws servicediscovery list-instances --service-id $WEB_SERVICE_ID

# List instances cho API service
echo "API service instances:"
aws servicediscovery list-instances --service-id $API_SERVICE_ID

# List instances cho database service
echo "Database service instances:"
aws servicediscovery list-instances --service-id $DB_SERVICE_ID
```

### 6.3 Test DNS Resolution
Để test DNS resolution, chúng ta sẽ tạo temporary task có thể thực hiện DNS lookups:

```bash
# Tạo test task definition
cat > test-task-definition.json << EOF
{
    "family": "dns-test",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole",
    "containerDefinitions": [
        {
            "name": "dns-test",
            "image": "alpine:latest",
            "command": ["sleep", "300"],
            "essential": true,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/dns-test",
                    "awslogs-region": "$(aws configure get region)",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ]
}
EOF

# Tạo log group và register task definition
aws logs create-log-group --log-group-name /ecs/dns-test
aws ecs register-task-definition --cli-input-json file://test-task-definition.json

# Chạy test task
TEST_TASK_ARN=$(aws ecs run-task \
    --cluster $CLUSTER_NAME \
    --task-definition dns-test \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --query 'tasks[0].taskArn' \
    --output text)

echo "Test task ARN: $TEST_TASK_ARN"

# Chờ task running
echo "Đang chờ test task running..."
aws ecs wait tasks-running --cluster $CLUSTER_NAME --tasks $TEST_TASK_ARN
```

## Bước 7: Advanced Service Discovery Features

### 7.1 Health Checks
Service discovery tự động thực hiện health checks. Bạn có thể xem health status:

```bash
# Lấy health status cho tất cả services
aws servicediscovery get-instances-health-status --service-id $WEB_SERVICE_ID
aws servicediscovery get-instances-health-status --service-id $API_SERVICE_ID
aws servicediscovery get-instances-health-status --service-id $DB_SERVICE_ID
```

### 7.2 Custom Attributes
Bạn có thể thêm custom attributes vào service instances:

```bash
# Ví dụ: Thêm custom attributes vào service
aws servicediscovery register-instance \
    --service-id $WEB_SERVICE_ID \
    --instance-id custom-web-instance \
    --attributes AWS_INSTANCE_IPV4=10.0.3.100,environment=production,version=1.0
```

### 7.3 Service Discovery Metrics
Enable CloudWatch metrics cho service discovery:

```bash
# Service discovery tự động publish metrics vào CloudWatch
# Xem available metrics
aws cloudwatch list-metrics --namespace AWS/ServiceDiscovery
```

## Bước 8: Cập nhật Environment Variables

Lưu service discovery resources mới:

```bash
# Cập nhật environment variables file
cat >> workshop-resources.env << EOF
export NAMESPACE_ID=$NAMESPACE_ID
export WEB_SERVICE_ID=$WEB_SERVICE_ID
export API_SERVICE_ID=$API_SERVICE_ID
export DB_SERVICE_ID=$DB_SERVICE_ID
EOF

echo "Service discovery resources đã được thêm vào workshop-resources.env"
```

## Testing Service Discovery

### DNS Resolution Test
Khi test task của bạn đang chạy, bạn có thể execute commands để test DNS resolution:

```bash
# Lấy task ID (short form)
TASK_ID=$(echo $TEST_TASK_ARN | cut -d'/' -f3)

# Test DNS resolution (cần ECS Exec được enable)
# Hiện tại, chúng ta sẽ kiểm tra CloudWatch logs để xem services có được registered không

# Kiểm tra service registration trong CloudWatch logs
aws logs describe-log-streams --log-group-name /ecs/web-app
aws logs describe-log-streams --log-group-name /ecs/api-app
aws logs describe-log-streams --log-group-name /ecs/db-app
```

## Troubleshooting

### Các vấn đề thường gặp

1. **Service Registration Fails**
   - Kiểm tra service registry tồn tại
   - Xác minh ECS service có proper IAM permissions
   - Đảm bảo network configuration cho phép communication

2. **DNS Resolution không hoạt động**
   - Xác minh VPC có DNS resolution và DNS hostnames enabled
   - Kiểm tra tasks trong cùng VPC với namespace
   - Đảm bảo security groups cho phép required traffic

3. **Health Check Failures**
   - Kiểm tra container health và logs
   - Xác minh port configurations match
   - Review security group rules

### Verification Commands
```bash
# Kiểm tra namespace status
aws servicediscovery get-namespace --id $NAMESPACE_ID

# List tất cả services trong namespace
aws servicediscovery list-services --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID

# Kiểm tra service instances
aws servicediscovery list-instances --service-id $WEB_SERVICE_ID

# Xác minh ECS services
aws ecs describe-services --cluster $CLUSTER_NAME --services web-service api-service db-service
```

## Best Practices

1. **Naming Conventions**
   - Sử dụng consistent naming cho services và namespaces
   - Bao gồm environment và application identifiers

2. **TTL Configuration**
   - Sử dụng appropriate TTL values (60 seconds tốt cho hầu hết cases)
   - Lower TTL cho frequently changing services

3. **Health Checks**
   - Cấu hình appropriate failure thresholds
   - Monitor health check metrics

4. **Security**
   - Sử dụng private namespaces cho internal communication
   - Triển khai proper security group rules

## Bước tiếp theo

Tuyệt vời! Bạn đã triển khai thành công service discovery cho ECS services. Services của bạn bây giờ có thể giao tiếp với nhau sử dụng DNS names như:

- `web.workshop.local`
- `api.workshop.local`
- `db.workshop.local`

Tiếp theo, chúng ta sẽ chuyển đến [Load Balancing nâng cao](../5-load-balancing/) nơi chúng ta sẽ thiết lập Application Load Balancers với advanced routing capabilities.

---

**Resources đã tạo:**
- 1 Private DNS Namespace
- 3 Service Discovery Services
- 3 ECS Services với Service Discovery
- 3 Task Definitions
- 3 CloudWatch Log Groups

**Key Benefits đã đạt được:**
- ✅ DNS-based service discovery
- ✅ Automatic service registration/deregistration
- ✅ Health checking integration
- ✅ Simplified service-to-service communication

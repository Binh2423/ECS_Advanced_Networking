---
title : "Triển khai Service Discovery"
date : "`r Sys.Date()`"
weight : 4
chapter : false
pre : " <b> 4. </b> "
---

# Triển khai Service Discovery

## Service Discovery là gì?

Giống như danh bạ điện thoại, Service Discovery giúp các services tìm thấy nhau bằng tên thay vì phải nhớ địa chỉ IP.

**Ví dụ:**
- Thay vì: `http://10.0.3.100:3000`
- Dùng: `http://api.myapp.local`

## Tổng quan

Chúng ta sẽ tạo 3 services có thể giao tiếp với nhau:

```
Frontend ←→ API ←→ Database
   ↓         ↓        ↓
frontend.  api.   db.myapp.
myapp.local myapp.local local
```

## Bước 1: Chuẩn bị

### 1.1 Load environment

```bash
cd ~/ecs-workshop
source workshop-env.sh

# Kiểm tra variables
echo "VPC ID: $VPC_ID"
echo "Cluster: $CLUSTER_NAME"
```

### 1.2 Tạo CloudWatch Log Groups

```bash
# Tạo log groups cho các services
aws logs create-log-group --log-group-name /ecs/frontend
aws logs create-log-group --log-group-name /ecs/api  
aws logs create-log-group --log-group-name /ecs/database

echo "✅ Log groups đã tạo"
```

## Bước 2: Tạo Private DNS Namespace

### 2.1 Tạo Namespace

```bash
# Tạo private DNS namespace
NAMESPACE_OPERATION=$(aws servicediscovery create-private-dns-namespace \
    --name myapp.local \
    --vpc $VPC_ID \
    --description "Private DNS namespace for workshop" \
    --query 'OperationId' \
    --output text)

echo "✅ Đang tạo namespace... Operation: $NAMESPACE_OPERATION"
```

### 2.2 Chờ namespace hoàn thành

```bash
# Chờ operation hoàn thành
echo "⏳ Chờ namespace tạo xong..."
while true; do
    STATUS=$(aws servicediscovery get-operation --operation-id $NAMESPACE_OPERATION --query 'Operation.Status' --output text)
    echo "Status: $STATUS"
    
    if [ "$STATUS" = "SUCCESS" ]; then
        echo "✅ Namespace đã tạo xong!"
        break
    elif [ "$STATUS" = "FAIL" ]; then
        echo "❌ Tạo namespace thất bại!"
        exit 1
    fi
    
    sleep 10
done
```

### 2.3 Lấy Namespace ID

```bash
# Lấy namespace ID
NAMESPACE_ID=$(aws servicediscovery list-namespaces \
    --filters Name=TYPE,Values=DNS_PRIVATE \
    --query 'Namespaces[?Name==`myapp.local`].Id' \
    --output text)

echo "✅ Namespace ID: $NAMESPACE_ID"

# Lưu vào file
echo "export NAMESPACE_ID=$NAMESPACE_ID" >> workshop-env.sh
```

### 2.4 Xem trong Console

1. Mở [Route 53 Console](https://console.aws.amazon.com/route53/)
2. Chọn "Hosted zones" 
3. Tìm "myapp.local" (Private hosted zone)

![Route53 Hosted Zones](/images/route53-hosted-zones.png)

## Bước 3: Tạo Service Registry

### 3.1 Frontend Service Registry

```bash
FRONTEND_SERVICE_ID=$(aws servicediscovery create-service \
    --name frontend \
    --namespace-id $NAMESPACE_ID \
    --dns-config NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=60}] \
    --health-check-custom-config FailureThreshold=1 \
    --description "Frontend service registry" \
    --query 'Service.Id' \
    --output text)

echo "✅ Frontend Service ID: $FRONTEND_SERVICE_ID"
```

### 3.2 API Service Registry

```bash
API_SERVICE_ID=$(aws servicediscovery create-service \
    --name api \
    --namespace-id $NAMESPACE_ID \
    --dns-config NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=60}] \
    --health-check-custom-config FailureThreshold=1 \
    --description "API service registry" \
    --query 'Service.Id' \
    --output text)

echo "✅ API Service ID: $API_SERVICE_ID"
```

### 3.3 Database Service Registry

```bash
DB_SERVICE_ID=$(aws servicediscovery create-service \
    --name db \
    --namespace-id $NAMESPACE_ID \
    --dns-config NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=60}] \
    --health-check-custom-config FailureThreshold=1 \
    --description "Database service registry" \
    --query 'Service.Id' \
    --output text)

echo "✅ Database Service ID: $DB_SERVICE_ID"

# Lưu tất cả service IDs
echo "export FRONTEND_SERVICE_ID=$FRONTEND_SERVICE_ID" >> workshop-env.sh
echo "export API_SERVICE_ID=$API_SERVICE_ID" >> workshop-env.sh
echo "export DB_SERVICE_ID=$DB_SERVICE_ID" >> workshop-env.sh
```

## Bước 4: Tạo Task Definitions

### 4.1 Frontend Task Definition

```bash
cat > frontend-task-definition.json << EOF
{
    "family": "frontend-app",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole",
    "taskRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskRole",
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
                    "awslogs-group": "/ecs/frontend",
                    "awslogs-region": "$(aws configure get region)",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "environment": [
                {
                    "name": "API_ENDPOINT",
                    "value": "http://api.myapp.local"
                }
            ]
        }
    ]
}
EOF

# Register task definition
aws ecs register-task-definition --cli-input-json file://frontend-task-definition.json
echo "✅ Frontend task definition đã tạo"
```

### 4.2 API Task Definition

```bash
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
                    "awslogs-group": "/ecs/api",
                    "awslogs-region": "$(aws configure get region)",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "environment": [
                {
                    "name": "DB_ENDPOINT",
                    "value": "db.myapp.local"
                }
            ]
        }
    ]
}
EOF

aws ecs register-task-definition --cli-input-json file://api-task-definition.json
echo "✅ API task definition đã tạo"
```

### 4.3 Database Task Definition

```bash
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
                    "awslogs-group": "/ecs/database",
                    "awslogs-region": "$(aws configure get region)",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ]
}
EOF

aws ecs register-task-definition --cli-input-json file://db-task-definition.json
echo "✅ Database task definition đã tạo"
```

![ECS Task Definitions](/images/ecs-task-definitions.png)

## Bước 5: Tạo ECS Services

### 5.1 Database Service (tạo trước)

```bash
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name db-service \
    --task-definition db-app \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={
        subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],
        securityGroups=[$ECS_SG],
        assignPublicIp=DISABLED
    }" \
    --service-registries "registryArn=arn:aws:servicediscovery:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):service/$DB_SERVICE_ID"

echo "✅ Database service đã tạo"
```

### 5.2 API Service

```bash
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name api-service \
    --task-definition api-app \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={
        subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],
        securityGroups=[$ECS_SG],
        assignPublicIp=DISABLED
    }" \
    --service-registries "registryArn=arn:aws:servicediscovery:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):service/$API_SERVICE_ID"

echo "✅ API service đã tạo"
```

### 5.3 Frontend Service

```bash
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name frontend-service \
    --task-definition frontend-app \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={
        subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],
        securityGroups=[$ECS_SG],
        assignPublicIp=DISABLED
    }" \
    --service-registries "registryArn=arn:aws:servicediscovery:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):service/$FRONTEND_SERVICE_ID"

echo "✅ Frontend service đã tạo"
```

### 5.4 Xem Services trong Console

1. Mở [ECS Console](https://console.aws.amazon.com/ecs/)
2. Chọn cluster "ecs-workshop-cluster"
3. Tab "Services" - xem 3 services
4. Kiểm tra Status = "ACTIVE"

![ECS Services Overview](/images/ecs-services-overview.png)

## Bước 6: Kiểm tra Service Discovery

### 6.1 Chờ services chạy

```bash
echo "⏳ Chờ services chạy..."
aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services frontend-service api-service db-service

echo "✅ Tất cả services đã chạy ổn định"
```

### 6.2 Kiểm tra service registration

```bash
echo "=== Service Discovery Status ==="

echo "Frontend instances:"
aws servicediscovery list-instances --service-id $FRONTEND_SERVICE_ID \
    --query 'Instances[].{Id:Id,IPv4:Attributes.AWS_INSTANCE_IPV4}'

echo "API instances:"
aws servicediscovery list-instances --service-id $API_SERVICE_ID \
    --query 'Instances[].{Id:Id,IPv4:Attributes.AWS_INSTANCE_IPV4}'

echo "Database instances:"
aws servicediscovery list-instances --service-id $DB_SERVICE_ID \
    --query 'Instances[].{Id:Id,IPv4:Attributes.AWS_INSTANCE_IPV4}'
```

### 6.3 Test DNS Resolution

```bash
# Tạo test task để test DNS
cat > dns-test-task.json << EOF
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

# Tạo log group và register task
aws logs create-log-group --log-group-name /ecs/dns-test
aws ecs register-task-definition --cli-input-json file://dns-test-task.json

echo "✅ DNS test task đã tạo"
```

## Bước 7: Xem kết quả

### 7.1 Kiểm tra ECS Services

```bash
aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services frontend-service api-service db-service \
    --query 'services[].{
        Name:serviceName,
        Status:status,
        Running:runningCount,
        Desired:desiredCount
    }' --output table
```

### 7.2 Xem DNS Records

1. Mở [Route 53 Console](https://console.aws.amazon.com/route53/)
2. Chọn "myapp.local" hosted zone
3. Xem các A records đã tự động tạo:
   - frontend.myapp.local
   - api.myapp.local  
   - db.myapp.local

![DNS Records](/images/route53-dns-records.png)

### 7.3 Kiểm tra Health Status

```bash
echo "=== Health Status ==="

aws servicediscovery get-instances-health-status --service-id $FRONTEND_SERVICE_ID
aws servicediscovery get-instances-health-status --service-id $API_SERVICE_ID  
aws servicediscovery get-instances-health-status --service-id $DB_SERVICE_ID
```

## Troubleshooting

### Vấn đề thường gặp:

**Services không register:**
```bash
# Kiểm tra service registry ARN
aws servicediscovery get-service --id $FRONTEND_SERVICE_ID

# Kiểm tra ECS service
aws ecs describe-services --cluster $CLUSTER_NAME --services frontend-service
```

**DNS không resolve:**
```bash
# Kiểm tra VPC DNS settings
aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsHostnames
aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsSupport
```

**Tasks không start:**
```bash
# Xem task logs
aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks TASK_ARN
```

## Tóm tắt

Bạn đã tạo thành công:

- ✅ Private DNS namespace (myapp.local)
- ✅ 3 service registries (frontend, api, db)
- ✅ 3 ECS services với service discovery
- ✅ Automatic DNS registration

**Kết quả:** Các services có thể giao tiếp với nhau qua DNS names:
- `frontend.myapp.local`
- `api.myapp.local`
- `db.myapp.local`

## Bước tiếp theo

Services đã có thể tìm thấy nhau! Tiếp theo chúng ta sẽ thêm [Load Balancer](../5-load-balancing/) để phân phối traffic từ internet.

---

**💡 Tip:** Service Discovery tự động cập nhật DNS khi services scale up/down.

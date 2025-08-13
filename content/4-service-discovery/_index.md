---
title : "ECS Cluster và Service Discovery"
date : "`r Sys.Date()`"
weight : 4
chapter : false
pre : " <b> 4. </b> "
---

# ECS Cluster và Service Discovery

## Tổng quan

{{< workshop-image src="images/ecs-architecture.png" alt="ECS Architecture" caption="ECS Cluster với Fargate tasks và Service Discovery" >}}

### Chúng ta sẽ tạo:

🚀 **ECS Cluster** với Fargate  
📋 **Task Definitions** cho các services  
🔍 **Service Discovery** với AWS Cloud Map  
⚖️ **ECS Services** với load balancing  

## Bước 1: Tạo ECS Cluster

### 1.1 Truy cập ECS Console

{{< console-screenshot src="images/ecs-console.png" alt="ECS Console" caption="Truy cập ECS Console để tạo cluster mới" service="ECS Console" >}}

**Các bước:**
1. Mở AWS Console
2. Tìm kiếm "ECS"
3. Click vào Elastic Container Service

### 1.2 Tạo Cluster mới

{{< console-screenshot src="images/create-cluster.png" alt="Create ECS Cluster" caption="Tạo ECS Cluster với Fargate launch type" service="ECS Console" >}}

```bash
# Load environment
source workshop-env.sh

# Tạo ECS Cluster
CLUSTER_NAME="ecs-workshop-cluster"
aws ecs create-cluster --cluster-name $CLUSTER_NAME

echo "✅ ECS Cluster: $CLUSTER_NAME"
echo "export CLUSTER_NAME=$CLUSTER_NAME" >> workshop-env.sh
```

## Bước 2: Tạo Cloud Map Namespace

### 2.1 Service Discovery Namespace

{{< console-screenshot src="images/cloud-map.png" alt="Cloud Map Namespace" caption="AWS Cloud Map cung cấp service discovery cho ECS" service="Cloud Map Console" >}}

```bash
# Tạo private DNS namespace
NAMESPACE_NAME="workshop.local"
NAMESPACE_ID=$(aws servicediscovery create-private-dns-namespace \
    --name $NAMESPACE_NAME \
    --vpc $VPC_ID \
    --description "Service discovery namespace for ECS workshop" \
    --query 'OperationId' --output text)

# Chờ operation hoàn thành
aws servicediscovery get-operation --operation-id $NAMESPACE_ID

echo "✅ Cloud Map Namespace: $NAMESPACE_NAME"
echo "export NAMESPACE_NAME=$NAMESPACE_NAME" >> workshop-env.sh
```

## Bước 3: Tạo IAM Roles

### 3.1 ECS Task Execution Role

```bash
# Tạo trust policy
cat > ecs-task-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Tạo execution role
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document file://ecs-task-trust-policy.json

# Attach managed policy
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

echo "✅ ECS Task Execution Role created"
```

## Bước 4: Tạo Task Definition

### 4.1 Frontend Task Definition

{{< console-screenshot src="images/task-definition.png" alt="Task Definition" caption="Task Definition định nghĩa container specifications" service="ECS Console" >}}

```bash
# Tạo frontend task definition
cat > frontend-task-def.json << 'EOF'
{
  "family": "workshop-frontend",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
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
          "awslogs-group": "/ecs/workshop-frontend",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
EOF

# Thay thế ACCOUNT_ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
sed -i "s/ACCOUNT_ID/$ACCOUNT_ID/g" frontend-task-def.json

# Tạo CloudWatch Log Group
aws logs create-log-group --log-group-name /ecs/workshop-frontend

# Register task definition
aws ecs register-task-definition --cli-input-json file://frontend-task-def.json

echo "✅ Frontend Task Definition registered"
```

### 4.2 Backend Task Definition

```bash
# Tạo backend task definition
cat > backend-task-def.json << 'EOF'
{
  "family": "workshop-backend",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "backend",
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
          "awslogs-group": "/ecs/workshop-backend",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
EOF

# Thay thế ACCOUNT_ID và tạo log group
sed -i "s/ACCOUNT_ID/$ACCOUNT_ID/g" backend-task-def.json
aws logs create-log-group --log-group-name /ecs/workshop-backend

# Register task definition
aws ecs register-task-definition --cli-input-json file://backend-task-def.json

echo "✅ Backend Task Definition registered"
```

## Bước 5: Tạo ECS Services

### 5.1 Backend Service với Service Discovery

{{< console-screenshot src="images/ecs-service.png" alt="ECS Service" caption="ECS Service quản lý và scale containers" service="ECS Console" >}}

```bash
# Lấy namespace ID
NAMESPACE_ID=$(aws servicediscovery list-namespaces \
    --filters Name=NAME,Values=$NAMESPACE_NAME \
    --query 'Namespaces[0].Id' --output text)

# Tạo backend service
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name workshop-backend \
    --task-definition workshop-backend:1 \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --service-registries "registryArn=arn:aws:servicediscovery:us-east-1:$ACCOUNT_ID:service/srv-backend,containerName=backend"

echo "✅ Backend Service created with Service Discovery"
```

### 5.2 Kiểm tra Service Status

```bash
# Kiểm tra service status
aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services workshop-backend \
    --query 'services[0].{Name:serviceName,Status:status,Running:runningCount,Desired:desiredCount}'

echo "✅ Service status checked"
```

## Bước 6: Test Service Discovery

### 6.1 Xem Service Discovery Records

{{< console-screenshot src="images/service-discovery.png" alt="Service Discovery" caption="Service Discovery records trong Cloud Map" service="Cloud Map Console" >}}

```bash
# List service discovery services
aws servicediscovery list-services \
    --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID

# Kiểm tra DNS records
aws servicediscovery get-instances-health-status \
    --service-id srv-backend

echo "✅ Service Discovery configured"
```

### 6.2 Test DNS Resolution

```bash
# Tạo test task để kiểm tra DNS
cat > test-task-def.json << 'EOF'
{
  "family": "workshop-test",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "test",
      "image": "busybox:latest",
      "command": ["sleep", "3600"],
      "essential": true
    }
  ]
}
EOF

sed -i "s/ACCOUNT_ID/$ACCOUNT_ID/g" test-task-def.json
aws ecs register-task-definition --cli-input-json file://test-task-def.json

echo "✅ Test task definition created"
```

## Kiểm tra kết quả

### 6.3 Xem ECS Services trong Console

{{< console-screenshot src="images/ecs-services-running.png" alt="ECS Services Running" caption="ECS Services đang chạy với healthy tasks" service="ECS Console" >}}

### 6.4 Tóm tắt ECS Infrastructure

```bash
echo "📋 ECS Infrastructure Summary:"
echo "================================"
echo "Cluster: $CLUSTER_NAME"
echo "Namespace: $NAMESPACE_NAME"
echo "Services: workshop-backend (with Service Discovery)"
echo "Task Definitions: workshop-frontend, workshop-backend"
echo ""
echo "✅ ECS Cluster setup completed!"
```

{{< alert type="success" title="Hoàn thành!" >}}
🎉 **ECS Cluster đã sẵn sàng!**  
✅ ECS Cluster với Fargate  
✅ Service Discovery với Cloud Map  
✅ Backend service đang chạy  
✅ Task definitions đã được tạo  
{{< /alert >}}

## Bước tiếp theo

ECS Cluster và Service Discovery đã hoàn tất. Tiếp theo chúng ta sẽ thiết lập Load Balancer!

{{< button href="../5-load-balancing/" >}}Tiếp theo: Load Balancing →{{< /button >}}

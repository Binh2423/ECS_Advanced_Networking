---
title : "Service Discovery Implementation"
date : "`r Sys.Date()`"
weight : 4
chapter : false
pre : " <b> 4. </b> "
---

# Service Discovery Implementation

In this section, we'll implement service discovery using AWS Cloud Map, enabling our ECS services to find and communicate with each other using DNS names instead of hard-coded IP addresses.

## What is Service Discovery?

Service discovery is a mechanism that allows services to find and communicate with each other without hard-coding network locations. In a dynamic container environment like ECS, services can be created, destroyed, and moved frequently, making service discovery essential for reliable communication.

## AWS Cloud Map Overview

AWS Cloud Map is a cloud resource discovery service that provides:
- **DNS-based service discovery**
- **Health checking**
- **Automatic registration/deregistration**
- **Integration with ECS services**

## Architecture

We'll create the following service discovery setup:

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Cloud Map                           │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │            Private DNS Namespace                        ││
│  │              workshop.local                             ││
│  │                                                         ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    ││
│  │  │   web.      │  │   api.      │  │   db.       │    ││
│  │  │ workshop.   │  │ workshop.   │  │ workshop.   │    ││
│  │  │   local     │  │   local     │  │   local     │    ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘    ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Step 1: Load Environment Variables

First, load the environment variables from the previous section:

```bash
# Load environment variables
source workshop-resources.env

# Verify variables are loaded
echo "VPC ID: $VPC_ID"
echo "Cluster Name: $CLUSTER_NAME"
```

## Step 2: Create Cloud Map Namespace

### 2.1 Create Private DNS Namespace
```bash
# Create private DNS namespace
NAMESPACE_ID=$(aws servicediscovery create-private-dns-namespace \
    --name workshop.local \
    --vpc $VPC_ID \
    --description "Private DNS namespace for ECS workshop" \
    --query 'OperationId' \
    --output text)

echo "Namespace creation operation ID: $NAMESPACE_ID"

# Wait for namespace creation to complete
echo "Waiting for namespace creation to complete..."
aws servicediscovery get-operation --operation-id $NAMESPACE_ID

# Get the namespace ID once created
NAMESPACE_ID=$(aws servicediscovery list-namespaces \
    --filters Name=TYPE,Values=DNS_PRIVATE \
    --query 'Namespaces[?Name==`workshop.local`].Id' \
    --output text)

echo "Namespace ID: $NAMESPACE_ID"
```

### 2.2 Verify Namespace Creation
```bash
# Describe the namespace
aws servicediscovery get-namespace --id $NAMESPACE_ID
```

## Step 3: Create Service Registry Services

### 3.1 Create Web Service Registry
```bash
# Create service registry for web service
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

### 3.2 Create API Service Registry
```bash
# Create service registry for API service
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

### 3.3 Create Database Service Registry
```bash
# Create service registry for database service
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

## Step 4: Create Sample Applications

### 4.1 Create Web Application Task Definition
```bash
# Create task definition for web application
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

# Create CloudWatch log group
aws logs create-log-group --log-group-name /ecs/web-app

# Register task definition
aws ecs register-task-definition --cli-input-json file://web-task-definition.json
```

### 4.2 Create API Application Task Definition
```bash
# Create task definition for API application
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

# Create CloudWatch log group
aws logs create-log-group --log-group-name /ecs/api-app

# Register task definition
aws ecs register-task-definition --cli-input-json file://api-task-definition.json
```

### 4.3 Create Database Task Definition
```bash
# Create task definition for database
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

# Create CloudWatch log group
aws logs create-log-group --log-group-name /ecs/db-app

# Register task definition
aws ecs register-task-definition --cli-input-json file://db-task-definition.json
```

## Step 5: Create ECS Services with Service Discovery

### 5.1 Create Web Service
```bash
# Create web service with service discovery
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name web-service \
    --task-definition web-app \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --service-registries registryArn=arn:aws:servicediscovery:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):service/$WEB_SERVICE_ID

echo "Web service created"
```

### 5.2 Create API Service
```bash
# Create API service with service discovery
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name api-service \
    --task-definition api-app \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --service-registries registryArn=arn:aws:servicediscovery:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):service/$API_SERVICE_ID

echo "API service created"
```

### 5.3 Create Database Service
```bash
# Create database service with service discovery
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name db-service \
    --task-definition db-app \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --service-registries registryArn=arn:aws:servicediscovery:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):service/$DB_SERVICE_ID

echo "Database service created"
```

## Step 6: Verify Service Discovery

### 6.1 Check Service Status
```bash
# Check all services status
aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services web-service api-service db-service \
    --query 'services[].{Name:serviceName,Status:status,Running:runningCount,Desired:desiredCount}'
```

### 6.2 List Service Discovery Instances
```bash
# List instances for web service
echo "Web service instances:"
aws servicediscovery list-instances --service-id $WEB_SERVICE_ID

# List instances for API service
echo "API service instances:"
aws servicediscovery list-instances --service-id $API_SERVICE_ID

# List instances for database service
echo "Database service instances:"
aws servicediscovery list-instances --service-id $DB_SERVICE_ID
```

### 6.3 Test DNS Resolution
To test DNS resolution, we'll create a temporary task that can perform DNS lookups:

```bash
# Create a test task definition
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

# Create log group and register task definition
aws logs create-log-group --log-group-name /ecs/dns-test
aws ecs register-task-definition --cli-input-json file://test-task-definition.json

# Run the test task
TEST_TASK_ARN=$(aws ecs run-task \
    --cluster $CLUSTER_NAME \
    --task-definition dns-test \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --query 'tasks[0].taskArn' \
    --output text)

echo "Test task ARN: $TEST_TASK_ARN"

# Wait for task to be running
echo "Waiting for test task to be running..."
aws ecs wait tasks-running --cluster $CLUSTER_NAME --tasks $TEST_TASK_ARN
```

## Step 7: Advanced Service Discovery Features

### 7.1 Health Checks
Service discovery automatically performs health checks. You can view the health status:

```bash
# Get health status for all services
aws servicediscovery get-instances-health-status --service-id $WEB_SERVICE_ID
aws servicediscovery get-instances-health-status --service-id $API_SERVICE_ID
aws servicediscovery get-instances-health-status --service-id $DB_SERVICE_ID
```

### 7.2 Custom Attributes
You can add custom attributes to service instances:

```bash
# Example: Add custom attributes to a service
aws servicediscovery register-instance \
    --service-id $WEB_SERVICE_ID \
    --instance-id custom-web-instance \
    --attributes AWS_INSTANCE_IPV4=10.0.3.100,environment=production,version=1.0
```

### 7.3 Service Discovery Metrics
Enable CloudWatch metrics for service discovery:

```bash
# Service discovery automatically publishes metrics to CloudWatch
# View available metrics
aws cloudwatch list-metrics --namespace AWS/ServiceDiscovery
```

## Step 8: Update Environment Variables

Save the new service discovery resources:

```bash
# Update environment variables file
cat >> workshop-resources.env << EOF
export NAMESPACE_ID=$NAMESPACE_ID
export WEB_SERVICE_ID=$WEB_SERVICE_ID
export API_SERVICE_ID=$API_SERVICE_ID
export DB_SERVICE_ID=$DB_SERVICE_ID
EOF

echo "Service discovery resources added to workshop-resources.env"
```

## Testing Service Discovery

### DNS Resolution Test
Once your test task is running, you can execute commands to test DNS resolution:

```bash
# Get the task ID (short form)
TASK_ID=$(echo $TEST_TASK_ARN | cut -d'/' -f3)

# Test DNS resolution (this requires ECS Exec to be enabled)
# For now, we'll check the CloudWatch logs to see if services are registered

# Check service registration in CloudWatch logs
aws logs describe-log-streams --log-group-name /ecs/web-app
aws logs describe-log-streams --log-group-name /ecs/api-app
aws logs describe-log-streams --log-group-name /ecs/db-app
```

## Troubleshooting

### Common Issues

1. **Service Registration Fails**
   - Check that the service registry exists
   - Verify ECS service has proper IAM permissions
   - Ensure network configuration allows communication

2. **DNS Resolution Not Working**
   - Verify VPC has DNS resolution and DNS hostnames enabled
   - Check that tasks are in the same VPC as the namespace
   - Ensure security groups allow the required traffic

3. **Health Check Failures**
   - Check container health and logs
   - Verify port configurations match
   - Review security group rules

### Verification Commands
```bash
# Check namespace status
aws servicediscovery get-namespace --id $NAMESPACE_ID

# List all services in namespace
aws servicediscovery list-services --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID

# Check service instances
aws servicediscovery list-instances --service-id $WEB_SERVICE_ID

# Verify ECS services
aws ecs describe-services --cluster $CLUSTER_NAME --services web-service api-service db-service
```

## Best Practices

1. **Naming Conventions**
   - Use consistent naming for services and namespaces
   - Include environment and application identifiers

2. **TTL Configuration**
   - Use appropriate TTL values (60 seconds is good for most cases)
   - Lower TTL for frequently changing services

3. **Health Checks**
   - Configure appropriate failure thresholds
   - Monitor health check metrics

4. **Security**
   - Use private namespaces for internal communication
   - Implement proper security group rules

## Next Steps

Excellent! You've successfully implemented service discovery for your ECS services. Your services can now communicate with each other using DNS names like:

- `web.workshop.local`
- `api.workshop.local`
- `db.workshop.local`

Next, we'll move on to [Advanced Load Balancing](../5-load-balancing/) where we'll set up Application Load Balancers with advanced routing capabilities.

---

**Resources Created:**
- 1 Private DNS Namespace
- 3 Service Discovery Services
- 3 ECS Services with Service Discovery
- 3 Task Definitions
- 3 CloudWatch Log Groups

**Key Benefits Achieved:**
- ✅ DNS-based service discovery
- ✅ Automatic service registration/deregistration
- ✅ Health checking integration
- ✅ Simplified service-to-service communication

---
title : "Clean up Resources"
date : "`r Sys.Date()`"
weight : 8
chapter : false
pre : " <b> 8. </b> "
---

# Clean up Resources

> **Important**: This section will delete all resources created during the workshop. Make sure you have completed all exercises and saved any important configurations before proceeding.

To avoid ongoing charges, it's crucial to clean up all AWS resources created during this workshop. We'll delete resources in the reverse order of creation to handle dependencies properly.

## Step 1: Load Environment Variables

First, load all the environment variables from the workshop:

```bash
# Load environment variables
source workshop-resources.env

# Verify variables are loaded
echo "VPC ID: $VPC_ID"
echo "Cluster Name: $CLUSTER_NAME"
```

## Step 2: Delete ECS Services

### 2.1 Scale Down Services
```bash
# Scale down all services to 0
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service web-service \
    --desired-count 0

aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service api-service \
    --desired-count 0

aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service db-service \
    --desired-count 0

echo "Services scaled down to 0. Waiting for tasks to stop..."

# Wait for services to stabilize
aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services web-service api-service db-service
```

### 2.2 Delete ECS Services
```bash
# Delete ECS services
aws ecs delete-service \
    --cluster $CLUSTER_NAME \
    --service web-service \
    --force

aws ecs delete-service \
    --cluster $CLUSTER_NAME \
    --service api-service \
    --force

aws ecs delete-service \
    --cluster $CLUSTER_NAME \
    --service db-service \
    --force

echo "ECS services deleted"
```

### 2.3 Stop Any Running Tasks
```bash
# List and stop any remaining tasks
RUNNING_TASKS=$(aws ecs list-tasks \
    --cluster $CLUSTER_NAME \
    --desired-status RUNNING \
    --query 'taskArns[]' \
    --output text)

if [ ! -z "$RUNNING_TASKS" ]; then
    echo "Stopping remaining tasks..."
    for task in $RUNNING_TASKS; do
        aws ecs stop-task --cluster $CLUSTER_NAME --task $task
    done
    
    # Wait for tasks to stop
    aws ecs wait tasks-stopped --cluster $CLUSTER_NAME --tasks $RUNNING_TASKS
fi
```

## Step 3: Delete Load Balancer Resources

### 3.1 Delete Target Groups
```bash
# List and delete target groups
TARGET_GROUPS=$(aws elbv2 describe-target-groups \
    --query 'TargetGroups[?VpcId==`'$VPC_ID'`].TargetGroupArn' \
    --output text)

if [ ! -z "$TARGET_GROUPS" ]; then
    echo "Deleting target groups..."
    for tg in $TARGET_GROUPS; do
        aws elbv2 delete-target-group --target-group-arn $tg
    done
fi
```

### 3.2 Delete Load Balancers
```bash
# List and delete load balancers in the VPC
LOAD_BALANCERS=$(aws elbv2 describe-load-balancers \
    --query 'LoadBalancers[?VpcId==`'$VPC_ID'`].LoadBalancerArn' \
    --output text)

if [ ! -z "$LOAD_BALANCERS" ]; then
    echo "Deleting load balancers..."
    for lb in $LOAD_BALANCERS; do
        aws elbv2 delete-load-balancer --load-balancer-arn $lb
    done
    
    # Wait for load balancers to be deleted
    echo "Waiting for load balancers to be deleted..."
    sleep 60
fi
```

## Step 4: Delete Service Discovery Resources

### 4.1 Deregister Service Instances
```bash
# Deregister instances from service discovery (if any manual registrations exist)
if [ ! -z "$WEB_SERVICE_ID" ]; then
    INSTANCES=$(aws servicediscovery list-instances \
        --service-id $WEB_SERVICE_ID \
        --query 'Instances[].Id' \
        --output text)
    
    for instance in $INSTANCES; do
        aws servicediscovery deregister-instance \
            --service-id $WEB_SERVICE_ID \
            --instance-id $instance
    done
fi
```

### 4.2 Delete Service Discovery Services
```bash
# Delete service discovery services
if [ ! -z "$WEB_SERVICE_ID" ]; then
    aws servicediscovery delete-service --id $WEB_SERVICE_ID
    echo "Web service discovery deleted"
fi

if [ ! -z "$API_SERVICE_ID" ]; then
    aws servicediscovery delete-service --id $API_SERVICE_ID
    echo "API service discovery deleted"
fi

if [ ! -z "$DB_SERVICE_ID" ]; then
    aws servicediscovery delete-service --id $DB_SERVICE_ID
    echo "Database service discovery deleted"
fi
```

### 4.3 Delete Service Discovery Namespace
```bash
# Delete the namespace
if [ ! -z "$NAMESPACE_ID" ]; then
    aws servicediscovery delete-namespace --id $NAMESPACE_ID
    echo "Service discovery namespace deleted"
fi
```

## Step 5: Delete ECS Cluster

```bash
# Delete ECS cluster
aws ecs delete-cluster --cluster $CLUSTER_NAME
echo "ECS cluster deleted"
```

## Step 6: Delete Task Definitions

```bash
# Deregister task definitions
TASK_FAMILIES=("web-app" "api-app" "db-app" "dns-test")

for family in "${TASK_FAMILIES[@]}"; do
    # Get all revisions for the family
    REVISIONS=$(aws ecs list-task-definitions \
        --family-prefix $family \
        --status ACTIVE \
        --query 'taskDefinitionArns[]' \
        --output text)
    
    # Deregister each revision
    for revision in $REVISIONS; do
        aws ecs deregister-task-definition --task-definition $revision
        echo "Deregistered task definition: $revision"
    done
done
```

## Step 7: Delete CloudWatch Log Groups

```bash
# Delete CloudWatch log groups
LOG_GROUPS=("/ecs/web-app" "/ecs/api-app" "/ecs/db-app" "/ecs/dns-test")

for log_group in "${LOG_GROUPS[@]}"; do
    aws logs delete-log-group --log-group-name $log_group 2>/dev/null || echo "Log group $log_group not found or already deleted"
done

echo "CloudWatch log groups deleted"
```

## Step 8: Delete VPC Endpoints (if created)

```bash
# Delete VPC endpoints
VPC_ENDPOINTS=$(aws ec2 describe-vpc-endpoints \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'VpcEndpoints[].VpcEndpointId' \
    --output text)

if [ ! -z "$VPC_ENDPOINTS" ]; then
    echo "Deleting VPC endpoints..."
    for endpoint in $VPC_ENDPOINTS; do
        aws ec2 delete-vpc-endpoint --vpc-endpoint-id $endpoint
    done
fi
```

## Step 9: Delete NAT Gateways

```bash
# Delete NAT Gateways
if [ ! -z "$NAT_GW_1" ]; then
    aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_1
    echo "NAT Gateway 1 deletion initiated"
fi

if [ ! -z "$NAT_GW_2" ]; then
    aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_2
    echo "NAT Gateway 2 deletion initiated"
fi

# Wait for NAT Gateways to be deleted
if [ ! -z "$NAT_GW_1" ] || [ ! -z "$NAT_GW_2" ]; then
    echo "Waiting for NAT Gateways to be deleted (this may take several minutes)..."
    sleep 120
fi
```

## Step 10: Release Elastic IPs

```bash
# Get and release Elastic IPs associated with NAT Gateways
EIP_ALLOCATIONS=$(aws ec2 describe-addresses \
    --filters "Name=domain,Values=vpc" \
    --query 'Addresses[?AssociationId==null].AllocationId' \
    --output text)

if [ ! -z "$EIP_ALLOCATIONS" ]; then
    echo "Releasing Elastic IPs..."
    for allocation in $EIP_ALLOCATIONS; do
        aws ec2 release-address --allocation-id $allocation
        echo "Released EIP: $allocation"
    done
fi
```

## Step 11: Delete Security Groups

```bash
# Delete custom security groups (default security group cannot be deleted)
SECURITY_GROUPS=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
    --output text)

if [ ! -z "$SECURITY_GROUPS" ]; then
    echo "Deleting security groups..."
    for sg in $SECURITY_GROUPS; do
        aws ec2 delete-security-group --group-id $sg
        echo "Deleted security group: $sg"
    done
fi
```

## Step 12: Delete Route Tables and Routes

```bash
# Get custom route tables (not main route table)
ROUTE_TABLES=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
    --output text)

if [ ! -z "$ROUTE_TABLES" ]; then
    echo "Deleting route tables..."
    for rt in $ROUTE_TABLES; do
        # Disassociate from subnets first
        ASSOCIATIONS=$(aws ec2 describe-route-tables \
            --route-table-ids $rt \
            --query 'RouteTables[0].Associations[?Main!=`true`].RouteTableAssociationId' \
            --output text)
        
        for assoc in $ASSOCIATIONS; do
            aws ec2 disassociate-route-table --association-id $assoc
        done
        
        # Delete the route table
        aws ec2 delete-route-table --route-table-id $rt
        echo "Deleted route table: $rt"
    done
fi
```

## Step 13: Detach and Delete Internet Gateway

```bash
# Detach and delete Internet Gateway
if [ ! -z "$IGW_ID" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
    echo "Internet Gateway deleted: $IGW_ID"
fi
```

## Step 14: Delete Subnets

```bash
# Delete subnets
SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[].SubnetId' \
    --output text)

if [ ! -z "$SUBNETS" ]; then
    echo "Deleting subnets..."
    for subnet in $SUBNETS; do
        aws ec2 delete-subnet --subnet-id $subnet
        echo "Deleted subnet: $subnet"
    done
fi
```

## Step 15: Delete VPC

```bash
# Delete VPC
if [ ! -z "$VPC_ID" ]; then
    aws ec2 delete-vpc --vpc-id $VPC_ID
    echo "VPC deleted: $VPC_ID"
fi
```

## Step 16: Delete IAM Roles and Policies

```bash
# Delete custom IAM policy
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/ECSTaskCustomPolicy"

# Detach policy from role
aws iam detach-role-policy \
    --role-name ecsTaskRole \
    --policy-arn $POLICY_ARN 2>/dev/null || echo "Policy already detached or not found"

# Delete custom policy
aws iam delete-policy --policy-arn $POLICY_ARN 2>/dev/null || echo "Custom policy not found or already deleted"

# Detach AWS managed policies from roles
aws iam detach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>/dev/null || echo "Policy already detached"

# Delete IAM roles
aws iam delete-role --role-name ecsTaskExecutionRole 2>/dev/null || echo "ecsTaskExecutionRole not found or already deleted"
aws iam delete-role --role-name ecsTaskRole 2>/dev/null || echo "ecsTaskRole not found or already deleted"

echo "IAM roles and policies cleaned up"
```

## Step 17: Clean Up Local Files

```bash
# Remove local files created during the workshop
rm -f workshop-resources.env
rm -f ecs-task-execution-trust-policy.json
rm -f ecs-task-policy.json
rm -f web-task-definition.json
rm -f api-task-definition.json
rm -f db-task-definition.json
rm -f test-task-definition.json

echo "Local files cleaned up"
```

## Step 18: Verification

### 18.1 Verify Resource Deletion
```bash
# Verify VPC is deleted
aws ec2 describe-vpcs --vpc-ids $VPC_ID 2>/dev/null || echo "VPC successfully deleted"

# Verify ECS cluster is deleted
aws ecs describe-clusters --clusters $CLUSTER_NAME 2>/dev/null || echo "ECS cluster successfully deleted"

# Check for any remaining resources
echo "Checking for any remaining resources..."

# List any remaining ECS services
aws ecs list-services --cluster $CLUSTER_NAME 2>/dev/null || echo "No ECS services found"

# List any remaining load balancers
REMAINING_LBS=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName' --output text 2>/dev/null)
if [ -z "$REMAINING_LBS" ]; then
    echo "No load balancers found"
else
    echo "Remaining load balancers: $REMAINING_LBS"
fi
```

### 18.2 Check Billing
```bash
# Get current month's costs (requires billing permissions)
echo "Checking current month's costs..."
aws ce get-cost-and-usage \
    --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE 2>/dev/null || echo "Unable to retrieve cost information (requires billing permissions)"
```

## Cleanup Verification Checklist

Verify that the following resources have been deleted:

- [ ] ECS Services (web-service, api-service, db-service)
- [ ] ECS Cluster (ecs-workshop-cluster)
- [ ] Task Definitions (deregistered)
- [ ] Load Balancers and Target Groups
- [ ] Service Discovery Services and Namespace
- [ ] CloudWatch Log Groups
- [ ] NAT Gateways
- [ ] Elastic IP Addresses
- [ ] Security Groups (custom ones)
- [ ] Route Tables (custom ones)
- [ ] Internet Gateway
- [ ] Subnets
- [ ] VPC
- [ ] IAM Roles and Policies
- [ ] Local workshop files

## Troubleshooting Cleanup Issues

### Common Issues

1. **Resource Dependencies**
   - Some resources cannot be deleted while others depend on them
   - Follow the deletion order provided in this guide

2. **NAT Gateway Deletion**
   - NAT Gateways take time to delete (5-10 minutes)
   - Wait for deletion to complete before proceeding

3. **Security Group Deletion**
   - Security groups with active references cannot be deleted
   - Ensure all EC2 instances and load balancers are deleted first

4. **VPC Deletion Fails**
   - Check for remaining ENIs, VPC endpoints, or other resources
   - Use the VPC console to identify remaining dependencies

### Force Cleanup Commands

If some resources are stuck, you can try these force cleanup commands:

```bash
# Force delete security groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text | xargs -I {} aws ec2 delete-security-group --group-id {}

# Force delete network interfaces
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text | xargs -I {} aws ec2 delete-network-interface --network-interface-id {}
```

## Final Cost Check

After cleanup, monitor your AWS bill for the next few days to ensure no unexpected charges. The workshop should have cost approximately $15-25 total.

## Conclusion

Congratulations! You have successfully completed the ECS Advanced Networking Workshop and cleaned up all resources. 

### What You Accomplished

- ✅ Built a custom VPC with proper networking architecture
- ✅ Deployed ECS Fargate services with advanced networking
- ✅ Implemented service discovery with AWS Cloud Map
- ✅ Configured load balancing and traffic routing
- ✅ Applied security best practices
- ✅ Set up monitoring and logging
- ✅ Cleaned up all resources to avoid ongoing charges

### Next Steps

- Apply these concepts to your own projects
- Explore additional ECS features like Service Connect
- Learn about ECS Anywhere for hybrid deployments
- Consider pursuing AWS certifications

---

**Thank you for participating in the ECS Advanced Networking Workshop!**

For questions or feedback, please:
- Join our [AWS Study Group](https://www.facebook.com/groups/awsstudygroupfcj/)
- Open an issue on [GitHub](https://github.com/Binh2423/ECS_Advanced_Networking_Workshop)
- Connect with the AWS community

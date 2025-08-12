---
title : "Cleanup Resources"
date : "`r Sys.Date()`"
weight : 8
chapter : false
pre : " <b> 8. </b> "
---

# Cleanup Resources

## Tại sao Cleanup quan trọng?

Giống như dọn dẹp nhà cửa, cleanup AWS resources giúp bạn:
- **Tiết kiệm chi phí:** Tránh charges không cần thiết
- **Bảo mật:** Xóa resources không sử dụng
- **Tổ chức:** Giữ account sạch sẽ

**⚠️ Cảnh báo:** Cleanup sẽ xóa TẤT CẢ resources đã tạo trong workshop. Đảm bảo bạn đã backup mọi thứ cần thiết!

## Cleanup Strategy

```
Applications → Load Balancers → ECS → Networking → IAM → Monitoring
     ↓              ↓           ↓        ↓         ↓        ↓
  Stop Tasks    Delete ALB   Delete    Delete    Delete   Delete
                Delete TGs   Services   VPC      Roles    Logs
```

## Bước 1: Chuẩn bị Cleanup

### 1.1 Load environment và backup

```bash
cd ~/ecs-workshop
source workshop-env.sh

# Backup environment variables
cp workshop-env.sh workshop-env-backup.sh
echo "✅ Environment variables đã được backup"

# Tạo cleanup log
echo "🗑️ Starting cleanup at $(date)" > cleanup.log
```

### 1.2 Liệt kê resources sẽ xóa

```bash
echo "📋 Resources sẽ được xóa:"
echo "========================="

echo "ECS Services:"
aws ecs list-services --cluster $CLUSTER_NAME --query 'serviceArns' --output table

echo "Load Balancers:"
aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[].LoadBalancerName' --output table

echo "Target Groups:"
aws elbv2 describe-target-groups --target-group-arns $FRONTEND_TG_ARN $API_TG_ARN --query 'TargetGroups[].TargetGroupName' --output table

echo "Security Groups:"
aws ec2 describe-security-groups --group-ids $ALB_SG $ECS_SG $DB_SG $MGMT_SG --query 'SecurityGroups[].GroupName' --output table 2>/dev/null || echo "Some security groups not found"

echo "VPC Resources:"
echo "VPC ID: $VPC_ID"
echo "Subnets: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2, $PRIVATE_SUBNET_1, $PRIVATE_SUBNET_2"
```

### 1.3 Xác nhận cleanup

```bash
echo "⚠️  CẢNH BÁO: Bạn sắp xóa TẤT CẢ workshop resources!"
echo "Điều này sẽ:"
echo "- Xóa tất cả ECS services và tasks"
echo "- Xóa Load Balancer và Target Groups"
echo "- Xóa VPC và tất cả network resources"
echo "- Xóa IAM roles và policies"
echo "- Xóa CloudWatch logs và alarms"
echo ""
read -p "Bạn có chắc chắn muốn tiếp tục? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Cleanup đã bị hủy"
    exit 1
fi

echo "✅ Bắt đầu cleanup..." | tee -a cleanup.log
```

## Bước 2: Cleanup ECS Resources

### 2.1 Stop và Delete ECS Services

```bash
echo "🛑 Stopping ECS Services..." | tee -a cleanup.log

# Scale down services to 0
services=("frontend-service" "api-service" "db-service")

for service in "${services[@]}"; do
    echo "Scaling down $service to 0..." | tee -a cleanup.log
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $service \
        --desired-count 0 \
        --no-cli-pager 2>/dev/null || echo "Service $service not found"
done

# Wait for services to scale down
echo "⏳ Waiting for services to scale down..." | tee -a cleanup.log
sleep 30

# Delete services
for service in "${services[@]}"; do
    echo "Deleting $service..." | tee -a cleanup.log
    aws ecs delete-service \
        --cluster $CLUSTER_NAME \
        --service $service \
        --force \
        --no-cli-pager 2>/dev/null || echo "Service $service not found"
done

echo "✅ ECS Services cleanup completed" | tee -a cleanup.log
```

### 2.2 Delete ECS Cluster

```bash
echo "🗑️ Deleting ECS Cluster..." | tee -a cleanup.log

# Wait for services to be deleted
echo "⏳ Waiting for services to be fully deleted..."
sleep 60

# Delete cluster
aws ecs delete-cluster --cluster $CLUSTER_NAME --no-cli-pager 2>/dev/null || echo "Cluster not found"

echo "✅ ECS Cluster deleted" | tee -a cleanup.log
```

### 2.3 Deregister Task Definitions

```bash
echo "📋 Deregistering Task Definitions..." | tee -a cleanup.log

# List all task definition families
families=("frontend-app" "api-app" "db-app" "frontend-secure" "api-enhanced" "admin-app" "dns-test")

for family in "${families[@]}"; do
    echo "Deregistering $family task definitions..." | tee -a cleanup.log
    
    # Get all revisions for this family
    revisions=$(aws ecs list-task-definitions --family-prefix $family --query 'taskDefinitionArns' --output text 2>/dev/null)
    
    for revision in $revisions; do
        if [ ! -z "$revision" ]; then
            aws ecs deregister-task-definition --task-definition $revision --no-cli-pager 2>/dev/null || echo "Task definition $revision not found"
        fi
    done
done

echo "✅ Task Definitions cleanup completed" | tee -a cleanup.log
```

## Bước 3: Cleanup Load Balancer Resources

### 3.1 Delete Load Balancer

```bash
echo "⚖️ Deleting Load Balancer..." | tee -a cleanup.log

# Delete ALB
if [ ! -z "$ALB_ARN" ]; then
    aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --no-cli-pager 2>/dev/null || echo "ALB not found"
    echo "⏳ Waiting for ALB to be deleted..."
    sleep 60
fi

echo "✅ Load Balancer deleted" | tee -a cleanup.log
```

### 3.2 Delete Target Groups

```bash
echo "🎯 Deleting Target Groups..." | tee -a cleanup.log

target_groups=("$FRONTEND_TG_ARN" "$API_TG_ARN")

for tg in "${target_groups[@]}"; do
    if [ ! -z "$tg" ]; then
        echo "Deleting target group $tg..." | tee -a cleanup.log
        aws elbv2 delete-target-group --target-group-arn $tg --no-cli-pager 2>/dev/null || echo "Target group not found"
    fi
done

echo "✅ Target Groups deleted" | tee -a cleanup.log
```

## Bước 4: Cleanup Service Discovery

### 4.1 Delete Service Discovery Services

```bash
echo "🔍 Deleting Service Discovery..." | tee -a cleanup.log

service_ids=("$FRONTEND_SERVICE_ID" "$API_SERVICE_ID" "$DB_SERVICE_ID")

for service_id in "${service_ids[@]}"; do
    if [ ! -z "$service_id" ]; then
        echo "Deleting service discovery service $service_id..." | tee -a cleanup.log
        aws servicediscovery delete-service --id $service_id --no-cli-pager 2>/dev/null || echo "Service discovery service not found"
    fi
done

# Delete namespace
if [ ! -z "$NAMESPACE_ID" ]; then
    echo "Deleting namespace $NAMESPACE_ID..." | tee -a cleanup.log
    aws servicediscovery delete-namespace --id $NAMESPACE_ID --no-cli-pager 2>/dev/null || echo "Namespace not found"
fi

echo "✅ Service Discovery cleanup completed" | tee -a cleanup.log
```

## Bước 5: Cleanup Network Resources

### 5.1 Delete Security Groups

```bash
echo "🔒 Deleting Security Groups..." | tee -a cleanup.log

# Delete in reverse dependency order
security_groups=("$MGMT_SG" "$DB_SG" "$ECS_SG" "$ALB_SG")

for sg in "${security_groups[@]}"; do
    if [ ! -z "$sg" ]; then
        echo "Deleting security group $sg..." | tee -a cleanup.log
        
        # Remove all rules first
        aws ec2 describe-security-groups --group-ids $sg --query 'SecurityGroups[0].IpPermissions' --output json > /tmp/sg_rules.json 2>/dev/null
        if [ -s /tmp/sg_rules.json ] && [ "$(cat /tmp/sg_rules.json)" != "null" ]; then
            aws ec2 revoke-security-group-ingress --group-id $sg --ip-permissions file:///tmp/sg_rules.json --no-cli-pager 2>/dev/null || echo "No ingress rules to remove"
        fi
        
        aws ec2 describe-security-groups --group-ids $sg --query 'SecurityGroups[0].IpPermissionsEgress' --output json > /tmp/sg_egress_rules.json 2>/dev/null
        if [ -s /tmp/sg_egress_rules.json ] && [ "$(cat /tmp/sg_egress_rules.json)" != "null" ]; then
            aws ec2 revoke-security-group-egress --group-id $sg --ip-permissions file:///tmp/sg_egress_rules.json --no-cli-pager 2>/dev/null || echo "No egress rules to remove"
        fi
        
        # Delete security group
        aws ec2 delete-security-group --group-id $sg --no-cli-pager 2>/dev/null || echo "Security group $sg not found"
    fi
done

echo "✅ Security Groups deleted" | tee -a cleanup.log
```

### 5.2 Delete VPC Flow Logs

```bash
echo "📊 Deleting VPC Flow Logs..." | tee -a cleanup.log

# Get flow log IDs
flow_log_ids=$(aws ec2 describe-flow-logs --filter Name=resource-id,Values=$VPC_ID --query 'FlowLogs[].FlowLogId' --output text 2>/dev/null)

for flow_log_id in $flow_log_ids; do
    if [ ! -z "$flow_log_id" ]; then
        echo "Deleting flow log $flow_log_id..." | tee -a cleanup.log
        aws ec2 delete-flow-logs --flow-log-ids $flow_log_id --no-cli-pager 2>/dev/null || echo "Flow log not found"
    fi
done

echo "✅ VPC Flow Logs deleted" | tee -a cleanup.log
```

### 5.3 Delete VPC and Subnets

```bash
echo "🌐 Deleting VPC Resources..." | tee -a cleanup.log

# Delete NAT Gateways first
nat_gateways=$(aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=$VPC_ID --query 'NatGateways[].NatGatewayId' --output text 2>/dev/null)
for nat_gw in $nat_gateways; do
    if [ ! -z "$nat_gw" ]; then
        echo "Deleting NAT Gateway $nat_gw..." | tee -a cleanup.log
        aws ec2 delete-nat-gateway --nat-gateway-id $nat_gw --no-cli-pager 2>/dev/null || echo "NAT Gateway not found"
    fi
done

# Wait for NAT Gateways to be deleted
if [ ! -z "$nat_gateways" ]; then
    echo "⏳ Waiting for NAT Gateways to be deleted..."
    sleep 120
fi

# Delete Internet Gateway
igw_id=$(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$VPC_ID --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null)
if [ "$igw_id" != "None" ] && [ ! -z "$igw_id" ]; then
    echo "Detaching and deleting Internet Gateway $igw_id..." | tee -a cleanup.log
    aws ec2 detach-internet-gateway --internet-gateway-id $igw_id --vpc-id $VPC_ID --no-cli-pager 2>/dev/null || echo "IGW not attached"
    aws ec2 delete-internet-gateway --internet-gateway-id $igw_id --no-cli-pager 2>/dev/null || echo "IGW not found"
fi

# Delete Route Tables (except main)
route_tables=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text 2>/dev/null)
for rt in $route_tables; do
    if [ ! -z "$rt" ]; then
        echo "Deleting route table $rt..." | tee -a cleanup.log
        aws ec2 delete-route-table --route-table-id $rt --no-cli-pager 2>/dev/null || echo "Route table not found"
    fi
done

# Delete Subnets
subnets=("$PUBLIC_SUBNET_1" "$PUBLIC_SUBNET_2" "$PRIVATE_SUBNET_1" "$PRIVATE_SUBNET_2")
for subnet in "${subnets[@]}"; do
    if [ ! -z "$subnet" ]; then
        echo "Deleting subnet $subnet..." | tee -a cleanup.log
        aws ec2 delete-subnet --subnet-id $subnet --no-cli-pager 2>/dev/null || echo "Subnet not found"
    fi
done

# Delete VPC
if [ ! -z "$VPC_ID" ]; then
    echo "Deleting VPC $VPC_ID..." | tee -a cleanup.log
    aws ec2 delete-vpc --vpc-id $VPC_ID --no-cli-pager 2>/dev/null || echo "VPC not found"
fi

echo "✅ VPC Resources deleted" | tee -a cleanup.log
```

## Bước 6: Cleanup IAM Resources

### 6.1 Delete IAM Roles và Policies

```bash
echo "👤 Deleting IAM Resources..." | tee -a cleanup.log

# Delete custom policies
custom_policies=("ECSWorkshopTaskPolicy")
for policy in "${custom_policies[@]}"; do
    policy_arn="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$policy"
    echo "Deleting policy $policy..." | tee -a cleanup.log
    
    # Detach from roles first
    attached_roles=$(aws iam list-entities-for-policy --policy-arn $policy_arn --query 'PolicyRoles[].RoleName' --output text 2>/dev/null)
    for role in $attached_roles; do
        aws iam detach-role-policy --role-name $role --policy-arn $policy_arn --no-cli-pager 2>/dev/null || echo "Policy not attached to role"
    done
    
    # Delete policy
    aws iam delete-policy --policy-arn $policy_arn --no-cli-pager 2>/dev/null || echo "Policy not found"
done

# Delete custom roles
custom_roles=("ecsEnhancedTaskRole" "flowlogsRole")
for role in "${custom_roles[@]}"; do
    echo "Deleting role $role..." | tee -a cleanup.log
    
    # Detach managed policies
    attached_policies=$(aws iam list-attached-role-policies --role-name $role --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null)
    for policy_arn in $attached_policies; do
        aws iam detach-role-policy --role-name $role --policy-arn $policy_arn --no-cli-pager 2>/dev/null || echo "Policy not attached"
    done
    
    # Delete role
    aws iam delete-role --role-name $role --no-cli-pager 2>/dev/null || echo "Role not found"
done

echo "✅ IAM Resources deleted" | tee -a cleanup.log
```

## Bước 7: Cleanup Monitoring Resources

### 7.1 Delete CloudWatch Resources

```bash
echo "📊 Deleting CloudWatch Resources..." | tee -a cleanup.log

# Delete Dashboards
dashboards=("ECS-Workshop-Dashboard" "ECS-Network-Dashboard")
for dashboard in "${dashboards[@]}"; do
    echo "Deleting dashboard $dashboard..." | tee -a cleanup.log
    aws cloudwatch delete-dashboards --dashboard-names $dashboard --no-cli-pager 2>/dev/null || echo "Dashboard not found"
done

# Delete Alarms
alarms=("ECS-Frontend-High-CPU" "ECS-Frontend-High-Memory" "ECS-Frontend-Low-Task-Count" "ALB-High-4XX-Error-Rate" "ALB-High-Response-Time" "ALB-Unhealthy-Targets" "ECS-High-Error-Rate" "ECS-High-Network-Traffic")
for alarm in "${alarms[@]}"; do
    echo "Deleting alarm $alarm..." | tee -a cleanup.log
    aws cloudwatch delete-alarms --alarm-names $alarm --no-cli-pager 2>/dev/null || echo "Alarm not found"
done

# Delete Log Groups
log_groups=("/ecs/frontend" "/ecs/api" "/ecs/database" "/ecs/application-logs" "/ecs/error-logs" "/ecs/access-logs" "/ecs/api-enhanced" "/ecs/admin-app" "/ecs/dns-test" "/aws/vpc/flowlogs")
for log_group in "${log_groups[@]}"; do
    echo "Deleting log group $log_group..." | tee -a cleanup.log
    aws logs delete-log-group --log-group-name $log_group --no-cli-pager 2>/dev/null || echo "Log group not found"
done

echo "✅ CloudWatch Resources deleted" | tee -a cleanup.log
```

### 7.2 Delete SNS Topics

```bash
echo "📧 Deleting SNS Topics..." | tee -a cleanup.log

# Get SNS topic ARN
sns_topic_arn=$(aws sns list-topics --query 'Topics[?contains(TopicArn,`ecs-workshop-alerts`)].TopicArn' --output text 2>/dev/null)
if [ ! -z "$sns_topic_arn" ]; then
    echo "Deleting SNS topic $sns_topic_arn..." | tee -a cleanup.log
    aws sns delete-topic --topic-arn $sns_topic_arn --no-cli-pager 2>/dev/null || echo "SNS topic not found"
fi

echo "✅ SNS Topics deleted" | tee -a cleanup.log
```

## Bước 8: Cleanup Secrets và Parameters

### 8.1 Delete Secrets Manager Secrets

```bash
echo "🔐 Deleting Secrets..." | tee -a cleanup.log

secrets=("ecs-workshop/database" "ecs-workshop/api-keys")
for secret in "${secrets[@]}"; do
    echo "Deleting secret $secret..." | tee -a cleanup.log
    aws secretsmanager delete-secret --secret-id $secret --force-delete-without-recovery --no-cli-pager 2>/dev/null || echo "Secret not found"
done

echo "✅ Secrets deleted" | tee -a cleanup.log
```

### 8.2 Delete SSM Parameters

```bash
echo "⚙️ Deleting SSM Parameters..." | tee -a cleanup.log

parameters=("/ecs-workshop/app/environment" "/ecs-workshop/app/debug" "/ecs-workshop/app/max-connections")
for param in "${parameters[@]}"; do
    echo "Deleting parameter $param..." | tee -a cleanup.log
    aws ssm delete-parameter --name $param --no-cli-pager 2>/dev/null || echo "Parameter not found"
done

echo "✅ SSM Parameters deleted" | tee -a cleanup.log
```

## Bước 9: Cleanup Local Files

### 9.1 Delete Workshop Files

```bash
echo "🗂️ Cleaning up local files..." | tee -a cleanup.log

# List files to be deleted
echo "Files to be deleted:"
ls -la *.json *.sh *.py *.txt 2>/dev/null || echo "No files to delete"

# Delete generated files
files_to_delete=(
    "*.json"
    "custom-metrics.sh"
    "performance-monitor.sh"
    "health-check.sh"
    "load-test.sh"
    "log-insights-queries.txt"
    "/tmp/sg_rules.json"
    "/tmp/sg_egress_rules.json"
)

for pattern in "${files_to_delete[@]}"; do
    rm -f $pattern 2>/dev/null || echo "Files matching $pattern not found"
done

echo "✅ Local files cleaned up" | tee -a cleanup.log
```

### 9.2 Archive Workshop Data

```bash
echo "📦 Archiving workshop data..." | tee -a cleanup.log

# Create archive directory
mkdir -p workshop-archive

# Move important files to archive
mv workshop-env-backup.sh workshop-archive/ 2>/dev/null || echo "Backup file not found"
mv cleanup.log workshop-archive/ 2>/dev/null || echo "Cleanup log not found"

# Create summary file
cat > workshop-archive/cleanup-summary.txt << EOF
ECS Advanced Networking Workshop - Cleanup Summary
==================================================
Cleanup Date: $(date)
Region: $(aws configure get region)
Account: $(aws sts get-caller-identity --query Account --output text)

Resources Cleaned Up:
- ECS Cluster: $CLUSTER_NAME
- VPC: $VPC_ID
- Load Balancer: $ALB_ARN
- Security Groups: $ALB_SG, $ECS_SG, $DB_SG, $MGMT_SG
- Service Discovery Namespace: $NAMESPACE_ID

All workshop resources have been successfully deleted.
EOF

echo "✅ Workshop data archived in workshop-archive/" | tee -a cleanup.log
```

## Bước 10: Verification và Final Steps

### 10.1 Verify Cleanup

```bash
echo "🔍 Verifying cleanup..." | tee -a cleanup.log

echo "Checking remaining resources:"

# Check ECS
echo "ECS Clusters:"
aws ecs list-clusters --query 'clusterArns[?contains(@,`ecs-workshop`)]' --output text || echo "No ECS clusters found"

# Check Load Balancers
echo "Load Balancers:"
aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName,`ecs-workshop`)].LoadBalancerName' --output text || echo "No load balancers found"

# Check VPCs
echo "VPCs:"
aws ec2 describe-vpcs --filters Name=tag:Name,Values=ECS-Workshop-VPC --query 'Vpcs[].VpcId' --output text || echo "No VPCs found"

# Check Security Groups
echo "Security Groups:"
aws ec2 describe-security-groups --filters Name=group-name,Values=ecs-* --query 'SecurityGroups[].GroupName' --output text || echo "No security groups found"

# Check Log Groups
echo "Log Groups:"
aws logs describe-log-groups --log-group-name-prefix "/ecs/" --query 'logGroups[].logGroupName' --output text || echo "No log groups found"

echo "✅ Cleanup verification completed" | tee -a cleanup.log
```

### 10.2 Cost Estimation

```bash
echo "💰 Cost Impact Analysis..." | tee -a cleanup.log

cat << 'EOF'
Estimated Monthly Savings from Cleanup:
=======================================
- ECS Fargate Tasks (3 services): ~$30-50/month
- Application Load Balancer: ~$16/month
- NAT Gateway: ~$32/month
- VPC Flow Logs: ~$5-10/month
- CloudWatch Logs: ~$5/month
- Data Transfer: ~$5-15/month

Total Estimated Savings: ~$93-128/month

Note: Actual costs may vary based on usage patterns and region.
EOF
```

### 10.3 Final Summary

```bash
echo "🎉 Cleanup Summary" | tee -a cleanup.log
echo "==================" | tee -a cleanup.log

cat << EOF | tee -a cleanup.log
✅ CLEANUP COMPLETED SUCCESSFULLY!

Resources Deleted:
- ECS Services and Cluster
- Application Load Balancer and Target Groups
- VPC and all networking components
- Security Groups and NACLs
- Service Discovery namespace and services
- IAM roles and policies
- CloudWatch dashboards, alarms, and log groups
- SNS topics
- Secrets Manager secrets
- SSM parameters
- Local workshop files

Next Steps:
1. Review workshop-archive/ for any important data
2. Check AWS billing console in 24-48 hours to confirm no charges
3. Consider leaving feedback about the workshop experience

Thank you for completing the ECS Advanced Networking Workshop! 🚀
EOF

echo ""
echo "📁 Workshop archive location: $(pwd)/workshop-archive/"
echo "📊 Cleanup log: $(pwd)/workshop-archive/cleanup.log"
echo ""
echo "🎯 Pro Tip: Bookmark this cleanup script for future workshops!"
```

## Troubleshooting Cleanup Issues

### Vấn đề thường gặp:

**Resources không thể xóa do dependencies:**
```bash
# Kiểm tra dependencies
aws ec2 describe-network-interfaces --filters Name=vpc-id,Values=$VPC_ID
aws elbv2 describe-load-balancers --query 'LoadBalancers[?VpcId==`'$VPC_ID'`]'
```

**Security Groups không thể xóa:**
```bash
# Kiểm tra security group usage
aws ec2 describe-network-interfaces --filters Name=group-id,Values=$ECS_SG
aws ec2 describe-instances --filters Name=instance.group-id,Values=$ECS_SG
```

**VPC không thể xóa:**
```bash
# Kiểm tra VPC dependencies
aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=$VPC_ID
aws ec2 describe-network-interfaces --filters Name=vpc-id,Values=$VPC_ID
```

**Manual cleanup commands:**
```bash
# Force delete security group
aws ec2 delete-security-group --group-id $ECS_SG --force

# Force delete VPC
aws ec2 delete-vpc --vpc-id $VPC_ID --force

# Check billing
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 --granularity MONTHLY --metrics BlendedCost
```

## Emergency Cleanup Script

```bash
# Tạo emergency cleanup script
cat > emergency-cleanup.sh << 'EOF'
#!/bin/bash
echo "🚨 EMERGENCY CLEANUP - Deleting ALL ECS and VPC resources"

# Delete all ECS clusters
for cluster in $(aws ecs list-clusters --query 'clusterArns' --output text); do
    aws ecs delete-cluster --cluster $cluster --force
done

# Delete all custom VPCs
for vpc in $(aws ec2 describe-vpcs --filters Name=is-default,Values=false --query 'Vpcs[].VpcId' --output text); do
    aws ec2 delete-vpc --vpc-id $vpc
done

echo "Emergency cleanup completed"
EOF

chmod +x emergency-cleanup.sh
echo "⚠️ Emergency cleanup script created: emergency-cleanup.sh"
```

---

## 🎉 Chúc mừng!

Bạn đã hoàn thành thành công **ECS Advanced Networking Workshop** và cleanup tất cả resources!

**Những gì bạn đã học:**
- ✅ VPC và Networking cơ bản
- ✅ ECS Cluster và Services
- ✅ Service Discovery
- ✅ Load Balancing
- ✅ Security Best Practices
- ✅ Monitoring và Logging
- ✅ Resource Management và Cleanup

**Kỹ năng đã đạt được:**
- Container orchestration với ECS
- Advanced networking concepts
- AWS security implementation
- Monitoring và troubleshooting
- Cost optimization

Cảm ơn bạn đã tham gia workshop! 🚀

---

**💡 Cleanup Tip:** Luôn cleanup resources sau khi hoàn thành workshop để tránh chi phí không cần thiết.

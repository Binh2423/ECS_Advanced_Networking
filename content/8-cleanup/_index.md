---
title : "Cleanup Resources"
date : "`r Sys.Date()`"
weight : 8
chapter : false
pre : " <b> 8. </b> "
---

# Cleanup Resources

## Tại sao cần cleanup?

{{< alert type="warning" title="Quan trọng!" >}}
💰 **Tránh chi phí không cần thiết**  
🔒 **Bảo mật tài khoản AWS**  
🧹 **Giữ tài khoản sạch sẽ**  
⚡ **Tránh đạt service limits**  
{{< /alert >}}

## Thứ tự cleanup

{{< workshop-image src="images/cleanup-order.png" alt="Cleanup Order" caption="Thứ tự cleanup resources để tránh dependency errors" >}}

### Cleanup theo thứ tự:
1. **ECS Services và Tasks**
2. **Load Balancer và Target Groups**  
3. **ECS Cluster**
4. **NAT Gateways và Elastic IPs**
5. **VPC Components**
6. **IAM Roles và Policies**
7. **CloudWatch Resources**

## Bước 1: Cleanup ECS Resources

### 1.1 Stop ECS Services

{{< console-screenshot src="images/stop-ecs-services.png" alt="Stop ECS Services" caption="Stop và delete ECS services trước khi cleanup cluster" service="ECS Console" >}}

```bash
# Load environment
source workshop-env.sh

echo "🛑 Stopping ECS Services..."

# Scale down services to 0
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service workshop-frontend \
    --desired-count 0

aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service workshop-backend \
    --desired-count 0

echo "✅ Services scaled down to 0"
```

### 1.2 Delete ECS Services

```bash
echo "🗑️ Deleting ECS Services..."

# Chờ services scale down
aws ecs wait services-stable --cluster $CLUSTER_NAME --services workshop-frontend workshop-backend

# Delete services
aws ecs delete-service --cluster $CLUSTER_NAME --service workshop-frontend --force
aws ecs delete-service --cluster $CLUSTER_NAME --service workshop-backend --force

echo "✅ ECS Services deleted"
```

### 1.3 Delete ECS Cluster

```bash
echo "🗑️ Deleting ECS Cluster..."

# Delete cluster
aws ecs delete-cluster --cluster $CLUSTER_NAME

echo "✅ ECS Cluster deleted"
```

## Bước 2: Cleanup Load Balancer

### 2.1 Delete Load Balancer

{{< console-screenshot src="images/delete-alb.png" alt="Delete ALB" caption="Delete Application Load Balancer và associated resources" service="EC2 Console" >}}

```bash
echo "🗑️ Deleting Load Balancer..."

# Delete ALB
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN

# Chờ ALB deleted
aws elbv2 wait load-balancer-not-exists --load-balancer-arns $ALB_ARN

echo "✅ Load Balancer deleted"
```

### 2.2 Delete Target Groups

```bash
echo "🗑️ Deleting Target Groups..."

# Delete target groups
aws elbv2 delete-target-group --target-group-arn $FRONTEND_TG_ARN
aws elbv2 delete-target-group --target-group-arn $BACKEND_TG_ARN

echo "✅ Target Groups deleted"
```

## Bước 3: Cleanup VPC Resources

### 3.1 Delete NAT Gateways

{{< console-screenshot src="images/delete-nat-gateways.png" alt="Delete NAT Gateways" caption="Delete NAT Gateways và release Elastic IPs" service="VPC Console" >}}

```bash
echo "🗑️ Deleting NAT Gateways..."

# Delete NAT Gateways
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_1
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_2

# Chờ NAT Gateways deleted
aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_GW_1 $NAT_GW_2

echo "✅ NAT Gateways deleted"
```

### 3.2 Release Elastic IPs

```bash
echo "🗑️ Releasing Elastic IPs..."

# Release EIPs
aws ec2 release-address --allocation-id $EIP_1
aws ec2 release-address --allocation-id $EIP_2

echo "✅ Elastic IPs released"
```

### 3.3 Delete Route Tables

```bash
echo "🗑️ Deleting Route Tables..."

# Disassociate và delete route tables
aws ec2 delete-route-table --route-table-id $PUBLIC_RT
aws ec2 delete-route-table --route-table-id $PRIVATE_RT_1
aws ec2 delete-route-table --route-table-id $PRIVATE_RT_2

echo "✅ Route Tables deleted"
```

### 3.4 Delete Subnets

```bash
echo "🗑️ Deleting Subnets..."

# Delete subnets
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_1
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_2
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_1
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_2

echo "✅ Subnets deleted"
```

### 3.5 Delete Internet Gateway

```bash
echo "🗑️ Deleting Internet Gateway..."

# Detach và delete IGW
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID

echo "✅ Internet Gateway deleted"
```

### 3.6 Delete Security Groups

```bash
echo "🗑️ Deleting Security Groups..."

# Delete security groups
aws ec2 delete-security-group --group-id $ALB_SG
aws ec2 delete-security-group --group-id $ECS_SG

echo "✅ Security Groups deleted"
```

### 3.7 Delete VPC

```bash
echo "🗑️ Deleting VPC..."

# Delete VPC
aws ec2 delete-vpc --vpc-id $VPC_ID

echo "✅ VPC deleted"
```

## Bước 4: Cleanup IAM Resources

### 4.1 Delete IAM Roles

{{< console-screenshot src="images/delete-iam-roles.png" alt="Delete IAM Roles" caption="Delete IAM roles và policies" service="IAM Console" >}}

```bash
echo "🗑️ Deleting IAM Resources..."

# Detach policies và delete roles
aws iam detach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws iam detach-role-policy --role-name ecsTaskRole --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/ECSTaskCustomPolicy
aws iam delete-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/ECSTaskCustomPolicy

aws iam detach-role-policy --role-name flowlogsRole --policy-arn arn:aws:iam::aws:policy/service-role/VPCFlowLogsDeliveryRolePolicy

# Delete roles
aws iam delete-role --role-name ecsTaskExecutionRole
aws iam delete-role --role-name ecsTaskRole
aws iam delete-role --role-name flowlogsRole

echo "✅ IAM Resources deleted"
```

## Bước 5: Cleanup CloudWatch Resources

### 5.1 Delete Log Groups

{{< console-screenshot src="images/delete-cloudwatch.png" alt="Delete CloudWatch" caption="Delete CloudWatch logs, alarms và dashboards" service="CloudWatch Console" >}}

```bash
echo "🗑️ Deleting CloudWatch Resources..."

# Delete log groups
aws logs delete-log-group --log-group-name /ecs/workshop-frontend
aws logs delete-log-group --log-group-name /ecs/workshop-backend
aws logs delete-log-group --log-group-name /ecs/workshop-monitoring
aws logs delete-log-group --log-group-name /ecs/workshop-xray
aws logs delete-log-group --log-group-name /aws/vpc/flowlogs

echo "✅ CloudWatch Log Groups deleted"
```

### 5.2 Delete Alarms và Dashboards

```bash
# Delete alarms
aws cloudwatch delete-alarms --alarm-names "ALB-UnhealthyTargets" "ECS-HighCPU" "ECS-Service-Health-Composite"

# Delete dashboards
aws cloudwatch delete-dashboards --dashboard-names "ECS-Workshop-Dashboard" "ECS-Workshop-Advanced-Dashboard"

echo "✅ CloudWatch Alarms and Dashboards deleted"
```

## Bước 6: Cleanup Other Resources

### 6.1 Delete SNS Topic

```bash
echo "🗑️ Deleting SNS Topic..."

# Delete SNS topic
aws sns delete-topic --topic-arn $TOPIC_ARN

echo "✅ SNS Topic deleted"
```

### 6.2 Delete Secrets Manager Secret

```bash
echo "🗑️ Deleting Secrets..."

# Delete secret (với immediate deletion)
aws secretsmanager delete-secret \
    --secret-id "workshop/database/credentials" \
    --force-delete-without-recovery

echo "✅ Secrets deleted"
```

### 6.3 Delete Service Discovery

```bash
echo "🗑️ Deleting Service Discovery..."

# List và delete services trong namespace
NAMESPACE_ID=$(aws servicediscovery list-namespaces \
    --filters Name=NAME,Values=$NAMESPACE_NAME \
    --query 'Namespaces[0].Id' --output text 2>/dev/null || echo "")

if [ "$NAMESPACE_ID" != "" ] && [ "$NAMESPACE_ID" != "None" ]; then
    # Delete services trong namespace
    SERVICE_IDS=$(aws servicediscovery list-services \
        --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID \
        --query 'Services[].Id' --output text)
    
    for SERVICE_ID in $SERVICE_IDS; do
        aws servicediscovery delete-service --id $SERVICE_ID
    done
    
    # Delete namespace
    aws servicediscovery delete-namespace --id $NAMESPACE_ID
fi

echo "✅ Service Discovery cleaned up"
```

## Bước 7: Verification

### 7.1 Verify Cleanup

{{< console-screenshot src="images/cleanup-verification.png" alt="Cleanup Verification" caption="Verify tất cả resources đã được cleanup" service="AWS Console" >}}

```bash
echo "🔍 Verifying Cleanup..."

# Check VPCs
echo "Remaining VPCs:"
aws ec2 describe-vpcs --filters Name=tag:Name,Values=ECS-Workshop-VPC --query 'Vpcs[].VpcId' --output text

# Check ECS clusters
echo "Remaining ECS Clusters:"
aws ecs list-clusters --query 'clusterArns[?contains(@, `ecs-workshop`)]' --output text

# Check Load Balancers
echo "Remaining Load Balancers:"
aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `ecs-workshop`)].LoadBalancerName' --output text

# Check IAM roles
echo "Remaining IAM Roles:"
aws iam list-roles --query 'Roles[?contains(RoleName, `ecs`) || contains(RoleName, `flowlogs`)].RoleName' --output text

echo "✅ Cleanup verification completed"
```

### 7.2 Final Cleanup Script

```bash
# Tạo cleanup script để chạy lại nếu cần
cat > final-cleanup.sh << 'EOF'
#!/bin/bash
echo "🧹 Final cleanup script..."

# Remove any remaining resources
aws ecs list-clusters --query 'clusterArns[?contains(@, `workshop`)]' --output text | xargs -r -I {} aws ecs delete-cluster --cluster {}

# Clean up any remaining log groups
aws logs describe-log-groups --log-group-name-prefix "/ecs/workshop" --query 'logGroups[].logGroupName' --output text | xargs -r -I {} aws logs delete-log-group --log-group-name {}

echo "✅ Final cleanup completed"
EOF

chmod +x final-cleanup.sh
echo "✅ Final cleanup script created"
```

## Cleanup Summary

### 7.3 Resources Cleaned Up

```bash
echo "📋 Cleanup Summary:"
echo "==================="
echo "✅ ECS Services và Cluster"
echo "✅ Application Load Balancer"
echo "✅ Target Groups"
echo "✅ VPC và Networking components"
echo "✅ NAT Gateways và Elastic IPs"
echo "✅ Security Groups"
echo "✅ IAM Roles và Policies"
echo "✅ CloudWatch Logs, Alarms, Dashboards"
echo "✅ SNS Topic"
echo "✅ Secrets Manager Secret"
echo "✅ Service Discovery Namespace"
echo ""
echo "🎉 Workshop cleanup completed!"
```

{{< alert type="success" title="Cleanup hoàn tất!" >}}
🎉 **Tất cả resources đã được cleanup!**  
💰 **Không còn chi phí phát sinh**  
🔒 **Tài khoản AWS đã được dọn sạch**  
📚 **Workshop hoàn thành thành công**  
{{< /alert >}}

## Best Practices cho Cleanup

{{< alert type="tip" title="Cleanup Best Practices" >}}
🔄 **Cleanup ngay sau workshop** - Tránh quên và phát sinh chi phí  
📋 **Kiểm tra billing dashboard** - Đảm bảo không còn charges  
🏷️ **Sử dụng tags** - Dễ dàng identify resources cần cleanup  
🤖 **Automation** - Tạo cleanup scripts cho workshops  
📊 **Monitor costs** - Set up billing alerts  
{{< /alert >}}

## Kết thúc Workshop

{{< alert type="info" title="Cảm ơn bạn đã tham gia!" >}}
🎓 **Bạn đã hoàn thành ECS Advanced Networking Workshop!**  
📚 **Kiến thức đã học:** VPC, ECS, Service Discovery, Load Balancing, Security, Monitoring  
🚀 **Bước tiếp theo:** Áp dụng vào projects thực tế  
💡 **Tiếp tục học:** Explore thêm AWS services khác  
{{< /alert >}}

---

## Workshop Resources

- **GitHub Repository:** [ECS Advanced Networking Workshop](https://github.com/Binh2423/ECS_Advanced_Networking)
- **AWS Documentation:** [Amazon ECS](https://docs.aws.amazon.com/ecs/)
- **AWS Well-Architected:** [Framework](https://aws.amazon.com/architecture/well-architected/)

**Happy Learning! 🚀**

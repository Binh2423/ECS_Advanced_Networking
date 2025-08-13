---
title : "Security Groups"
date : "`r Sys.Date()`"
weight : 6
chapter : false
pre : " <b> 3.6 </b> "
---

# Tạo Security Groups

## Mục tiêu

Security Groups hoạt động như firewall ở instance level. Chúng ta sẽ tạo:
- **ALB Security Group** - Cho phép HTTP/HTTPS từ internet
- **ECS Security Group** - Cho phép traffic từ ALB và internal communication

## Kiến trúc Security

{{< mermaid >}}
graph TB
    Internet[🌐 Internet<br/>0.0.0.0/0]
    
    subgraph "ALB Security Group"
        ALB[Application Load Balancer<br/>Port 80, 443]
    end
    
    subgraph "ECS Security Group"
        ECS1[ECS Tasks<br/>Port 80, 8080]
        ECS2[ECS Tasks<br/>Port 80, 8080]
    end
    
    Internet -->|HTTP/HTTPS| ALB
    ALB -->|HTTP| ECS1
    ALB -->|HTTP| ECS2
    ECS1 <-->|All Traffic| ECS2
{{< /mermaid >}}

## Security Group Rules

### ALB Security Group Rules

| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| Inbound | TCP | 80 | 0.0.0.0/0 | HTTP from Internet |
| Inbound | TCP | 443 | 0.0.0.0/0 | HTTPS from Internet |
| Outbound | All | All | 0.0.0.0/0 | All outbound traffic |

### ECS Security Group Rules

| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| Inbound | TCP | 80 | ALB SG | HTTP from ALB |
| Inbound | TCP | 8080 | ALB SG | App port from ALB |
| Inbound | All | All | ECS SG | Internal communication |
| Outbound | All | All | 0.0.0.0/0 | All outbound traffic |

## Phương pháp 1: Sử dụng AWS Console

### Bước 1: Truy cập Security Groups Console

{{< console-interaction >}}
**📍 Vị trí:** EC2 Console → Security Groups

**Hành động:**
1. Mở AWS Console
2. Tìm kiếm "EC2"
3. Click vào **Security Groups** ở menu bên trái
4. Click **Create security group**

**📸 Screenshot cần chụp:**
- [ ] EC2 Console với Security Groups menu
- [ ] Security Groups dashboard
{{< /console-interaction >}}

### Bước 2: Tạo ALB Security Group

{{< console-interaction >}}
**📍 Vị trí:** Create security group form

**Cấu hình:**
- **Security group name:** `ecs-workshop-alb-sg`
- **Description:** `Security group for Application Load Balancer`
- **VPC:** Chọn `ECS-Workshop-VPC`

**Inbound rules:**
- Rule 1: HTTP (80) from Anywhere (0.0.0.0/0)
- Rule 2: HTTPS (443) from Anywhere (0.0.0.0/0)

**📸 Screenshot cần chụp:**
- [ ] Create security group form với ALB configuration
- [ ] Inbound rules configuration
{{< /console-interaction >}}

## Phương pháp 2: Sử dụng AWS CLI

### Tạo ALB Security Group

{{< code-block language="bash" title="Tạo ALB Security Group" description="Security group cho Application Load Balancer với HTTP/HTTPS access" >}}
# Load environment variables
source workshop-env.sh

echo "🔒 Creating ALB Security Group..."

# Tạo ALB Security Group
ALB_SG=$(aws ec2 create-security-group \
    --group-name ecs-workshop-alb-sg \
    --description "Security group for Application Load Balancer" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[
        {Key=Name,Value=ECS-Workshop-ALB-SG},
        {Key=Purpose,Value=ALB},
        {Key=Project,Value=ECS-Workshop}
    ]' \
    --query 'GroupId' \
    --output text)

echo "✅ ALB Security Group created: $ALB_SG"

# Thêm inbound rules cho ALB
echo "🔓 Adding inbound rules for ALB..."

# Allow HTTP from internet
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# Allow HTTPS from internet
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

echo "✅ ALB Security Group rules configured"
{{< /code-block >}}

### Tạo ECS Security Group

{{< code-block language="bash" title="Tạo ECS Security Group" description="Security group cho ECS tasks với access từ ALB và internal communication" >}}
echo "🔒 Creating ECS Security Group..."

# Tạo ECS Security Group
ECS_SG=$(aws ec2 create-security-group \
    --group-name ecs-workshop-ecs-sg \
    --description "Security group for ECS services" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[
        {Key=Name,Value=ECS-Workshop-ECS-SG},
        {Key=Purpose,Value=ECS},
        {Key=Project,Value=ECS-Workshop}
    ]' \
    --query 'GroupId' \
    --output text)

echo "✅ ECS Security Group created: $ECS_SG"

# Thêm inbound rules cho ECS
echo "🔓 Adding inbound rules for ECS..."

# Allow HTTP from ALB
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol tcp \
    --port 80 \
    --source-group $ALB_SG

# Allow port 8080 from ALB (for applications)
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol tcp \
    --port 8080 \
    --source-group $ALB_SG

# Allow all traffic from same security group (internal communication)
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol -1 \
    --source-group $ECS_SG

echo "✅ ECS Security Group rules configured"
{{< /code-block >}}

### Lưu Security Group IDs

{{< code-block language="bash" title="Lưu Security Group IDs" >}}
# Lưu Security Group IDs vào environment file
cat >> workshop-env.sh << EOF
export ALB_SG=$ALB_SG
export ECS_SG=$ECS_SG
EOF

echo "💾 Security Group IDs saved to workshop-env.sh"
echo "   ALB Security Group: $ALB_SG"
echo "   ECS Security Group: $ECS_SG"
{{< /code-block >}}

## Xác minh kết quả

### Kiểm tra Security Groups

{{< code-block language="bash" title="Kiểm tra Security Groups" >}}
echo "📋 Security Group Summary:"
echo "=========================="

# Function để hiển thị security group info
show_security_group() {
    local sg_id=$1
    local sg_name=$(aws ec2 describe-security-groups --group-ids $sg_id --query 'SecurityGroups[0].GroupName' --output text)
    local sg_desc=$(aws ec2 describe-security-groups --group-ids $sg_id --query 'SecurityGroups[0].Description' --output text)
    
    echo "$sg_name ($sg_id):"
    echo "  Description: $sg_desc"
    
    # Show inbound rules
    echo "  Inbound Rules:"
    aws ec2 describe-security-groups --group-ids $sg_id --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp,UserIdGroupPairs[0].GroupId]' --output text | while read line; do
        if [ -n "$line" ]; then
            echo "    ✓ $line"
        fi
    done
    echo ""
}

show_security_group $ALB_SG
show_security_group $ECS_SG
{{< /code-block >}}

### Kiểm tra trong Console

{{< console-interaction >}}
**📍 Vị trí:** EC2 Console → Security Groups

**Xác minh:**
- [ ] 2 Security Groups xuất hiện trong danh sách
- [ ] ALB SG có rules cho port 80, 443 từ 0.0.0.0/0
- [ ] ECS SG có rules từ ALB SG và self-reference
- [ ] Cả 2 SGs đều thuộc đúng VPC

**📸 Screenshot cần chụp:**
- [ ] Security Groups list
- [ ] ALB Security Group inbound rules
- [ ] ECS Security Group inbound rules
{{< /console-interaction >}}

## Test Security Groups

### Tạo script test security groups

{{< code-block language="bash" title="Test Security Groups" file="test-security-groups.sh" >}}
cat > test-security-groups.sh << 'EOF'
#!/bin/bash
source workshop-env.sh

echo "🧪 Testing Security Group Configuration..."
echo "========================================"

# Function to test security group rules
test_security_group() {
    local sg_id=$1
    local sg_name=$2
    
    echo "Testing $sg_name ($sg_id):"
    
    # Check if security group exists
    if ! aws ec2 describe-security-groups --group-ids $sg_id >/dev/null 2>&1; then
        echo "  ❌ Security group not found"
        return 1
    fi
    
    # Get security group info
    sg_info=$(aws ec2 describe-security-groups --group-ids $sg_id --query 'SecurityGroups[0]')
    vpc_id=$(echo $sg_info | jq -r '.VpcId')
    
    # Check VPC
    if [ "$vpc_id" = "$VPC_ID" ]; then
        echo "  ✅ Correct VPC: $vpc_id"
    else
        echo "  ❌ Wrong VPC: $vpc_id (expected: $VPC_ID)"
        return 1
    fi
    
    # Count inbound rules
    rule_count=$(echo $sg_info | jq '.IpPermissions | length')
    echo "  ✅ Inbound rules: $rule_count"
    
    echo ""
    return 0
}

# Test ALB Security Group
echo "1. Testing ALB Security Group..."
test_security_group $ALB_SG "ALB-Security-Group"

# Verify ALB specific rules
echo "   Checking ALB specific rules..."
alb_http=$(aws ec2 describe-security-groups --group-ids $ALB_SG --query 'SecurityGroups[0].IpPermissions[?FromPort==`80`]' --output text)
alb_https=$(aws ec2 describe-security-groups --group-ids $ALB_SG --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`]' --output text)

if [ -n "$alb_http" ]; then
    echo "   ✅ HTTP (80) rule found"
else
    echo "   ❌ HTTP (80) rule missing"
fi

if [ -n "$alb_https" ]; then
    echo "   ✅ HTTPS (443) rule found"
else
    echo "   ❌ HTTPS (443) rule missing"
fi

echo ""

# Test ECS Security Group
echo "2. Testing ECS Security Group..."
test_security_group $ECS_SG "ECS-Security-Group"

# Verify ECS specific rules
echo "   Checking ECS specific rules..."
ecs_http=$(aws ec2 describe-security-groups --group-ids $ECS_SG --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\` && UserIdGroupPairs[0].GroupId==\`$ALB_SG\`]" --output text)
ecs_self=$(aws ec2 describe-security-groups --group-ids $ECS_SG --query "SecurityGroups[0].IpPermissions[?UserIdGroupPairs[0].GroupId==\`$ECS_SG\`]" --output text)

if [ -n "$ecs_http" ]; then
    echo "   ✅ HTTP from ALB rule found"
else
    echo "   ❌ HTTP from ALB rule missing"
fi

if [ -n "$ecs_self" ]; then
    echo "   ✅ Self-reference rule found"
else
    echo "   ❌ Self-reference rule missing"
fi

echo ""
echo "✅ Security group testing completed!"
EOF

chmod +x test-security-groups.sh
./test-security-groups.sh
{{< /code-block >}}

## Advanced Security Group Configuration

### Thêm rules cho database access (optional)

{{< code-block language="bash" title="Database Security Group (Optional)" description="Nếu bạn cần database access cho ECS tasks" >}}
# Tạo Database Security Group (optional)
echo "🔒 Creating Database Security Group (optional)..."

DB_SG=$(aws ec2 create-security-group \
    --group-name ecs-workshop-db-sg \
    --description "Security group for RDS database" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[
        {Key=Name,Value=ECS-Workshop-DB-SG},
        {Key=Purpose,Value=Database},
        {Key=Project,Value=ECS-Workshop}
    ]' \
    --query 'GroupId' \
    --output text)

# Allow MySQL/Aurora access from ECS
aws ec2 authorize-security-group-ingress \
    --group-id $DB_SG \
    --protocol tcp \
    --port 3306 \
    --source-group $ECS_SG

# Allow PostgreSQL access from ECS
aws ec2 authorize-security-group-ingress \
    --group-id $DB_SG \
    --protocol tcp \
    --port 5432 \
    --source-group $ECS_SG

echo "✅ Database Security Group created: $DB_SG"
echo "export DB_SG=$DB_SG" >> workshop-env.sh
{{< /code-block >}}

## Troubleshooting

### Lỗi thường gặp

{{< alert type="warning" title="Rule Already Exists" >}}
**Lỗi:** `InvalidPermission.Duplicate: the specified rule "peer: 0.0.0.0/0, TCP, from port: 80, to port: 80, ALLOW" already exists`

**Giải pháp:**
- Rule đã tồn tại, có thể bỏ qua lỗi này
- Kiểm tra existing rules: `aws ec2 describe-security-groups --group-ids $SG_ID`
{{< /alert >}}

{{< alert type="warning" title="Invalid Group ID" >}}
**Lỗi:** `InvalidGroup.Id: The security group 'sg-xxx' does not exist`

**Giải pháp:**
- Kiểm tra Security Group ID trong environment file
- Đảm bảo Security Group đã được tạo thành công
- Kiểm tra region đang sử dụng
{{< /alert >}}

### Debug Commands

{{< code-block language="bash" title="Debug Commands" >}}
# Xem tất cả security groups trong VPC
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[*].[GroupId,GroupName,Description]' --output table

# Xem chi tiết rules của security group
aws ec2 describe-security-groups --group-ids $ALB_SG --query 'SecurityGroups[0].IpPermissions' --output json

# Kiểm tra outbound rules
aws ec2 describe-security-groups --group-ids $ECS_SG --query 'SecurityGroups[0].IpPermissionsEgress' --output table

# Test connectivity (nếu có EC2 instance)
# aws ec2 describe-security-groups --group-ids $ECS_SG --query 'SecurityGroups[0].IpPermissions[?UserIdGroupPairs[0].GroupId==`'$ALB_SG'`]'
{{< /code-block >}}

## Security Best Practices

{{< alert type="info" title="🔒 Security Best Practices" >}}
**Principle of Least Privilege:**

✅ **Specific Ports:** Chỉ mở ports cần thiết  
✅ **Source Restrictions:** Sử dụng Security Group references thay vì 0.0.0.0/0  
✅ **Regular Audits:** Review rules định kỳ  
✅ **Descriptive Names:** Sử dụng naming convention rõ ràng  
✅ **Tagging:** Tag tất cả resources để dễ quản lý  
{{< /alert >}}

## Tóm tắt

🎉 **Hoàn thành!** Bạn đã tạo thành công:

✅ ALB Security Group với HTTP/HTTPS access  
✅ ECS Security Group với ALB access và internal communication  
✅ Security Group rules đã được cấu hình đúng  
✅ Environment variables đã được lưu  

## Bước tiếp theo

Security Groups đã sẵn sàng! VPC infrastructure đã hoàn chỉnh. Tiếp theo chúng ta sẽ tạo ECS Cluster.

{{< button href="../../4-service-discovery/" >}}Tiếp theo: ECS Cluster Setup →{{< /button >}}

---

{{< alert type="success" title="🎉 VPC Infrastructure Complete!" >}}
**Chúc mừng!** Bạn đã hoàn thành việc thiết lập VPC infrastructure:

🌐 VPC với 4 subnets  
🌍 Internet Gateway và NAT Gateways  
🛣️ Route Tables đã cấu hình  
🔒 Security Groups cho ALB và ECS  

Infrastructure đã sẵn sàng cho ECS deployment!
{{< /alert >}}

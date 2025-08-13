---
title : "Security Groups"
date : "2024-08-13"
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

![Security Groups Architecture](/ECS_Advanced_Networking/images/3-cluster-setup/06-security/security-groups-architecture.png)

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

![Security Groups Dashboard](/ECS_Advanced_Networking/images/3-cluster-setup/06-security/01-security-groups-dashboard.png)

1. Mở AWS Console
2. Tìm kiếm "EC2"
3. Click vào **Security Groups** ở menu bên trái
4. Click **Create security group**

### Bước 2: Tạo ALB Security Group

![Create ALB SG Form](/ECS_Advanced_Networking/images/3-cluster-setup/06-security/02-create-alb-sg-form.png)

**Cấu hình:**
- **Security group name:** `ecs-workshop-alb-sg`
- **Description:** `Security group for Application Load Balancer`
- **VPC:** Chọn `ECS-Workshop-VPC`

![ALB SG Inbound Rules](/ECS_Advanced_Networking/images/3-cluster-setup/06-security/03-alb-sg-inbound-rules.png)

**Inbound rules:**
- Rule 1: HTTP (80) from Anywhere (0.0.0.0/0)
- Rule 2: HTTPS (443) from Anywhere (0.0.0.0/0)

### Bước 3: Tạo ECS Security Group

![Create ECS SG Form](/ECS_Advanced_Networking/images/3-cluster-setup/06-security/04-create-ecs-sg-form.png)

**Cấu hình:**
- **Security group name:** `ecs-workshop-ecs-sg`
- **Description:** `Security group for ECS services`
- **VPC:** Chọn `ECS-Workshop-VPC`

![ECS SG Inbound Rules](/ECS_Advanced_Networking/images/3-cluster-setup/06-security/05-ecs-sg-inbound-rules.png)

**Inbound rules:**
- Rule 1: HTTP (80) from ALB Security Group
- Rule 2: Port 8080 from ALB Security Group
- Rule 3: All traffic from self (ECS Security Group)

### Bước 4: Xác minh kết quả

![Security Groups List](/ECS_Advanced_Networking/images/3-cluster-setup/06-security/06-security-groups-list.png)

Cả 2 Security Groups sẽ xuất hiện trong danh sách với đúng VPC.

## Phương pháp 2: Sử dụng AWS CLI

### Tạo ALB Security Group

```bash
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
```

### Tạo ECS Security Group

```bash
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
```

### Lưu Security Group IDs

```bash
# Lưu Security Group IDs vào environment file
cat >> workshop-env.sh << EOF
export ALB_SG=$ALB_SG
export ECS_SG=$ECS_SG
EOF

echo "💾 Security Group IDs saved to workshop-env.sh"
echo "   ALB Security Group: $ALB_SG"
echo "   ECS Security Group: $ECS_SG"
```

## Xác minh kết quả

### Kiểm tra Security Groups

```bash
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
```

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

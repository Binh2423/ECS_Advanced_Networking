---
title : "Tạo Application Load Balancer"
date : "2024-08-13"
weight : 1
chapter : false
pre : " <b> 5.1 </b> "
---

# Tạo Application Load Balancer

## Mục tiêu

Tạo Application Load Balancer trong public subnets để phân phối traffic từ internet đến ECS services trong private subnets.

## Kiến trúc ALB

![ALB Detailed Architecture](/ECS_Advanced_Networking/images/5-load-balancing/01-alb/alb-detailed-architecture.png)

## Phương pháp 1: Sử dụng AWS Console

### Bước 1: Truy cập Load Balancer Console

![EC2 Load Balancers Menu](/ECS_Advanced_Networking/images/5-load-balancing/01-alb/01-ec2-load-balancers-menu.png)

1. Mở AWS Console
2. Tìm kiếm "EC2"
3. Click vào **Load Balancers** ở menu bên trái
4. Click **Create Load Balancer**

### Bước 2: Chọn Application Load Balancer

![Load Balancers Dashboard](/ECS_Advanced_Networking/images/5-load-balancing/01-alb/02-load-balancers-dashboard.png)

Trong Load Balancers dashboard, click **Create Load Balancer**.

![Choose Load Balancer Type](/ECS_Advanced_Networking/images/5-load-balancing/01-alb/03-choose-load-balancer-type.png)

- Chọn **Application Load Balancer**
- Click **Create**

### Bước 3: Cấu hình ALB Basic Settings

![ALB Basic Configuration](/ECS_Advanced_Networking/images/5-load-balancing/01-alb/04-alb-basic-configuration.png)

**Cấu hình:**
- **Name:** `ecs-workshop-alb`
- **Scheme:** Internet-facing
- **IP address type:** IPv4

### Bước 4: Network Mapping

![ALB Network Mapping](/ECS_Advanced_Networking/images/5-load-balancing/01-alb/05-alb-network-mapping.png)

**Network mapping:**
- **VPC:** Chọn `ECS-Workshop-VPC`
- **Mappings:** Chọn cả 2 public subnets
  - Public-Subnet-1 (AZ-1)
  - Public-Subnet-2 (AZ-2)

### Bước 5: Security Groups

![ALB Security Groups](/ECS_Advanced_Networking/images/5-load-balancing/01-alb/06-alb-security-groups.png)

**Security groups:**
- Chọn `ecs-workshop-alb-sg`
- Remove default security group

### Bước 6: Listeners (tạm thời để trống)

![ALB Listeners Empty](/ECS_Advanced_Networking/images/5-load-balancing/01-alb/07-alb-listeners-empty.png)

Chúng ta sẽ cấu hình listeners sau khi tạo target groups.

### Bước 7: Xác minh ALB đã tạo

![ALB Created Success](/ECS_Advanced_Networking/images/5-load-balancing/01-alb/08-alb-created-success.png)

ALB sẽ được tạo với trạng thái "Provisioning", sau đó chuyển thành "Active".

![ALB Details Page](/ECS_Advanced_Networking/images/5-load-balancing/01-alb/09-alb-details-page.png)

## Phương pháp 2: Sử dụng AWS CLI

### Chuẩn bị

```bash
# Load environment variables
source workshop-env.sh

echo "🔍 Checking prerequisites..."
echo "=========================="
echo "VPC ID: $VPC_ID"
echo "Public Subnet 1: $PUBLIC_SUBNET_1"
echo "Public Subnet 2: $PUBLIC_SUBNET_2"
echo "ALB Security Group: $ALB_SG"

# Kiểm tra tất cả variables có tồn tại
if [ -z "$VPC_ID" ] || [ -z "$PUBLIC_SUBNET_1" ] || [ -z "$PUBLIC_SUBNET_2" ] || [ -z "$ALB_SG" ]; then
    echo "❌ Missing required environment variables"
    echo "Please complete previous sections first"
    exit 1
fi

echo "✅ All prerequisites met"
```

### Tạo Application Load Balancer

```bash
echo "⚖️ Creating Application Load Balancer..."

# Tạo ALB
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name ecs-workshop-alb \
    --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 \
    --security-groups $ALB_SG \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --tags Key=Name,Value=ECS-Workshop-ALB Key=Project,Value=ECS-Workshop \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

if [ -n "$ALB_ARN" ]; then
    echo "✅ Application Load Balancer created successfully!"
    echo "📋 ALB ARN: $ALB_ARN"
else
    echo "❌ Failed to create Application Load Balancer"
    exit 1
fi

# Lấy DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "🌐 ALB DNS Name: $ALB_DNS"
```

### Chờ ALB sẵn sàng

```bash
echo "⏳ Waiting for ALB to become active..."
echo "   This may take 2-3 minutes..."

# Chờ ALB active
aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN

# Kiểm tra trạng thái
ALB_STATE=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].State.Code' \
    --output text)

if [ "$ALB_STATE" = "active" ]; then
    echo "✅ ALB is now active and ready!"
else
    echo "❌ ALB is not active. Current state: $ALB_STATE"
    exit 1
fi
```

### Lưu ALB thông tin

```bash
# Lưu ALB thông tin vào environment file
cat >> workshop-env.sh << EOF
export ALB_ARN=$ALB_ARN
export ALB_DNS=$ALB_DNS
EOF

echo "💾 ALB information saved to workshop-env.sh"
echo "   ALB ARN: $ALB_ARN"
echo "   ALB DNS: $ALB_DNS"
```

## Xác minh kết quả

### Kiểm tra bằng CLI

```bash
echo "📋 ALB Summary:"
echo "==============="

# Lấy thông tin ALB
alb_info=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0]')

# Extract thông tin
alb_name=$(echo $alb_info | jq -r '.LoadBalancerName')
alb_state=$(echo $alb_info | jq -r '.State.Code')
alb_type=$(echo $alb_info | jq -r '.Type')
alb_scheme=$(echo $alb_info | jq -r '.Scheme')
alb_vpc=$(echo $alb_info | jq -r '.VpcId')
alb_subnets=$(echo $alb_info | jq -r '.AvailabilityZones | length')

echo "Name: $alb_name"
echo "State: $alb_state"
echo "Type: $alb_type"
echo "Scheme: $alb_scheme"
echo "VPC: $alb_vpc"
echo "Subnets: $alb_subnets subnets"
echo "DNS: $ALB_DNS"

# Kiểm tra security groups
echo ""
echo "Security Groups:"
aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0].SecurityGroups' --output text | tr '\t' '\n' | while read sg; do
    sg_name=$(aws ec2 describe-security-groups --group-ids $sg --query 'SecurityGroups[0].GroupName' --output text)
    echo "  ✓ $sg ($sg_name)"
done
```

## Test ALB Connectivity

### Test DNS Resolution

```bash
echo "🧪 Testing ALB DNS resolution..."

# Test DNS resolution
if nslookup $ALB_DNS > /dev/null 2>&1; then
    echo "✅ DNS resolution successful"
    
    # Get IP addresses
    echo "ALB IP Addresses:"
    nslookup $ALB_DNS | grep "Address:" | grep -v "#" | while read line; do
        ip=$(echo $line | cut -d' ' -f2)
        echo "  ✓ $ip"
    done
else
    echo "❌ DNS resolution failed"
fi
```

### Test HTTP Connectivity (sẽ fail vì chưa có listener)

```bash
echo "🧪 Testing HTTP connectivity..."
echo "Note: This will fail because we haven't created listeners yet"

# Test HTTP connection (expected to fail)
if curl -s --connect-timeout 5 http://$ALB_DNS > /dev/null 2>&1; then
    echo "✅ HTTP connection successful"
else
    echo "⚠️ HTTP connection failed (expected - no listeners configured yet)"
fi

echo ""
echo "💡 We'll configure listeners in the next step"
```

## Troubleshooting

### Lỗi thường gặp

{{< alert type="warning" title="Subnet Not Available" >}}
**Lỗi:** `InvalidSubnet: The subnet ID 'subnet-xxx' is not valid`

**Giải pháp:**
- Kiểm tra subnet IDs trong environment file
- Đảm bảo subnets thuộc đúng VPC
- Kiểm tra region đang sử dụng
{{< /alert >}}

{{< alert type="warning" title="Security Group Not Found" >}}
**Lỗi:** `InvalidGroup.Id: The security group 'sg-xxx' does not exist`

**Giải pháp:**
- Kiểm tra ALB Security Group ID
- Đảm bảo security group đã được tạo
- Kiểm tra security group thuộc đúng VPC
{{< /alert >}}

## Tóm tắt

🎉 **Hoàn thành!** Bạn đã tạo thành công:

✅ Application Load Balancer trong public subnets  
✅ ALB đã ở trạng thái `Active`  
✅ DNS name đã được cấp phát  
✅ Security groups đã được attach  
✅ Environment variables đã được lưu  

## Bước tiếp theo

ALB đã sẵn sàng! Tiếp theo chúng ta sẽ tạo Target Groups để định nghĩa targets cho ALB.

{{< button href="../02-target-groups/" >}}Tiếp theo: Target Groups →{{< /button >}}

---

{{< alert type="info" title="💡 Tip" >}}
**DNS Propagation:** ALB DNS name có thể mất vài phút để propagate globally. Đây là behavior bình thường.
{{< /alert >}}

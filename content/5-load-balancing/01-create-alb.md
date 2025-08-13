---
title : "Tạo Application Load Balancer"
date : "`r Sys.Date()`"
weight : 1
chapter : false
pre : " <b> 5.1 </b> "
---

# Tạo Application Load Balancer

## Mục tiêu

Tạo Application Load Balancer trong public subnets để phân phối traffic từ internet đến ECS services trong private subnets.

## Kiến trúc ALB

{{< mermaid >}}
graph TB
    Internet[🌐 Internet]
    
    subgraph "VPC: 10.0.0.0/16"
        subgraph "Public Subnets"
            subgraph "AZ-1"
                ALB1[ALB Node 1<br/>10.0.1.x]
            end
            subgraph "AZ-2"
                ALB2[ALB Node 2<br/>10.0.2.x]
            end
        end
        
        subgraph "Private Subnets"
            subgraph "AZ-1"
                ECS1[ECS Tasks<br/>10.0.3.x]
            end
            subgraph "AZ-2"
                ECS2[ECS Tasks<br/>10.0.4.x]
            end
        end
    end
    
    Internet --> ALB1
    Internet --> ALB2
    ALB1 --> ECS1
    ALB1 --> ECS2
    ALB2 --> ECS1
    ALB2 --> ECS2
{{< /mermaid >}}

## Phương pháp 1: Sử dụng AWS Console

### Bước 1: Truy cập Load Balancer Console

{{< console-interaction >}}
**📍 Vị trí:** EC2 Console → Load Balancers

**Hành động:**
1. Mở AWS Console
2. Tìm kiếm "EC2"
3. Click vào **Load Balancers** ở menu bên trái
4. Click **Create Load Balancer**

**📸 Screenshot cần chụp:**
- [ ] EC2 Console với Load Balancers menu
- [ ] Load Balancers dashboard
- [ ] Create Load Balancer page với ALB option
{{< /console-interaction >}}

### Bước 2: Chọn Application Load Balancer

{{< console-interaction >}}
**📍 Vị trí:** Create Load Balancer → Choose Load Balancer Type

**Cấu hình:**
- Chọn **Application Load Balancer**
- Click **Create**

**📸 Screenshot cần chụp:**
- [ ] Load Balancer type selection với ALB highlighted
{{< /console-interaction >}}

### Bước 3: Cấu hình ALB Basic Settings

{{< console-interaction >}}
**📍 Vị trí:** Create Application Load Balancer → Basic Configuration

**Cấu hình:**
- **Name:** `ecs-workshop-alb`
- **Scheme:** Internet-facing
- **IP address type:** IPv4

**Network mapping:**
- **VPC:** Chọn `ECS-Workshop-VPC`
- **Mappings:** Chọn cả 2 public subnets
  - Public-Subnet-1 (AZ-1)
  - Public-Subnet-2 (AZ-2)

**Security groups:**
- Chọn `ecs-workshop-alb-sg`
- Remove default security group

**📸 Screenshot cần chụp:**
- [ ] Basic configuration form
- [ ] Network mapping với 2 public subnets
- [ ] Security groups selection
{{< /console-interaction >}}

## Phương pháp 2: Sử dụng AWS CLI

### Chuẩn bị

{{< code-block language="bash" title="Load Environment và Kiểm tra Prerequisites" >}}
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
{{< /code-block >}}

### Tạo Application Load Balancer

{{< code-block language="bash" title="Tạo Application Load Balancer" description="Tạo ALB trong public subnets với security group đã cấu hình" >}}
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
{{< /code-block >}}

### Chờ ALB sẵn sàng

{{< code-block language="bash" title="Chờ ALB Active" description="Chờ ALB chuyển sang trạng thái active trước khi tiếp tục" >}}
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
{{< /code-block >}}

### Lưu ALB thông tin

{{< code-block language="bash" title="Lưu ALB Information" >}}
# Lưu ALB thông tin vào environment file
cat >> workshop-env.sh << EOF
export ALB_ARN=$ALB_ARN
export ALB_DNS=$ALB_DNS
EOF

echo "💾 ALB information saved to workshop-env.sh"
echo "   ALB ARN: $ALB_ARN"
echo "   ALB DNS: $ALB_DNS"
{{< /code-block >}}

## Xác minh kết quả

### Kiểm tra ALB trong Console

{{< console-interaction >}}
**📍 Vị trí:** EC2 Console → Load Balancers

**Xác minh:**
- [ ] ALB `ecs-workshop-alb` xuất hiện trong danh sách
- [ ] State: `Active`
- [ ] Scheme: `internet-facing`
- [ ] VPC: `ECS-Workshop-VPC`
- [ ] Availability Zones: 2 AZs với public subnets

**📸 Screenshot cần chụp:**
- [ ] Load Balancers list showing new ALB
- [ ] ALB details page showing configuration
- [ ] ALB listeners tab (should be empty for now)
{{< /console-interaction >}}

### Kiểm tra bằng CLI

{{< code-block language="bash" title="Kiểm tra ALB Configuration" >}}
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
{{< /code-block >}}

## Test ALB Connectivity

### Test DNS Resolution

{{< code-block language="bash" title="Test DNS Resolution" >}}
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
{{< /code-block >}}

### Test HTTP Connectivity (sẽ fail vì chưa có listener)

{{< code-block language="bash" title="Test HTTP Connectivity" >}}
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
{{< /code-block >}}

## ALB Attributes và Tuning

### Xem ALB Attributes

{{< code-block language="bash" title="ALB Attributes" >}}
echo "⚙️ ALB Attributes:"
echo "=================="

aws elbv2 describe-load-balancer-attributes \
    --load-balancer-arn $ALB_ARN \
    --query 'Attributes[*].[Key,Value]' \
    --output table
{{< /code-block >}}

### Tùy chỉnh ALB Attributes (Optional)

{{< code-block language="bash" title="Customize ALB Attributes (Optional)" description="Tùy chỉnh các attributes của ALB để tối ưu performance" >}}
echo "⚙️ Customizing ALB attributes..."

# Enable access logs (optional - requires S3 bucket)
# aws elbv2 modify-load-balancer-attributes \
#     --load-balancer-arn $ALB_ARN \
#     --attributes Key=access_logs.s3.enabled,Value=true \
#                  Key=access_logs.s3.bucket,Value=my-alb-logs-bucket

# Enable deletion protection (recommended for production)
aws elbv2 modify-load-balancer-attributes \
    --load-balancer-arn $ALB_ARN \
    --attributes Key=deletion_protection.enabled,Value=false

# Set idle timeout (default is 60 seconds)
aws elbv2 modify-load-balancer-attributes \
    --load-balancer-arn $ALB_ARN \
    --attributes Key=idle_timeout.timeout_seconds,Value=60

echo "✅ ALB attributes configured"
{{< /code-block >}}

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

### Debug Commands

{{< code-block language="bash" title="Debug Commands" >}}
# Kiểm tra tất cả load balancers
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerName,State.Code,Type]' --output table

# Kiểm tra subnets có sẵn
aws ec2 describe-subnets --subnet-ids $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]' --output table

# Kiểm tra security group
aws ec2 describe-security-groups --group-ids $ALB_SG --query 'SecurityGroups[0].[GroupId,GroupName,VpcId]' --output table

# Xem ALB events (nếu có lỗi)
aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0].State'
{{< /code-block >}}

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

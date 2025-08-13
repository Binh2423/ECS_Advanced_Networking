---
title : "NAT Gateways"
date : "`r Sys.Date()`"
weight : 4
chapter : false
pre : " <b> 3.4 </b> "
---

# Tạo NAT Gateways

## Mục tiêu

NAT Gateways cho phép resources trong private subnets truy cập internet (outbound) mà không cho phép internet truy cập vào (inbound). Chúng ta sẽ tạo 2 NAT Gateways để đảm bảo high availability.

## Kiến trúc

{{< mermaid >}}
graph TB
    Internet[🌐 Internet]
    IGW[Internet Gateway]
    
    subgraph "VPC: 10.0.0.0/16"
        subgraph "Public Subnets"
            PUB1[Public Subnet 1<br/>10.0.1.0/24]
            PUB2[Public Subnet 2<br/>10.0.2.0/24]
        end
        
        subgraph "Private Subnets"
            PRIV1[Private Subnet 1<br/>10.0.3.0/24]
            PRIV2[Private Subnet 2<br/>10.0.4.0/24]
        end
        
        NAT1[NAT Gateway 1]
        NAT2[NAT Gateway 2]
        ECS1[ECS Tasks]
        ECS2[ECS Tasks]
    end
    
    Internet --> IGW
    IGW --> PUB1
    IGW --> PUB2
    PUB1 --> NAT1
    PUB2 --> NAT2
    NAT1 --> PRIV1
    NAT2 --> PRIV2
    PRIV1 --> ECS1
    PRIV2 --> ECS2
{{< /mermaid >}}

## Tại sao cần 2 NAT Gateways?

{{< alert type="info" title="💡 High Availability Design" >}}
**Best Practice:** Tạo 1 NAT Gateway trong mỗi AZ để:

🔄 **Fault tolerance:** Nếu 1 AZ down, AZ khác vẫn hoạt động  
⚡ **Performance:** Giảm latency bằng cách sử dụng NAT Gateway gần nhất  
💰 **Cost optimization:** Tránh cross-AZ data transfer charges  
{{< /alert >}}

## Phương pháp 1: Sử dụng AWS Console

### Bước 1: Truy cập NAT Gateways Console

{{< console-interaction >}}
**📍 Vị trí:** VPC Console → NAT Gateways

**Hành động:**
1. Trong VPC Console, click vào **NAT Gateways** ở menu bên trái
2. Click **Create NAT gateway**

**📸 Screenshot cần chụp:**
- [ ] NAT Gateways dashboard
- [ ] Create NAT gateway button
{{< /console-interaction >}}

### Bước 2: Tạo NAT Gateway 1

{{< console-interaction >}}
**📍 Vị trí:** Create NAT gateway form

**Cấu hình:**
- **Name:** `ECS-Workshop-NAT-1`
- **Subnet:** Chọn `Public-Subnet-1`
- **Connectivity type:** Public
- **Elastic IP allocation ID:** Click "Allocate Elastic IP"

**📸 Screenshot cần chụp:**
- [ ] Create NAT gateway form với thông tin đã điền
- [ ] Elastic IP allocation dialog
{{< /console-interaction >}}

### Bước 3: Tạo NAT Gateway 2

Lặp lại quá trình tương tự với:
- **Name:** `ECS-Workshop-NAT-2`
- **Subnet:** Chọn `Public-Subnet-2`

## Phương pháp 2: Sử dụng AWS CLI

### Tạo Elastic IP Addresses

```bash
# Load environment variables
source workshop-env.sh

echo "💰 Allocating Elastic IP addresses..."

# Tạo EIP cho NAT Gateway 1
EIP_1_ALLOC=$(aws ec2 allocate-address \
    --domain vpc \
    --tag-specifications 'ResourceType=elastic-ip,Tags=[
        {Key=Name,Value=ECS-Workshop-EIP-1},
        {Key=Project,Value=ECS-Workshop},
        {Key=Purpose,Value=NAT-Gateway-1}
    ]' \
    --query 'AllocationId' \
    --output text)

# Tạo EIP cho NAT Gateway 2
EIP_2_ALLOC=$(aws ec2 allocate-address \
    --domain vpc \
    --tag-specifications 'ResourceType=elastic-ip,Tags=[
        {Key=Name,Value=ECS-Workshop-EIP-2},
        {Key=Project,Value=ECS-Workshop},
        {Key=Purpose,Value=NAT-Gateway-2}
    ]' \
    --query 'AllocationId' \
    --output text)

echo "✅ Elastic IPs allocated:"
echo "   EIP 1 Allocation ID: $EIP_1_ALLOC"
echo "   EIP 2 Allocation ID: $EIP_2_ALLOC"

# Lấy public IP addresses
EIP_1_IP=$(aws ec2 describe-addresses --allocation-ids $EIP_1_ALLOC --query 'Addresses[0].PublicIp' --output text)
EIP_2_IP=$(aws ec2 describe-addresses --allocation-ids $EIP_2_ALLOC --query 'Addresses[0].PublicIp' --output text)

echo "   EIP 1 Public IP: $EIP_1_IP"
echo "   EIP 2 Public IP: $EIP_2_IP"
```

### Tạo NAT Gateways

```bash
echo "🌐 Creating NAT Gateways..."

# Tạo NAT Gateway 1 trong Public Subnet 1
NAT_GW_1=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_1 \
    --allocation-id $EIP_1_ALLOC \
    --tag-specifications 'ResourceType=nat-gateway,Tags=[
        {Key=Name,Value=ECS-Workshop-NAT-1},
        {Key=Project,Value=ECS-Workshop},
        {Key=AZ,Value=1}
    ]' \
    --query 'NatGateway.NatGatewayId' \
    --output text)

# Tạo NAT Gateway 2 trong Public Subnet 2
NAT_GW_2=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_2 \
    --allocation-id $EIP_2_ALLOC \
    --tag-specifications 'ResourceType=nat-gateway,Tags=[
        {Key=Name,Value=ECS-Workshop-NAT-2},
        {Key=Project,Value=ECS-Workshop},
        {Key=AZ,Value=2}
    ]' \
    --query 'NatGateway.NatGatewayId' \
    --output text)

echo "✅ NAT Gateways created:"
echo "   NAT Gateway 1: $NAT_GW_1 (in $PUBLIC_SUBNET_1)"
echo "   NAT Gateway 2: $NAT_GW_2 (in $PUBLIC_SUBNET_2)"
```

### Chờ NAT Gateways sẵn sàng

```bash
echo "⏳ Waiting for NAT Gateways to become available..."
echo "   This may take 2-3 minutes..."

# Chờ NAT Gateway 1
echo "   Waiting for NAT Gateway 1..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_1

# Chờ NAT Gateway 2
echo "   Waiting for NAT Gateway 2..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_2

echo "✅ All NAT Gateways are now available!"
```

### Lưu NAT Gateway IDs

```bash
# Lưu tất cả IDs vào environment file
cat >> workshop-env.sh << EOF
export EIP_1_ALLOC=$EIP_1_ALLOC
export EIP_2_ALLOC=$EIP_2_ALLOC
export EIP_1_IP=$EIP_1_IP
export EIP_2_IP=$EIP_2_IP
export NAT_GW_1=$NAT_GW_1
export NAT_GW_2=$NAT_GW_2
EOF

echo "💾 NAT Gateway IDs saved to workshop-env.sh"
```

## Xác minh kết quả

### Kiểm tra bằng CLI

```bash
# Hiển thị thông tin NAT Gateways
echo "📋 NAT Gateway Summary:"
echo "======================"

aws ec2 describe-nat-gateways \
    --nat-gateway-ids $NAT_GW_1 $NAT_GW_2 \
    --query 'NatGateways[*].[
        Tags[?Key==`Name`].Value|[0],
        NatGatewayId,
        SubnetId,
        State,
        NatGatewayAddresses[0].PublicIp
    ]' \
    --output table
```

### Kiểm tra trong Console

{{< console-interaction >}}
**📍 Vị trí:** VPC Console → NAT Gateways

**Xác minh:**
- [ ] 2 NAT Gateways xuất hiện trong danh sách
- [ ] State: `Available`
- [ ] Mỗi NAT Gateway ở public subnet khác nhau
- [ ] Mỗi NAT Gateway có Elastic IP riêng

**📸 Screenshot cần chụp:**
- [ ] NAT Gateways list showing both gateways
- [ ] NAT Gateway details showing subnet and EIP
{{< /console-interaction >}}

## Kiểm tra chi phí

### Ước tính chi phí NAT Gateway

```bash
# Tạo script tính chi phí
cat > calculate-nat-cost.sh << 'EOF'
#!/bin/bash

echo "💰 NAT Gateway Cost Estimation (ap-southeast-1):"
echo "================================================"
echo ""
echo "📊 Hourly Costs:"
echo "   NAT Gateway: $0.045/hour × 2 = $0.09/hour"
echo "   Elastic IP: $0.005/hour × 2 = $0.01/hour"
echo "   Total: $0.10/hour"
echo ""
echo "📊 Daily Costs:"
echo "   Total: $0.10 × 24 = $2.40/day"
echo ""
echo "📊 Monthly Costs (30 days):"
echo "   Total: $2.40 × 30 = $72.00/month"
echo ""
echo "⚠️  Note: Data processing charges apply separately"
echo "   First 1GB/month: Free"
echo "   Next 9TB/month: $0.045/GB"
echo ""
echo "💡 Cost Optimization Tips:"
echo "   - Delete NAT Gateways when not in use"
echo "   - Use VPC Endpoints for AWS services"
echo "   - Monitor data transfer usage"
EOF

chmod +x calculate-nat-cost.sh
./calculate-nat-cost.sh
```

## Test kết nối

### Tạo script kiểm tra

```bash
# Tạo script kiểm tra NAT Gateways
cat > check-nat-gateways.sh << 'EOF'
#!/bin/bash
source workshop-env.sh

echo "🔍 Checking NAT Gateway configuration..."

# Function to check NAT Gateway
check_nat_gateway() {
    local nat_id=$1
    local nat_name=$2
    
    echo "Checking $nat_name ($nat_id):"
    
    # Get NAT Gateway info
    nat_info=$(aws ec2 describe-nat-gateways --nat-gateway-ids $nat_id --query 'NatGateways[0]')
    
    state=$(echo $nat_info | jq -r '.State')
    subnet_id=$(echo $nat_info | jq -r '.SubnetId')
    public_ip=$(echo $nat_info | jq -r '.NatGatewayAddresses[0].PublicIp')
    
    echo "  ✓ State: $state"
    echo "  ✓ Subnet: $subnet_id"
    echo "  ✓ Public IP: $public_ip"
    
    if [ "$state" = "available" ]; then
        echo "  ✅ NAT Gateway is ready!"
    else
        echo "  ❌ NAT Gateway is not ready (State: $state)"
    fi
    echo ""
}

# Check both NAT Gateways
check_nat_gateway $NAT_GW_1 "NAT-Gateway-1"
check_nat_gateway $NAT_GW_2 "NAT-Gateway-2"

echo "✅ NAT Gateway check completed!"
EOF

chmod +x check-nat-gateways.sh
./check-nat-gateways.sh
```

## Troubleshooting

### Lỗi thường gặp

{{< alert type="warning" title="Insufficient Elastic IP Addresses" >}}
**Lỗi:** `AddressLimitExceeded: The maximum number of addresses has been reached`

**Giải pháp:**
- Kiểm tra Elastic IP limit trong region
- Release các EIP không sử dụng
- Request limit increase nếu cần
{{< /alert >}}

{{< alert type="warning" title="NAT Gateway Creation Failed" >}}
**Lỗi:** `InvalidSubnetID.NotFound: The subnet ID 'subnet-xxx' does not exist`

**Giải pháp:**
- Kiểm tra subnet IDs trong environment file
- Đảm bảo public subnets đã được tạo
- Kiểm tra region đang sử dụng
{{< /alert >}}

### Debug commands

```bash
# Kiểm tra tất cả NAT Gateways
aws ec2 describe-nat-gateways --query 'NatGateways[*].[NatGatewayId,State,SubnetId]' --output table

# Kiểm tra Elastic IPs
aws ec2 describe-addresses --allocation-ids $EIP_1_ALLOC $EIP_2_ALLOC --query 'Addresses[*].[AllocationId,PublicIp,AssociationId]' --output table

# Kiểm tra subnet tồn tại
aws ec2 describe-subnets --subnet-ids $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]' --output table
```

## Tóm tắt

🎉 **Hoàn thành!** Bạn đã tạo thành công:

✅ 2 Elastic IP addresses  
✅ 2 NAT Gateways trong 2 AZs khác nhau  
✅ NAT Gateways đã ở trạng thái `Available`  
✅ Environment variables đã được lưu  

## Bước tiếp theo

NAT Gateways đã sẵn sàng! Tiếp theo chúng ta sẽ tạo Route Tables để định tuyến traffic.

{{< button href="../05-route-tables/" >}}Tiếp theo: Route Tables →{{< /button >}}

---

{{< alert type="warning" title="💰 Chi phí" >}}
**Lưu ý:** NAT Gateways có chi phí ~$2.40/ngày. Nhớ cleanup sau khi hoàn thành workshop để tránh chi phí không cần thiết!
{{< /alert >}}

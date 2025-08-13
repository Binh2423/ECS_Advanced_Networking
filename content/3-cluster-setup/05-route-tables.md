---
title : "Route Tables"
date : "`r Sys.Date()`"
weight : 5
chapter : false
pre : " <b> 3.5 </b> "
---

# Tạo Route Tables

## Mục tiêu

Route Tables định tuyến traffic trong VPC. Chúng ta sẽ tạo:
- **1 Public Route Table** - Route traffic từ public subnets ra internet qua IGW
- **2 Private Route Tables** - Route traffic từ private subnets ra internet qua NAT Gateways

## Kiến trúc Routing

{{< mermaid >}}
graph TB
    subgraph "VPC: 10.0.0.0/16"
        subgraph "Public Route Table"
            PRT[Public RT<br/>0.0.0.0/0 → IGW]
        end
        
        subgraph "Private Route Tables"
            PRT1[Private RT 1<br/>0.0.0.0/0 → NAT GW 1]
            PRT2[Private RT 2<br/>0.0.0.0/0 → NAT GW 2]
        end
        
        PUB1[Public Subnet 1] --> PRT
        PUB2[Public Subnet 2] --> PRT
        PRIV1[Private Subnet 1] --> PRT1
        PRIV2[Private Subnet 2] --> PRT2
    end
    
    PRT --> IGW[Internet Gateway]
    PRT1 --> NAT1[NAT Gateway 1]
    PRT2 --> NAT2[NAT Gateway 2]
{{< /mermaid >}}

## Phương pháp 1: Sử dụng AWS Console

### Bước 1: Truy cập Route Tables Console

{{< console-interaction >}}
**📍 Vị trí:** VPC Console → Route Tables

**Hành động:**
1. Trong VPC Console, click vào **Route Tables** ở menu bên trái
2. Click **Create route table**

**📸 Screenshot cần chụp:**
- [ ] Route Tables dashboard
- [ ] Create route table button
{{< /console-interaction >}}

### Bước 2: Tạo Public Route Table

{{< console-interaction >}}
**📍 Vị trí:** Create route table form

**Cấu hình:**
- **Name:** `Public-Route-Table`
- **VPC:** Chọn `ECS-Workshop-VPC`

**Hành động sau khi tạo:**
1. Select route table vừa tạo
2. Tab **Routes** → **Edit routes**
3. **Add route:** `0.0.0.0/0` → Target: Internet Gateway → Chọn IGW
4. Tab **Subnet associations** → **Edit subnet associations**
5. Chọn cả 2 public subnets

**📸 Screenshot cần chụp:**
- [ ] Create route table form
- [ ] Routes configuration với IGW
- [ ] Subnet associations với public subnets
{{< /console-interaction >}}

## Phương pháp 2: Sử dụng AWS CLI

### Tạo Public Route Table

{{< code-block language="bash" title="Tạo Public Route Table" description="Route table cho public subnets với route tới Internet Gateway" >}}
# Load environment variables
source workshop-env.sh

echo "🛣️ Creating Public Route Table..."

# Tạo Public Route Table
PUBLIC_RT=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[
        {Key=Name,Value=Public-Route-Table},
        {Key=Type,Value=Public},
        {Key=Project,Value=ECS-Workshop}
    ]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

echo "✅ Public Route Table created: $PUBLIC_RT"

# Thêm route tới Internet Gateway
aws ec2 create-route \
    --route-table-id $PUBLIC_RT \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

echo "✅ Route to Internet Gateway added"

# Associate với public subnets
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_1 --route-table-id $PUBLIC_RT
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_2 --route-table-id $PUBLIC_RT

echo "✅ Public subnets associated with Public Route Table"
{{< /code-block >}}

### Tạo Private Route Tables

{{< code-block language="bash" title="Tạo Private Route Tables" description="Route tables cho private subnets với routes tới NAT Gateways" >}}
echo "🛣️ Creating Private Route Tables..."

# Private Route Table 1 (cho Private Subnet 1)
PRIVATE_RT_1=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[
        {Key=Name,Value=Private-Route-Table-1},
        {Key=Type,Value=Private},
        {Key=AZ,Value=1},
        {Key=Project,Value=ECS-Workshop}
    ]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Route tới NAT Gateway 1
aws ec2 create-route \
    --route-table-id $PRIVATE_RT_1 \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_1

# Associate với Private Subnet 1
aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_1 --route-table-id $PRIVATE_RT_1

echo "✅ Private Route Table 1 created and configured: $PRIVATE_RT_1"

# Private Route Table 2 (cho Private Subnet 2)
PRIVATE_RT_2=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[
        {Key=Name,Value=Private-Route-Table-2},
        {Key=Type,Value=Private},
        {Key=AZ,Value=2},
        {Key=Project,Value=ECS-Workshop}
    ]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Route tới NAT Gateway 2
aws ec2 create-route \
    --route-table-id $PRIVATE_RT_2 \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_2

# Associate với Private Subnet 2
aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_2 --route-table-id $PRIVATE_RT_2

echo "✅ Private Route Table 2 created and configured: $PRIVATE_RT_2"
{{< /code-block >}}

### Lưu Route Table IDs

{{< code-block language="bash" title="Lưu Route Table IDs" >}}
# Lưu Route Table IDs vào environment file
cat >> workshop-env.sh << EOF
export PUBLIC_RT=$PUBLIC_RT
export PRIVATE_RT_1=$PRIVATE_RT_1
export PRIVATE_RT_2=$PRIVATE_RT_2
EOF

echo "💾 Route Table IDs saved to workshop-env.sh"
{{< /code-block >}}

## Xác minh kết quả

### Kiểm tra Route Tables

{{< code-block language="bash" title="Kiểm tra Route Tables" >}}
echo "📋 Route Table Summary:"
echo "======================"

# Function để hiển thị route table info
show_route_table() {
    local rt_id=$1
    local rt_name=$(aws ec2 describe-route-tables --route-table-ids $rt_id --query 'RouteTables[0].Tags[?Key==`Name`].Value|[0]' --output text)
    local routes=$(aws ec2 describe-route-tables --route-table-ids $rt_id --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].[DestinationCidrBlock,GatewayId,NatGatewayId]' --output text)
    
    echo "$rt_name ($rt_id):"
    if [[ $routes == *"igw-"* ]]; then
        echo "  ✓ Route: 0.0.0.0/0 → Internet Gateway"
    elif [[ $routes == *"nat-"* ]]; then
        echo "  ✓ Route: 0.0.0.0/0 → NAT Gateway"
    fi
    echo ""
}

show_route_table $PUBLIC_RT
show_route_table $PRIVATE_RT_1
show_route_table $PRIVATE_RT_2
{{< /code-block >}}

### Kiểm tra Subnet Associations

{{< code-block language="bash" title="Kiểm tra Subnet Associations" >}}
echo "🔗 Subnet Associations:"
echo "======================="

# Kiểm tra associations cho từng route table
check_associations() {
    local rt_id=$1
    local rt_name=$(aws ec2 describe-route-tables --route-table-ids $rt_id --query 'RouteTables[0].Tags[?Key==`Name`].Value|[0]' --output text)
    
    echo "$rt_name:"
    aws ec2 describe-route-tables --route-table-ids $rt_id --query 'RouteTables[0].Associations[?SubnetId!=null].[SubnetId]' --output text | while read subnet_id; do
        if [ -n "$subnet_id" ]; then
            subnet_name=$(aws ec2 describe-subnets --subnet-ids $subnet_id --query 'Subnets[0].Tags[?Key==`Name`].Value|[0]' --output text)
            echo "  ✓ $subnet_name ($subnet_id)"
        fi
    done
    echo ""
}

check_associations $PUBLIC_RT
check_associations $PRIVATE_RT_1
check_associations $PRIVATE_RT_2
{{< /code-block >}}

## Test Routing

### Tạo script test routing

{{< code-block language="bash" title="Test Routing Script" file="test-routing.sh" >}}
cat > test-routing.sh << 'EOF'
#!/bin/bash
source workshop-env.sh

echo "🧪 Testing Route Table Configuration..."
echo "======================================"

# Function to test route table
test_route_table() {
    local rt_id=$1
    local rt_name=$2
    local expected_target=$3
    
    echo "Testing $rt_name ($rt_id):"
    
    # Get route information
    route_info=$(aws ec2 describe-route-tables --route-table-ids $rt_id --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`]' --output json)
    
    if [ "$route_info" = "[]" ]; then
        echo "  ❌ No default route found"
        return 1
    fi
    
    # Check target
    if echo "$route_info" | grep -q "$expected_target"; then
        echo "  ✅ Default route correctly points to $expected_target"
    else
        echo "  ❌ Default route does not point to expected target"
        echo "  Route info: $route_info"
        return 1
    fi
    
    # Check associations
    associations=$(aws ec2 describe-route-tables --route-table-ids $rt_id --query 'RouteTables[0].Associations[?SubnetId!=null].SubnetId' --output text)
    if [ -n "$associations" ]; then
        echo "  ✅ Subnets associated: $(echo $associations | wc -w) subnet(s)"
    else
        echo "  ❌ No subnets associated"
        return 1
    fi
    
    echo ""
    return 0
}

# Test all route tables
echo "1. Testing Public Route Table..."
test_route_table $PUBLIC_RT "Public-Route-Table" "igw-"

echo "2. Testing Private Route Table 1..."
test_route_table $PRIVATE_RT_1 "Private-Route-Table-1" "nat-"

echo "3. Testing Private Route Table 2..."
test_route_table $PRIVATE_RT_2 "Private-Route-Table-2" "nat-"

echo "✅ Route table testing completed!"
EOF

chmod +x test-routing.sh
./test-routing.sh
{{< /code-block >}}

## Troubleshooting

### Lỗi thường gặp

{{< alert type="warning" title="Route Already Exists" >}}
**Lỗi:** `RouteAlreadyExists: The route identified by 0.0.0.0/0 already exists`

**Giải pháp:**
- Route đã tồn tại, có thể bỏ qua lỗi này
- Kiểm tra routes hiện tại: `aws ec2 describe-route-tables --route-table-ids $RT_ID`
- Xóa route cũ nếu cần: `aws ec2 delete-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0`
{{< /alert >}}

{{< alert type="warning" title="Association Already Exists" >}}
**Lỗi:** `Resource.AlreadyAssociated: resource subnet-xxx is already associated with route table rtb-xxx`

**Giải pháp:**
- Subnet đã được associate với route table khác
- Kiểm tra current association: `aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$SUBNET_ID"`
- Disassociate trước khi associate mới
{{< /alert >}}

### Debug Commands

{{< code-block language="bash" title="Debug Commands" >}}
# Xem tất cả route tables trong VPC
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[*].[RouteTableId,Tags[?Key==`Name`].Value|[0]]' --output table

# Xem routes của một route table
aws ec2 describe-route-tables --route-table-ids $PUBLIC_RT --query 'RouteTables[0].Routes' --output table

# Xem subnet associations
aws ec2 describe-route-tables --route-table-ids $PUBLIC_RT --query 'RouteTables[0].Associations' --output table

# Kiểm tra NAT Gateway status
aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_1 $NAT_GW_2 --query 'NatGateways[*].[NatGatewayId,State]' --output table
{{< /code-block >}}

## Hiểu về Route Tables

{{< alert type="info" title="💡 Route Tables Best Practices" >}}
**Tại sao tách riêng Private Route Tables?**

🔄 **Fault Isolation:** Nếu 1 NAT Gateway fail, chỉ 1 AZ bị ảnh hưởng  
💰 **Cost Optimization:** Tránh cross-AZ data transfer charges  
⚡ **Performance:** Traffic đi qua NAT Gateway gần nhất  
🔒 **Security:** Có thể apply different routing policies per AZ  
{{< /alert >}}

## Tóm tắt

🎉 **Hoàn thành!** Bạn đã tạo thành công:

✅ 1 Public Route Table với route tới Internet Gateway  
✅ 2 Private Route Tables với routes tới NAT Gateways  
✅ Subnet associations đã được cấu hình đúng  
✅ Environment variables đã được lưu  

## Bước tiếp theo

Route Tables đã sẵn sàng! Tiếp theo chúng ta sẽ tạo Security Groups.

{{< button href="../06-security-groups/" >}}Tiếp theo: Security Groups →{{< /button >}}

---

{{< alert type="tip" title="💡 Tip" >}}
**Monitoring:** Sử dụng VPC Flow Logs để monitor traffic routing và troubleshoot connectivity issues.
{{< /alert >}}

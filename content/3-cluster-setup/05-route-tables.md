---
title : "Route Tables"
date : "2024-08-13"
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

![Route Tables Architecture]({{ "images/3-cluster-setup/05-routes/route-tables-architecture.png" | absURL }})

## Phương pháp 1: Sử dụng AWS Console

### Bước 1: Truy cập Route Tables Console

![Route Tables Dashboard]({{ "images/3-cluster-setup/05-routes/01-route-tables-dashboard.png" | absURL }})

1. Trong VPC Console, click vào **Route Tables** ở menu bên trái
2. Click **Create route table**

### Bước 2: Tạo Public Route Table

![Create Route Table Form]({{ "images/3-cluster-setup/05-routes/02-create-route-table-form.png" | absURL }})

**Cấu hình:**
- **Name:** `Public-Route-Table`
- **VPC:** Chọn `ECS-Workshop-VPC`

### Bước 3: Cấu hình Routes

![Edit Routes Dialog]({{ "images/3-cluster-setup/05-routes/03-edit-routes-dialog.png" | absURL }})

**Hành động sau khi tạo:**
1. Select route table vừa tạo
2. Tab **Routes** → **Edit routes**
3. **Add route:** `0.0.0.0/0` → Target: Internet Gateway → Chọn IGW
4. Tab **Subnet associations** → **Edit subnet associations**
5. Chọn cả 2 public subnets

### Bước 4: Xác minh kết quả

![Route Tables Complete]({{ "images/3-cluster-setup/05-routes/05-route-tables-complete.png" | absURL }})

Tất cả route tables sẽ được cấu hình với đúng routes và subnet associations.

## Phương pháp 2: Sử dụng AWS CLI

### Tạo Public Route Table

```bash
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
```

### Tạo Private Route Tables

```bash
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
```

### Lưu Route Table IDs

```bash
# Lưu Route Table IDs vào environment file
cat >> workshop-env.sh << EOF
export PUBLIC_RT=$PUBLIC_RT
export PRIVATE_RT_1=$PRIVATE_RT_1
export PRIVATE_RT_2=$PRIVATE_RT_2
EOF

echo "💾 Route Table IDs saved to workshop-env.sh"
```

## Xác minh kết quả

### Kiểm tra Route Tables

```bash
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
```

### Kiểm tra Subnet Associations

```bash
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
```

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

---
title : "Internet Gateway"
date : "`r Sys.Date()`"
weight : 3
chapter : false
pre : " <b> 3.3 </b> "
---

# Tạo Internet Gateway

## Mục tiêu

Internet Gateway (IGW) cung cấp kết nối internet cho VPC. Chúng ta sẽ tạo IGW và attach nó vào VPC để cho phép public subnets truy cập internet.

## Kiến trúc

{{< mermaid >}}
graph TB
    Internet[🌐 Internet]
    IGW[Internet Gateway]
    VPC[VPC: 10.0.0.0/16]
    
    subgraph "Public Subnets"
        PUB1[Public Subnet 1<br/>10.0.1.0/24]
        PUB2[Public Subnet 2<br/>10.0.2.0/24]
    end
    
    Internet --> IGW
    IGW --> VPC
    VPC --> PUB1
    VPC --> PUB2
{{< /mermaid >}}

## Phương pháp 1: Sử dụng AWS Console

### Bước 1: Truy cập Internet Gateways Console

{{< console-interaction >}}
**📍 Vị trí:** VPC Console → Internet Gateways

**Hành động:**
1. Trong VPC Console, click vào **Internet Gateways** ở menu bên trái
2. Click **Create internet gateway**

**📸 Screenshot cần chụp:**
- [ ] Internet Gateways dashboard
- [ ] Create internet gateway button
{{< /console-interaction >}}

### Bước 2: Tạo Internet Gateway

{{< console-interaction >}}
**📍 Vị trí:** Create internet gateway form

**Cấu hình:**
- **Name tag:** `ECS-Workshop-IGW`

**Hành động:**
1. Nhập name tag
2. Click **Create internet gateway**

**📸 Screenshot cần chụp:**
- [ ] Create internet gateway form
- [ ] Success message sau khi tạo
{{< /console-interaction >}}

### Bước 3: Attach Internet Gateway vào VPC

{{< console-interaction >}}
**📍 Vị trí:** Internet Gateway details page

**Hành động:**
1. Sau khi tạo IGW, click **Actions** → **Attach to VPC**
2. Chọn VPC `ECS-Workshop-VPC`
3. Click **Attach internet gateway**

**📸 Screenshot cần chụp:**
- [ ] Attach to VPC dialog
- [ ] IGW state thay đổi từ "Detached" thành "Attached"
{{< /console-interaction >}}

## Phương pháp 2: Sử dụng AWS CLI

### Tạo Internet Gateway

```bash
# Load environment variables
source workshop-env.sh

echo "🌐 Creating Internet Gateway..."

# Tạo Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[
        {Key=Name,Value=ECS-Workshop-IGW},
        {Key=Project,Value=ECS-Workshop}
    ]' \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

if [ -n "$IGW_ID" ]; then
    echo "✅ Internet Gateway created successfully!"
    echo "📋 IGW ID: $IGW_ID"
else
    echo "❌ Failed to create Internet Gateway"
    exit 1
fi
```

### Attach Internet Gateway vào VPC

```bash
echo "🔗 Attaching Internet Gateway to VPC..."

# Attach IGW to VPC
aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID

# Kiểm tra attachment
attachment_state=$(aws ec2 describe-internet-gateways \
    --internet-gateway-ids $IGW_ID \
    --query 'InternetGateways[0].Attachments[0].State' \
    --output text)

if [ "$attachment_state" = "attached" ]; then
    echo "✅ Internet Gateway attached successfully!"
    echo "🔗 State: $attachment_state"
else
    echo "❌ Failed to attach Internet Gateway"
    exit 1
fi
```

### Lưu IGW ID

```bash
# Lưu IGW ID vào environment file
echo "export IGW_ID=$IGW_ID" >> workshop-env.sh

echo "💾 IGW ID saved to workshop-env.sh"
```

## Xác minh kết quả

### Kiểm tra bằng CLI

```bash
# Hiển thị thông tin Internet Gateway
echo "📋 Internet Gateway Summary:"
echo "============================"

aws ec2 describe-internet-gateways \
    --internet-gateway-ids $IGW_ID \
    --query 'InternetGateways[0].[
        InternetGatewayId,
        Tags[?Key==`Name`].Value|[0],
        Attachments[0].VpcId,
        Attachments[0].State
    ]' \
    --output table
```

### Kiểm tra trong Console

{{< console-interaction >}}
**📍 Vị trí:** VPC Console → Internet Gateways

**Xác minh:**
- [ ] IGW `ECS-Workshop-IGW` xuất hiện trong danh sách
- [ ] State: `Attached`
- [ ] VPC ID khớp với VPC của workshop

**📸 Screenshot cần chụp:**
- [ ] Internet Gateways list showing attached IGW
- [ ] IGW details page showing VPC attachment
{{< /console-interaction >}}

## Test kết nối

### Tạo script kiểm tra

```bash
# Tạo script kiểm tra IGW
cat > check-igw.sh << 'EOF'
#!/bin/bash
source workshop-env.sh

echo "🔍 Checking Internet Gateway configuration..."

# Get IGW info
igw_info=$(aws ec2 describe-internet-gateways --internet-gateway-ids $IGW_ID)

# Extract information
igw_name=$(echo $igw_info | jq -r '.InternetGateways[0].Tags[]? | select(.Key=="Name") | .Value')
attachment_vpc=$(echo $igw_info | jq -r '.InternetGateways[0].Attachments[0].VpcId')
attachment_state=$(echo $igw_info | jq -r '.InternetGateways[0].Attachments[0].State')

echo "Internet Gateway Details:"
echo "========================"
echo "  ✓ Name: $igw_name"
echo "  ✓ IGW ID: $IGW_ID"
echo "  ✓ Attached VPC: $attachment_vpc"
echo "  ✓ State: $attachment_state"

# Verify VPC match
if [ "$attachment_vpc" = "$VPC_ID" ]; then
    echo "  ✅ VPC attachment verified!"
else
    echo "  ❌ VPC mismatch!"
    exit 1
fi

# Check if attached
if [ "$attachment_state" = "attached" ]; then
    echo "  ✅ IGW is properly attached!"
else
    echo "  ❌ IGW is not attached!"
    exit 1
fi

echo ""
echo "✅ Internet Gateway is ready for use!"
EOF

chmod +x check-igw.sh
./check-igw.sh
```

## Hiểu về Internet Gateway

### Cách hoạt động

{{< alert type="info" title="💡 Cách Internet Gateway hoạt động" >}}
**Internet Gateway** là một thành phần VPC cho phép giao tiếp giữa VPC và internet:

🔄 **Bidirectional:** Cho phép traffic vào và ra  
🌐 **Public IP mapping:** Map private IP thành public IP  
⚡ **Highly available:** Tự động scale và redundant  
🆓 **No cost:** Không tính phí sử dụng  
{{< /alert >}}

### Route Tables

Lưu ý rằng chỉ tạo IGW thôi chưa đủ. Chúng ta cần:
1. ✅ **Internet Gateway** (đã tạo)
2. ⏳ **Route Tables** (sẽ tạo ở bước tiếp theo)
3. ⏳ **Routes** pointing to IGW (sẽ tạo ở bước tiếp theo)

## Troubleshooting

### Lỗi thường gặp

{{< alert type="warning" title="Already Attached" >}}
**Lỗi:** `Resource.AlreadyAssociated: resource igw-xxx is already attached to network vpc-xxx`

**Giải pháp:**
- IGW đã được attach rồi, có thể bỏ qua lỗi này
- Kiểm tra attachment state bằng `describe-internet-gateways`
{{< /alert >}}

{{< alert type="warning" title="VPC Not Found" >}}
**Lỗi:** `InvalidVpcID.NotFound: The vpc ID 'vpc-xxx' does not exist`

**Giải pháp:**
- Kiểm tra VPC_ID trong environment file
- Đảm bảo VPC đã được tạo thành công
- Kiểm tra region đang sử dụng
{{< /alert >}}

### Debug commands

```bash
# Kiểm tra tất cả IGWs trong region
aws ec2 describe-internet-gateways --query 'InternetGateways[*].[InternetGatewayId,Attachments[0].VpcId,Attachments[0].State]' --output table

# Kiểm tra VPC có tồn tại không
aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].VpcId' --output text
```

## Tóm tắt

🎉 **Hoàn thành!** Bạn đã tạo thành công:

✅ Internet Gateway với tên `ECS-Workshop-IGW`  
✅ IGW đã được attach vào VPC  
✅ Environment variable `IGW_ID` đã được lưu  
✅ Kết nối internet đã sẵn sàng cho public subnets  

## Bước tiếp theo

Internet Gateway đã sẵn sàng! Tiếp theo chúng ta sẽ tạo NAT Gateways cho private subnets.

{{< button href="../04-nat-gateways/" >}}Tiếp theo: NAT Gateways →{{< /button >}}

---

{{< alert type="info" title="💡 Tip" >}}
**Security:** Internet Gateway chỉ cho phép traffic từ resources có public IP. Private subnets vẫn cần NAT Gateway để truy cập internet.
{{< /alert >}}

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

![Internet Gateway Architecture](images/3-cluster-setup/03-igw/internet-gateway-architecture.png)

## Phương pháp 1: Sử dụng AWS Console

### Bước 1: Truy cập Internet Gateways Console

![IGW Dashboard](images/3-cluster-setup/03-igw/01-igw-dashboard.png)

1. Trong VPC Console, click vào **Internet Gateways** ở menu bên trái
2. Click **Create internet gateway**

### Bước 2: Tạo Internet Gateway

![Create IGW Form](images/3-cluster-setup/03-igw/02-create-igw-form.png)

**Cấu hình:**
- **Name tag:** `ECS-Workshop-IGW`

### Bước 3: Xác minh IGW đã tạo

![IGW Created](images/3-cluster-setup/03-igw/03-igw-created.png)

Internet Gateway sẽ được tạo với trạng thái "Detached".

### Bước 4: Attach Internet Gateway vào VPC

![Attach IGW Dialog](images/3-cluster-setup/03-igw/04-attach-igw-dialog.png)

1. Click **Actions** → **Attach to VPC**
2. Chọn VPC `ECS-Workshop-VPC`
3. Click **Attach internet gateway**

![IGW Attached](images/3-cluster-setup/03-igw/05-igw-attached.png)

IGW sẽ chuyển sang trạng thái "Attached".

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

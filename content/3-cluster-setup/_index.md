---
title : "Thiết lập VPC và Networking"
date : "2024-08-13"
weight : 3
chapter : true
pre : " <b> 3. </b> "
---

# Thiết lập VPC và Networking

## Tổng quan kiến trúc

Trong phần này, chúng ta sẽ xây dựng một VPC hoàn chỉnh với tất cả các thành phần networking cần thiết cho ECS cluster.

![VPC Architecture](images/3-cluster-setup/vpc-architecture-overview.png)

### Những gì chúng ta sẽ tạo:

🌐 **VPC** (10.0.0.0/16) - Virtual Private Cloud chính  
🏢 **4 Subnets** - 2 public + 2 private across 2 AZs  
🌍 **Internet Gateway** - Kết nối internet cho public subnets  
🔄 **2 NAT Gateways** - Internet access cho private subnets  
🔒 **Security Groups** - Firewall rules cho ALB và ECS  
📋 **Route Tables** - Định tuyến traffic  

## Cấu trúc bài học

Phần này được chia thành các bước nhỏ để dễ theo dõi:

{{< children style="card" depth="1" description="true" >}}

## Thời gian ước tính

⏱️ **Tổng thời gian:** 30-45 phút  
📊 **Độ khó:** Trung bình  
💰 **Chi phí:** ~$2-5/ngày (chủ yếu từ NAT Gateways)  

## Yêu cầu trước khi bắt đầu

✅ AWS CLI đã được cấu hình  
✅ Quyền IAM đầy đủ cho VPC, EC2  
✅ Terminal/Command prompt  
✅ Text editor để lưu environment variables  

{{< alert type="info" title="Lưu ý quan trọng" >}}
🔧 **Environment Variables**: Chúng ta sẽ sử dụng file `workshop-env.sh` để lưu trữ các IDs và ARNs. Hãy đảm bảo source file này trước mỗi session mới.

```bash
# Tạo file environment
touch workshop-env.sh
chmod +x workshop-env.sh
```
{{< /alert >}}

## Bắt đầu

Sẵn sàng tạo VPC infrastructure? Hãy bắt đầu với việc tạo VPC!

{{< button href="./01-create-vpc/" >}}Bắt đầu: Tạo VPC →{{< /button >}}

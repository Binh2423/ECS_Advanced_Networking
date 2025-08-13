---
title : "Load Balancing và ALB"
date : "2024-08-13"
weight : 5
chapter : true
pre : " <b> 5. </b> "
---

# Load Balancing và Application Load Balancer

## Tổng quan

Application Load Balancer (ALB) là thành phần quan trọng trong kiến trúc ECS, phân phối traffic đến các ECS tasks và cung cấp high availability cho ứng dụng.

![ALB Architecture Overview](/ECS_Advanced_Networking/images/5-load-balancing/alb-architecture-overview.png)

### Những gì chúng ta sẽ tạo:

⚖️ **Application Load Balancer** - Layer 7 load balancer  
🎯 **Target Groups** - Nhóm targets cho ECS services  
🔍 **Health Checks** - Monitor service health  
🌐 **Listener Rules** - Route traffic based on rules  
📊 **CloudWatch Integration** - Monitoring và logging  

## Cấu trúc bài học

{{< children style="card" depth="1" description="true" >}}

## Thời gian ước tính

⏱️ **Tổng thời gian:** 45-60 phút  
📊 **Độ khó:** Trung bình  
💰 **Chi phí:** ~$0.50-1.00/ngày  

## Yêu cầu trước khi bắt đầu

✅ VPC infrastructure đã hoàn thành  
✅ Security Groups đã được tạo  
✅ ECS Cluster đã sẵn sàng  
✅ Environment variables đã được load  

{{< alert type="info" title="Kiểm tra Prerequisites" >}}
Trước khi bắt đầu, hãy đảm bảo bạn có các resources sau:

```bash
source workshop-env.sh

# Kiểm tra required variables
echo "VPC ID: $VPC_ID"
echo "Public Subnets: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"
echo "ALB Security Group: $ALB_SG"
echo "ECS Security Group: $ECS_SG"
```

Nếu bất kỳ variable nào bị thiếu, hãy quay lại phần trước để hoàn thành.
{{< /alert >}}

## ALB vs Classic Load Balancer

| Feature | Application LB | Classic LB |
|---------|----------------|------------|
| **OSI Layer** | Layer 7 (HTTP/HTTPS) | Layer 4 (TCP) |
| **Routing** | Path/Host based | Port based only |
| **WebSocket** | ✅ Supported | ❌ Not supported |
| **HTTP/2** | ✅ Supported | ❌ Not supported |
| **Container Support** | ✅ Dynamic ports | ⚠️ Limited |
| **Cost** | Pay per LCU | Pay per hour |

{{< alert type="tip" title="💡 Tại sao chọn ALB?" >}}
**Application Load Balancer** phù hợp với ECS vì:

🎯 **Dynamic Port Mapping:** Tự động route tới container ports  
🔄 **Health Checks:** Advanced health checking cho containers  
📊 **Metrics:** Detailed CloudWatch metrics  
🌐 **Path Routing:** Route based on URL paths  
🔒 **SSL Termination:** Handle SSL/TLS certificates  
{{< /alert >}}

## Load Balancing Strategies

### Round Robin (Default)
- Phân phối requests đều cho tất cả healthy targets
- Phù hợp khi tất cả targets có capacity tương đương

### Least Outstanding Requests
- Route tới target có ít pending requests nhất
- Tốt cho applications có response time khác nhau

### Weighted Target Groups
- Phân phối traffic theo tỷ lệ được định sẵn
- Hữu ích cho blue/green deployments

## Bắt đầu

Sẵn sàng tạo Application Load Balancer? Hãy bắt đầu!

{{< button href="./01-create-alb/" >}}Bắt đầu: Tạo ALB →{{< /button >}}

---

## Tài liệu tham khảo

📚 **AWS Documentation:**
- [Application Load Balancer User Guide](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [ECS Service Load Balancing](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-load-balancing.html)

🔧 **Best Practices:**
- [ALB Best Practices](https://aws.amazon.com/blogs/aws/new-application-load-balancer/)
- [ECS Networking Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/networking.html)

---
title : "Giới thiệu Workshop"
date : "2024-08-13"
weight : 1
chapter : false
pre : " <b> 1. </b> "
---

# ECS Advanced Networking Workshop

## 🏗️ Kiến trúc tổng quan

![AWS Architecture Overview](/images/aws-architecture.png)

*Đây là kiến trúc tổng quan của hệ thống ECS Advanced Networking mà chúng ta sẽ xây dựng.*


## Chào mừng bạn đến với Workshop!

Trong workshop này, chúng ta sẽ học cách xây dựng một hệ thống ECS hoàn chỉnh với networking nâng cao trên AWS.

{{< alert type="success" title="Bạn sẽ học được gì?" >}}
✅ **Thiết lập VPC và Networking cơ bản**  
✅ **Triển khai ECS Cluster và Services**  
✅ **Cấu hình Service Discovery**  
✅ **Thiết lập Load Balancing**  
✅ **Bảo mật và Monitoring**  
{{< /alert >}}

## Kiến trúc tổng quan

{{< workshop-image src="images/architecture-overview.png" alt="Workshop Architecture" caption="Kiến trúc tổng quan của hệ thống ECS chúng ta sẽ xây dựng" >}}

### Các thành phần chính:

🌐 **VPC & Networking**
- VPC với public/private subnets
- Internet Gateway và NAT Gateways
- Security Groups

🚀 **ECS Infrastructure**
- ECS Cluster với Fargate
- Multiple services và tasks
- Service Discovery với Cloud Map

⚖️ **Load Balancing**
- Application Load Balancer
- Target Groups và Health Checks
- SSL/TLS termination

🔒 **Security & Monitoring**
- IAM roles và policies
- CloudWatch logs và metrics
- VPC Flow Logs

## Yêu cầu trước khi bắt đầu

{{< alert type="warning" title="Chuẩn bị trước" >}}
📋 **AWS Account** với quyền Administrator  
💻 **AWS CLI** đã cài đặt và cấu hình  
🔑 **IAM User** với Access Keys  
🌍 **Region:** us-east-1 (khuyến nghị)  
{{< /alert >}}

## Thời gian hoàn thành

⏱️ **Tổng thời gian:** 2-3 giờ  
📚 **Độ khó:** Trung bình  
💰 **Chi phí:** ~$5-10 USD  

## Bắt đầu Workshop

Sẵn sàng bắt đầu? Hãy chuyển sang bước tiếp theo để chuẩn bị môi trường!

{{< button href="../2-prerequisites/" >}}Bắt đầu Workshop →{{< /button >}}

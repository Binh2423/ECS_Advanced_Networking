---
title : "Giới thiệu"
date : "`r Sys.Date()`"
weight : 1
chapter : false
pre : " <b> 1. </b> "
---

# Giới thiệu về ECS Advanced Networking

## Amazon ECS là gì?

Amazon Elastic Container Service (ECS) là dịch vụ container orchestration được quản lý hoàn toàn, giúp dễ dàng triển khai, quản lý và mở rộng các ứng dụng container. ECS loại bỏ nhu cầu cài đặt và vận hành phần mềm container orchestration của riêng bạn, quản lý và mở rộng cluster của các máy ảo, hoặc lên lịch containers trên các máy ảo đó.

## Tổng quan về ECS Networking

ECS cung cấp nhiều network modes và tính năng cho phép bạn xây dựng các ứng dụng container phức tạp, sẵn sàng cho production:

### Network Modes

1. **awsvpc Mode** (Được khuyến nghị)
   - Mỗi task có elastic network interface (ENI) riêng
   - Tích hợp trực tiếp VPC với security groups
   - Khả năng bảo mật và monitoring nâng cao

2. **Bridge Mode**
   - Docker bridge networking mặc định
   - Cần port mapping để truy cập từ bên ngoài
   - Chia sẻ network namespace trên host

3. **Host Mode**
   - Truy cập trực tiếp vào host networking
   - Hiệu suất cao nhất nhưng ít isolation
   - Giới hạn về port availability

### Các thành phần Networking chính

#### Service Discovery
- **AWS Cloud Map**: DNS-based service discovery
- **Service Connect**: Giao tiếp service-to-service đơn giản
- **Load Balancer Integration**: Tự động đăng ký/hủy đăng ký

#### Load Balancing
- **Application Load Balancer (ALB)**: Layer 7 load balancing
- **Network Load Balancer (NLB)**: Layer 4 load balancing
- **Classic Load Balancer (CLB)**: Tùy chọn legacy

#### Security
- **Security Groups**: Virtual firewalls cho tasks
- **Network ACLs**: Bảo mật ở mức subnet
- **VPC Endpoints**: Kết nối private đến AWS services

## Kiến trúc Workshop

Trong workshop này, chúng ta sẽ xây dựng giải pháp ECS networking toàn diện:

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet Gateway                      │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                 Application Load Balancer                   │
│                    (Public Subnets)                        │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                    ECS Fargate Tasks                       │
│                   (Private Subnets)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Web App   │  │   API App   │  │  Database   │        │
│  │   Service   │  │   Service   │  │   Service   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                   Service Discovery                        │
│                   (AWS Cloud Map)                          │
└─────────────────────────────────────────────────────────────┘
```

## Mục tiêu học tập

Sau khi hoàn thành workshop này, bạn sẽ có thể:

1. **Thiết kế kiến trúc ECS Network**
   - Chọn network modes phù hợp
   - Lập kế hoạch VPC và subnet strategies
   - Triển khai security best practices

2. **Triển khai Service Discovery**
   - Cấu hình AWS Cloud Map
   - Thiết lập DNS-based service discovery
   - Quản lý service registration/deregistration

3. **Cấu hình Load Balancing nâng cao**
   - Thiết lập Application Load Balancers
   - Triển khai path-based routing
   - Cấu hình health checks và sticky sessions

4. **Bảo mật ECS Networks**
   - Triển khai network segmentation
   - Cấu hình VPC endpoints
   - Thiết lập encryption in transit

5. **Monitor và Troubleshoot**
   - Thiết lập CloudWatch monitoring
   - Phân tích VPC Flow Logs
   - Troubleshoot các vấn đề connectivity

## Ôn tập yêu cầu

Trước khi bắt đầu workshop này, hãy đảm bảo bạn có:

- **AWS Account** với quyền truy cập administrative
- **AWS CLI** được cài đặt và cấu hình
- **Docker** được cài đặt locally (để testing)
- **Kiến thức networking cơ bản** (VPC, subnets, routing)
- **Kinh nghiệm container** (Docker, containerization concepts)

## Luồng Workshop

Workshop này được cấu trúc như một trải nghiệm học tập tiến bộ:

1. **Foundation**: Thiết lập VPC và ECS cluster
2. **Core Services**: Triển khai containerized applications
3. **Service Discovery**: Kích hoạt service-to-service communication
4. **Load Balancing**: Triển khai traffic distribution
5. **Security**: Thêm các lớp network security
6. **Monitoring**: Thiết lập observability
7. **Cleanup**: Xóa tất cả resources

Mỗi phần xây dựng dựa trên phần trước, tạo ra một giải pháp ECS networking hoàn chỉnh, sẵn sàng cho production.

> **Thông tin Workshop**
> - **Thời gian ước tính**: 6 giờ tổng cộng
> - **Chi phí**: Khoảng $15-25 phí AWS
> - **Độ khó**: Trung cấp đến Nâng cao

## Bước tiếp theo

Sẵn sàng bắt đầu? Hãy bắt đầu với phần [Yêu cầu & Thiết lập](../2-prerequisites/) nơi chúng ta sẽ chuẩn bị môi trường cho workshop.

---

**Câu hỏi hoặc Vấn đề?**
- Kiểm tra [Hướng dẫn Troubleshooting](../7-monitoring/)
- Tham gia [AWS Study Group](https://www.facebook.com/groups/awsstudygroupfcj/)
- Mở issue trên [GitHub](https://github.com/Binh2423/ECS_Advanced_Networking_Workshop)

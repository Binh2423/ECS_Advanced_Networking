---
title : "Giới thiệu"
date : "`r Sys.Date()`"
weight : 1
chapter : false
pre : " <b> 1. </b> "
---

# Giới thiệu về ECS Advanced Networking

## Amazon ECS là gì?

Amazon Elastic Container Service (ECS) là dịch vụ container orchestration được quản lý hoàn toàn, giúp dễ dàng triển khai, quản lý và mở rộng các ứng dụng container. ECS loại bỏ nhu cầu cài đặt và vận hành phần mềm container orchestration của riêng bạn.

### Tại sao chọn ECS?

- **Fully Managed**: AWS quản lý infrastructure cho bạn
- **Serverless với Fargate**: Không cần quản lý EC2 instances
- **Tích hợp sâu với AWS**: Native integration với ALB, CloudWatch, IAM
- **Cost-effective**: Chỉ trả tiền cho resources bạn sử dụng

## Tổng quan về ECS Networking

ECS cung cấp nhiều network modes và tính năng cho phép bạn xây dựng các ứng dụng container phức tạp, sẵn sàng cho production:

### Network Modes

#### 1. **awsvpc Mode** (Được khuyến nghị)
- Mỗi task có elastic network interface (ENI) riêng
- Tích hợp trực tiếp VPC với security groups
- Khả năng bảo mật và monitoring nâng cao

**Khi nào sử dụng**: Production workloads, khi cần security groups riêng cho từng task

#### 2. **Bridge Mode**
- Docker bridge networking mặc định
- Cần port mapping để truy cập từ bên ngoài
- Chia sẻ network namespace trên host

**Khi nào sử dụng**: Development, legacy applications

#### 3. **Host Mode**
- Truy cập trực tiếp vào host networking
- Hiệu suất cao nhất nhưng ít isolation
- Giới hạn về port availability

**Khi nào sử dụng**: High-performance applications, monitoring tools

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

Trong workshop này, chúng ta sẽ xây dựng giải pháp ECS networking toàn diện như được thể hiện trong sơ đồ kiến trúc dưới đây:

![ECS Advanced Networking Architecture](/images/ecs-architecture.png)

### Các thành phần kiến trúc

Giải pháp bao gồm:

#### 1. **Multi-AZ VPC Design**
- Public subnets cho load balancers và NAT gateways
- Private subnets cho ECS tasks và internal services
- Internet Gateway cho public internet access
- NAT Gateways cho secure outbound connectivity

#### 2. **ECS Fargate Cluster**
- Serverless container platform
- Tasks được triển khai trên nhiều availability zones
- Automatic scaling và load distribution

#### 3. **Application Load Balancer**
- Layer 7 load balancing với advanced routing
- Health checks và target group management
- SSL/TLS termination capabilities

#### 4. **Service Discovery**
- AWS Cloud Map integration
- DNS-based service resolution
- Automatic service registration/deregistration

#### 5. **Security Implementation**
- Security groups cho network-level access control
- VPC endpoints cho private AWS service access
- Network segmentation best practices

#### 6. **Monitoring & Observability**
- CloudWatch integration cho metrics và logs
- VPC Flow Logs cho network traffic analysis
- Application và infrastructure monitoring

## Mục tiêu học tập

Sau khi hoàn thành workshop này, bạn sẽ có thể:

### 1. **Thiết kế kiến trúc ECS Network**
- Chọn network modes phù hợp cho từng use case
- Lập kế hoạch VPC và subnet strategies
- Triển khai security best practices

### 2. **Triển khai Service Discovery**
- Cấu hình AWS Cloud Map cho DNS-based discovery
- Thiết lập automatic service registration
- Quản lý service health checks

### 3. **Cấu hình Load Balancing nâng cao**
- Thiết lập Application Load Balancers
- Triển khai path-based và header-based routing
- Cấu hình SSL/TLS termination

### 4. **Bảo mật ECS Networks**
- Triển khai network segmentation
- Cấu hình VPC endpoints cho private connectivity
- Thiết lập encryption in transit

### 5. **Monitor và Troubleshoot**
- Thiết lập comprehensive monitoring
- Phân tích VPC Flow Logs
- Troubleshoot các vấn đề connectivity thường gặp

## Tương tác với AWS Console

Trong suốt workshop, bạn sẽ tương tác với các AWS services sau:

### AWS Console Navigation

#### 1. **ECS Console**
- Truy cập: [ECS Console](https://console.aws.amazon.com/ecs/)
- Sử dụng để: Quản lý clusters, services, tasks
- Key sections: Clusters, Task Definitions, Services

#### 2. **VPC Console**
- Truy cập: [VPC Console](https://console.aws.amazon.com/vpc/)
- Sử dụng để: Quản lý networking components
- Key sections: VPCs, Subnets, Route Tables, Security Groups

#### 3. **EC2 Load Balancer Console**
- Truy cập: [EC2 Console - Load Balancers](https://console.aws.amazon.com/ec2/#LoadBalancers)
- Sử dụng để: Cấu hình ALB, target groups
- Key sections: Load Balancers, Target Groups, Listeners

#### 4. **CloudWatch Console**
- Truy cập: [CloudWatch Console](https://console.aws.amazon.com/cloudwatch/)
- Sử dụng để: Monitoring, logs, alarms
- Key sections: Dashboards, Metrics, Logs, Alarms

### AWS CLI Commands Preview

Bạn sẽ sử dụng các AWS CLI commands chính như:

```bash
# ECS operations
aws ecs create-cluster
aws ecs create-service
aws ecs register-task-definition

# VPC operations
aws ec2 create-vpc
aws ec2 create-subnet
aws ec2 create-security-group

# Load Balancer operations
aws elbv2 create-load-balancer
aws elbv2 create-target-group
aws elbv2 create-listener

# Service Discovery operations
aws servicediscovery create-private-dns-namespace
aws servicediscovery create-service
```

## Ôn tập yêu cầu

Trước khi bắt đầu workshop này, hãy đảm bảo bạn có:

### Kiến thức cần thiết
- **AWS Account** với quyền truy cập administrative
- **AWS CLI** được cài đặt và cấu hình
- **Docker** được cài đặt locally (để testing)
- **Kiến thức networking cơ bản** (VPC, subnets, routing)
- **Kinh nghiệm container** (Docker, containerization concepts)

### Công cụ cần thiết
- Terminal/Command prompt
- Text editor (VS Code khuyến nghị)
- Web browser để truy cập AWS Console
- Git (tùy chọn)

## Luồng Workshop

Workshop này được cấu trúc như một trải nghiệm học tập tiến bộ:

### Phase 1: Foundation (Bước 1-3)
1. **Giới thiệu**: Hiểu concepts và architecture
2. **Prerequisites**: Chuẩn bị environment
3. **VPC & Cluster**: Xây dựng networking foundation

### Phase 2: Core Services (Bước 4-5)
4. **Service Discovery**: Kích hoạt service-to-service communication
5. **Load Balancing**: Triển khai traffic distribution

### Phase 3: Production Ready (Bước 6-8)
6. **Security**: Thêm các lớp bảo mật
7. **Monitoring**: Thiết lập observability
8. **Cleanup**: Dọn dẹp resources

Mỗi phần xây dựng dựa trên phần trước, tạo ra một giải pháp ECS networking hoàn chỉnh, sẵn sàng cho production.

## Thông tin Workshop

- **Thời gian ước tính**: 6 giờ tổng cộng
- **Chi phí**: Khoảng $15-25 phí AWS
- **Độ khó**: Trung cấp đến Nâng cao
- **Format**: Hands-on với real AWS environment

## Chuẩn bị bắt đầu

### Checklist trước khi bắt đầu
- [ ] AWS Account đã sẵn sàng
- [ ] AWS CLI đã cấu hình
- [ ] Docker đã cài đặt
- [ ] Text editor đã sẵn sàng
- [ ] Đã đọc qua architecture overview

### Bước tiếp theo

Sẵn sàng bắt đầu? Hãy chuyển đến phần [Yêu cầu & Thiết lập](../2-prerequisites/) nơi chúng ta sẽ chuẩn bị chi tiết môi trường cho workshop.

---

**Câu hỏi hoặc cần hỗ trợ?**
- Kiểm tra [Hướng dẫn Troubleshooting](../7-monitoring/)
- Tham gia [AWS Study Group](https://www.facebook.com/groups/awsstudygroupfcj/)
- Mở issue trên [GitHub](https://github.com/Binh2423/ECS_Advanced_Networking_Workshop)

**Hãy bắt đầu hành trình khám phá ECS Advanced Networking!** 🚀

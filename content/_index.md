---
title: "ECS_Advanced_Networking_Workshop"
date: "`r Sys.Date()`"
weight: 1
chapter: false
---

Chào mừng bạn đến với **ECS Advanced Networking Workshop**! 🚀

{{< alert type="aws" title="Về Workshop" >}}
Workshop này sẽ hướng dẫn bạn triển khai một hệ thống container hoàn chỉnh trên AWS ECS với các tính năng networking nâng cao.
{{< /alert >}}

## Bạn sẽ học được gì?

- **🌐 VPC Networking:** Thiết kế và triển khai VPC với public/private subnets
- **🐳 ECS Container Orchestration:** Quản lý containers với ECS Fargate
- **🔍 Service Discovery:** Kết nối services thông qua DNS
- **⚖️ Load Balancing:** Phân phối traffic với Application Load Balancer
- **🔒 Security:** Bảo mật network với Security Groups và IAM
- **📊 Monitoring:** Theo dõi hệ thống với CloudWatch
- **🧹 Resource Management:** Cleanup và cost optimization

## Architecture Overview

{{< workshop-image src="images/ecs-architecture.png" alt="ECS Advanced Networking Architecture" caption="Kiến trúc tổng quan của workshop - từ Internet đến ECS Services qua Load Balancer và Service Discovery" >}}

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              Application Load Balancer                      │
│                 (Public Subnets)                           │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
┌───────▼──────┐ ┌────▼────┐ ┌──────▼──────┐
│   Frontend   │ │   API   │ │  Database   │
│   Service    │ │ Service │ │   Service   │
│ (ECS Fargate)│ │(ECS     │ │(ECS Fargate)│
│              │ │Fargate) │ │             │
└──────────────┘ └─────────┘ └─────────────┘
       │              │              │
┌──────▼──────────────▼──────────────▼──────┐
│           Private Subnets                 │
│        Service Discovery Network          │
│         (myapp.local domain)              │
└───────────────────────────────────────────┘
```

## Workshop Structure

### 🏗️ [1. Thiết lập VPC và Networking](1-introduction/)
- Tạo VPC với public/private subnets
- Cấu hình Internet Gateway và NAT Gateway
- Thiết lập Route Tables và Security Groups

### 🛠️ [2. Chuẩn bị môi trường](2-prerequisites/)
- Kiểm tra prerequisites và tools
- Cấu hình AWS CLI và permissions
- Setup working environment

### 🐳 [3. Tạo ECS Cluster và Services](3-cluster-setup/)
- Khởi tạo ECS Cluster với Fargate
- Deploy containerized applications
- Cấu hình service scaling và health checks

### 🔍 [4. Triển khai Service Discovery](4-service-discovery/)
- Thiết lập AWS Cloud Map
- Cấu hình private DNS namespace
- Kết nối services qua DNS names

### ⚖️ [5. Cấu hình Load Balancing](5-load-balancing/)
- Tạo Application Load Balancer
- Thiết lập Target Groups và Health Checks
- Cấu hình path-based routing

### 🔒 [6. Security và Network Policies](6-security/)
- Tăng cường Security Groups
- Quản lý secrets với AWS Secrets Manager
- Thiết lập VPC Flow Logs và monitoring

### 📊 [7. Monitoring và Logging](7-monitoring/)
- Cấu hình CloudWatch Logs và Metrics
- Tạo Dashboards và Alarms
- Thiết lập automated monitoring

### 🧹 [8. Cleanup Resources](8-cleanup/)
- Xóa tất cả resources để tránh chi phí
- Best practices cho resource management
- Cost optimization tips

## Prerequisites

### Kiến thức cần có:
- ✅ Hiểu biết cơ bản về AWS
- ✅ Kinh nghiệm với command line
- ✅ Khái niệm về containers và Docker
- ✅ Networking cơ bản (IP, subnets, routing)

### Tools cần thiết:
- ✅ AWS CLI đã cấu hình
- ✅ Quyền truy cập AWS account với admin permissions
- ✅ Terminal/Command prompt
- ✅ Text editor (VS Code, nano, vim)

### Kiểm tra Prerequisites:

```bash
# Kiểm tra AWS CLI
aws --version
aws sts get-caller-identity

# Kiểm tra permissions
aws iam get-user
aws ec2 describe-regions --region us-east-1
```

## Estimated Costs

Workshop này sử dụng các AWS services có tính phí:

| Service | Estimated Cost | Duration |
|---------|----------------|----------|
| ECS Fargate | $0.50-1.00/hour | 3-4 hours |
| Application Load Balancer | $0.025/hour | 3-4 hours |
| NAT Gateway | $0.045/hour | 3-4 hours |
| VPC Flow Logs | $0.10/GB | Minimal |
| CloudWatch Logs | $0.50/GB | Minimal |
| **Total Estimated** | **$2-5** | **Complete Workshop** |

{{< alert type="warning" title="Quan trọng" >}}
Nhớ chạy cleanup script ở cuối workshop để tránh chi phí tiếp tục!
{{< /alert >}}

## Workshop Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| Setup | 30 mins | VPC và networking foundation |
| Core Services | 60 mins | ECS cluster và services |
| Advanced Features | 90 mins | Service discovery, load balancing, security |
| Monitoring | 45 mins | Logging và monitoring setup |
| Cleanup | 15 mins | Resource cleanup |
| **Total** | **4 hours** | **Complete workshop** |

## Getting Started

### Bước 1: Clone Workshop Materials
```bash
# Tạo working directory
mkdir ~/ecs-workshop
cd ~/ecs-workshop

# Tạo environment file
touch workshop-env.sh
```

### Bước 2: Verify AWS Access
```bash
# Test AWS connectivity
aws sts get-caller-identity
aws ec2 describe-regions --region us-east-1 --output table
```

### Bước 3: Set Region
```bash
# Set your preferred region
export AWS_DEFAULT_REGION=us-east-1
aws configure set region us-east-1
```

### Bước 4: Start Workshop
Bắt đầu với [Thiết lập VPC và Networking](1-introduction/) →

## Workshop Features

### 🎯 Hands-on Learning
- Thực hành trực tiếp với AWS Console và CLI
- Step-by-step instructions với screenshots
- Troubleshooting guides cho các vấn đề thường gặp

### 🔧 Production-Ready
- Best practices cho security và performance
- Scalable architecture patterns
- Cost optimization techniques

### 📚 Comprehensive Coverage
- Từ cơ bản đến nâng cao
- Real-world scenarios
- Multiple deployment strategies

### 🛠️ Practical Tools
- Ready-to-use scripts và templates
- Monitoring và alerting setup
- Automated cleanup procedures

## Support và Troubleshooting

### Common Issues:
- **Permission Errors:** Đảm bảo IAM user có đủ permissions
- **Region Issues:** Kiểm tra region consistency
- **Resource Limits:** Verify service quotas
- **Network Connectivity:** Check security group rules

### Getting Help:
- 📖 Detailed troubleshooting trong mỗi section
- 🔍 AWS documentation links
- 💡 Pro tips và best practices
- ⚠️ Common pitfalls và cách tránh

## Learning Outcomes

Sau khi hoàn thành workshop, bạn sẽ có thể:

- ✅ **Thiết kế** VPC architecture cho production workloads
- ✅ **Triển khai** containerized applications với ECS
- ✅ **Cấu hình** service discovery và load balancing
- ✅ **Bảo mật** network infrastructure với AWS security services
- ✅ **Monitoring** và troubleshoot distributed systems
- ✅ **Tối ưu** costs và performance
- ✅ **Quản lý** infrastructure lifecycle

## Next Steps

Sau workshop này, bạn có thể tiếp tục học:

- **ECS với CI/CD:** Automated deployments
- **EKS (Kubernetes):** Container orchestration alternatives  
- **Microservices Patterns:** Advanced architectural patterns
- **Infrastructure as Code:** Terraform, CloudFormation
- **Observability:** Advanced monitoring với X-Ray, Prometheus

---

## 🚀 Ready to Start?

Hãy bắt đầu hành trình khám phá ECS Advanced Networking!

**[Bắt đầu với VPC Setup →](1-introduction/)**

---

{{< alert type="tip" title="Pro Tip" >}}
Bookmark trang này để dễ dàng navigate giữa các sections trong quá trình làm workshop!
{{< /alert >}}

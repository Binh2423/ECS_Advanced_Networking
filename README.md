# Workshop ECS Advanced Networking

🚀 **Workshop thực hành về ECS Advanced Networking trên AWS**

[![Deploy Hugo site to Pages](https://github.com/aurora/ECS_Advanced_Networking_Workshop/actions/workflows/hugo.yml/badge.svg)](https://github.com/aurora/ECS_Advanced_Networking_Workshop/actions/workflows/hugo.yml)

## 📖 Về Workshop

Workshop này hướng dẫn bạn triển khai một hệ thống container hoàn chỉnh trên AWS ECS với các tính năng networking nâng cao bao gồm Service Discovery, Load Balancing, Security và Monitoring.

## 🌐 Truy cập Workshop

**Website:** [https://aurora.github.io/ECS_Advanced_Networking_Workshop/](https://aurora.github.io/ECS_Advanced_Networking_Workshop/)

## 📚 Nội dung Workshop

### 🏗️ [1. Thiết lập VPC và Networking](content/1-introduction/)
- Tạo VPC với public/private subnets
- Cấu hình Internet Gateway và NAT Gateway
- Thiết lập Route Tables và Security Groups

### 🛠️ [2. Chuẩn bị môi trường](content/2-prerequisites/)
- Kiểm tra prerequisites và tools
- Cấu hình AWS CLI và permissions
- Setup working environment

### 🐳 [3. Tạo ECS Cluster và Services](content/3-cluster-setup/)
- Khởi tạo ECS Cluster với Fargate
- Deploy containerized applications
- Cấu hình service scaling và health checks

### 🔍 [4. Triển khai Service Discovery](content/4-service-discovery/)
- Thiết lập AWS Cloud Map
- Cấu hình private DNS namespace
- Kết nối services qua DNS names

### ⚖️ [5. Cấu hình Load Balancing](content/5-load-balancing/)
- Tạo Application Load Balancer
- Thiết lập Target Groups và Health Checks
- Cấu hình path-based routing

### 🔒 [6. Security và Network Policies](content/6-security/)
- Tăng cường Security Groups
- Quản lý secrets với AWS Secrets Manager
- Thiết lập VPC Flow Logs và monitoring

### 📊 [7. Monitoring và Logging](content/7-monitoring/)
- Cấu hình CloudWatch Logs và Metrics
- Tạo Dashboards và Alarms
- Thiết lập automated monitoring

### 🧹 [8. Cleanup Resources](content/8-cleanup/)
- Xóa tất cả resources để tránh chi phí
- Best practices cho resource management
- Cost optimization tips

## 🎯 Mục tiêu học tập

Sau khi hoàn thành workshop, bạn sẽ có thể:

- ✅ **Thiết kế** VPC architecture cho production workloads
- ✅ **Triển khai** containerized applications với ECS
- ✅ **Cấu hình** service discovery và load balancing
- ✅ **Bảo mật** network infrastructure với AWS security services
- ✅ **Monitoring** và troubleshoot distributed systems
- ✅ **Tối ưu** costs và performance

## 💰 Chi phí ước tính

| Service | Chi phí/giờ | Thời gian | Tổng |
|---------|-------------|-----------|------|
| ECS Fargate | $0.50-1.00 | 3-4 giờ | $2-4 |
| Application Load Balancer | $0.025 | 3-4 giờ | $0.10 |
| NAT Gateway | $0.045 | 3-4 giờ | $0.18 |
| VPC Flow Logs | $0.10/GB | Minimal | $0.10 |
| **Tổng ước tính** | | **Toàn bộ workshop** | **$2-5** |

⚠️ **Quan trọng:** Nhớ chạy cleanup script ở cuối workshop để tránh chi phí tiếp tục!

## 🛠️ Prerequisites

### Kiến thức cần có:
- ✅ Hiểu biết cơ bản về AWS
- ✅ Kinh nghiệm với command line
- ✅ Khái niệm về containers và Docker
- ✅ Networking cơ bản (IP, subnets, routing)

### Tools cần thiết:
- ✅ AWS CLI đã cấu hình
- ✅ Quyền truy cập AWS account với admin permissions
- ✅ Terminal/Command prompt
- ✅ Text editor

## 🚀 Bắt đầu

1. **Truy cập workshop:** [https://aurora.github.io/ECS_Advanced_Networking_Workshop/](https://aurora.github.io/ECS_Advanced_Networking_Workshop/)

2. **Kiểm tra prerequisites:**
   ```bash
   aws --version
   aws sts get-caller-identity
   ```

3. **Tạo working directory:**
   ```bash
   mkdir ~/ecs-workshop
   cd ~/ecs-workshop
   ```

4. **Bắt đầu với phần đầu tiên:** [Thiết lập VPC và Networking](https://aurora.github.io/ECS_Advanced_Networking_Workshop/1-introduction/)

## 🏗️ Architecture Overview

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

## 🤝 Đóng góp

Chúng tôi hoan nghênh mọi đóng góp để cải thiện workshop:

1. Fork repository này
2. Tạo feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Tạo Pull Request

## 📝 License

Workshop này được phân phối dưới MIT License. Xem `LICENSE` file để biết thêm chi tiết.

## 📞 Hỗ trợ

- 🐛 **Issues:** [GitHub Issues](https://github.com/aurora/ECS_Advanced_Networking_Workshop/issues)
- 📧 **Email:** Liên hệ qua GitHub
- 📖 **Documentation:** [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)

## 🙏 Acknowledgments

- AWS Documentation Team
- Hugo Theme Learn contributors
- AWS Study Group Vietnam community

---

**⭐ Nếu workshop này hữu ích, hãy star repository để ủng hộ chúng tôi!**

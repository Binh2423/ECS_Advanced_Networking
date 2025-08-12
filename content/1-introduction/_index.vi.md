---
title : "Giới thiệu"
date : "`r Sys.Date()`"
weight : 1
chapter : false
pre : " <b> 1. </b> "
---

# Giới thiệu ECS Advanced Networking

## Amazon ECS là gì?

Amazon ECS (Elastic Container Service) giúp bạn chạy ứng dụng container mà không cần quản lý servers. Giống như thuê một căn hộ đã có đầy đủ tiện nghi thay vì tự xây nhà.

### Tại sao chọn ECS?
- **Không cần quản lý servers**: AWS lo tất cả
- **Chỉ trả tiền khi dùng**: Tiết kiệm chi phí
- **Tự động scale**: Tăng giảm resources theo nhu cầu
- **Bảo mật cao**: Tích hợp sẵn với AWS security

## Workshop này học gì?

Bạn sẽ xây dựng một hệ thống như thế này:

![ECS Architecture](/images/ecs-architecture.png)

### 🎯 Mục tiêu cụ thể:

**Bước 1-3: Xây dựng nền tảng**
- Tạo mạng riêng (VPC) 
- Thiết lập ECS cluster
- Cấu hình bảo mật cơ bản

**Bước 4-5: Kết nối services**
- Services tự tìm thấy nhau (Service Discovery)
- Phân phối traffic thông minh (Load Balancing)

**Bước 6-8: Sẵn sàng production**
- Bảo mật nâng cao
- Giám sát và cảnh báo
- Dọn dẹp tài nguyên

## Chuẩn bị gì?

### Kiến thức cần có:
- Biết cơ bản về AWS (VPC, EC2)
- Hiểu về containers và Docker
- Sử dụng được command line

### Công cụ cần thiết:
- AWS Account có quyền admin
- AWS CLI đã cài đặt
- Docker để test
- Text editor (VS Code khuyến nghị)

### Chi phí dự kiến:
- **Workshop**: ~$15-25 
- **Thời gian**: 6 giờ
- **Độ khó**: Trung cấp

## Kiến trúc sẽ xây dựng

### Thành phần chính:

**1. Network Layer**
```
Internet → Load Balancer → Private Network → ECS Tasks
```

**2. Service Layer**
```
Frontend ↔ API ↔ Database
(Tự động tìm thấy nhau qua DNS)
```

**3. Security Layer**
```
WAF → SSL → Security Groups → Private Subnets
```

**4. Monitoring Layer**
```
CloudWatch → Alarms → Notifications
```

## Tương tác với AWS Console

Trong workshop, bạn sẽ sử dụng các AWS Console sau:

### 🖥️ Console chính:

**ECS Console**: [console.aws.amazon.com/ecs](https://console.aws.amazon.com/ecs/)
- Quản lý clusters, services, tasks
- Xem logs và metrics

**VPC Console**: [console.aws.amazon.com/vpc](https://console.aws.amazon.com/vpc/)
- Tạo và quản lý network
- Cấu hình security groups

**CloudWatch Console**: [console.aws.amazon.com/cloudwatch](https://console.aws.amazon.com/cloudwatch/)
- Xem metrics và logs
- Tạo dashboards và alarms

### 💡 Tips sử dụng Console:
- Bookmark các console thường dùng
- Sử dụng multiple tabs
- Filter theo tags để dễ tìm resources

## Luồng học tập

### Phase 1: Foundation (1-3 giờ)
```
Bước 1: Hiểu concepts → 30 phút
Bước 2: Chuẩn bị tools → 30 phút  
Bước 3: Tạo VPC & ECS → 2 giờ
```

### Phase 2: Core Features (2-3 giờ)
```
Bước 4: Service Discovery → 1.5 giờ
Bước 5: Load Balancing → 1.5 giờ
```

### Phase 3: Production Ready (1-2 giờ)
```
Bước 6: Security → 45 phút
Bước 7: Monitoring → 45 phút
Bước 8: Cleanup → 30 phút
```

## Checklist trước khi bắt đầu

- [ ] AWS Account sẵn sàng
- [ ] AWS CLI configured
- [ ] Docker installed
- [ ] Đã đọc qua architecture
- [ ] Có 6 giờ để hoàn thành

## Bước tiếp theo

Sẵn sàng? Chuyển đến [Chuẩn bị môi trường](../2-prerequisites/) để thiết lập tools cần thiết.

---

**❓ Cần hỗ trợ?**
- [AWS Study Group Facebook](https://www.facebook.com/groups/awsstudygroupfcj/)
- [GitHub Issues](https://github.com/Binh2423/ECS_Advanced_Networking_Workshop/issues)

**🚀 Bắt đầu hành trình ECS networking!**

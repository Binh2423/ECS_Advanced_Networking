#!/bin/bash

# 🏗️ Add AWS Architecture Image to Content
# This script adds the new AWS architecture image to the main page

echo "🏗️ Adding AWS Architecture Image to Content"
echo "==========================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if the AWS architecture image exists
if [ ! -f "static/images/aws-architecture.png" ]; then
    echo "❌ AWS architecture image not found!"
    exit 1
fi

print_info "Adding AWS architecture image to main content page..."

# Update the main index page to include the AWS architecture
cat > content/_index.md << 'EOF'
---
title: "ECS Advanced Networking Workshop"
date: "2024-08-13"
weight: 1
chapter: false
---

# 🚀 ECS Advanced Networking Workshop

Chào mừng bạn đến với workshop về **Amazon ECS Advanced Networking**! Workshop này sẽ hướng dẫn bạn từng bước để thiết lập và cấu hình một hệ thống ECS với networking nâng cao.

## 🏗️ AWS Architecture Overview

![AWS Architecture Overview](/images/aws-architecture.png)

*Kiến trúc tổng quan của hệ thống ECS Advanced Networking mà chúng ta sẽ xây dựng trong workshop này.*

## 📋 Nội dung Workshop

Workshop này bao gồm các phần chính sau:

### 🔧 [1. Giới thiệu](/1-introduction/)
- Tổng quan về ECS và Advanced Networking
- Kiến trúc hệ thống
- Yêu cầu và chuẩn bị

### 📋 [2. Yêu cầu tiên quyết](/2-prerequisites/)
- Tài khoản AWS
- IAM permissions
- AWS CLI setup
- Kiến thức cơ bản về networking

### 🏗️ [3. Thiết lập Cluster](/3-cluster-setup/)
- Tạo VPC và Subnets
- Cấu hình Internet Gateway
- Thiết lập NAT Gateways
- Cấu hình Route Tables
- Thiết lập Security Groups

### 🔍 [4. Service Discovery](/4-service-discovery/)
- AWS Cloud Map
- Service Discovery configuration
- DNS-based service discovery

### ⚖️ [5. Load Balancing](/5-load-balancing/)
- Application Load Balancer (ALB)
- Target Groups
- Health Checks
- Listener Rules

### 🔒 [6. Security](/6-security/)
- Security Groups best practices
- Network ACLs
- IAM roles và policies
- Encryption in transit

### 📊 [7. Monitoring](/7-monitoring/)
- CloudWatch metrics
- Container Insights
- Log aggregation
- Alerting

### 🧹 [8. Cleanup](/8-cleanup/)
- Xóa resources
- Cost optimization
- Best practices

## 🎯 Mục tiêu Workshop

Sau khi hoàn thành workshop này, bạn sẽ có thể:

- ✅ Thiết lập một VPC với networking architecture phức tạp
- ✅ Deploy ECS services với advanced networking features
- ✅ Cấu hình service discovery và load balancing
- ✅ Implement security best practices
- ✅ Monitor và troubleshoot ECS networking issues
- ✅ Optimize costs và performance

## 🚀 Bắt đầu

Hãy bắt đầu với [**Giới thiệu**](/1-introduction/) để tìm hiểu về kiến trúc và yêu cầu của workshop!

---

**💡 Lưu ý:** Workshop này được thiết kế cho intermediate level. Bạn nên có kiến thức cơ bản về AWS, Docker, và networking concepts.
EOF

print_status "Updated main content page with AWS architecture image"

# Also update the introduction page to reference the architecture
print_info "Updating introduction page..."

# Check if introduction page exists and update it
if [ -f "content/1-introduction/_index.md" ]; then
    # Add architecture reference to introduction if not already there
    if ! grep -q "aws-architecture.png" content/1-introduction/_index.md; then
        # Insert architecture image after the title
        sed -i '/^# /a\\n## 🏗️ Kiến trúc tổng quan\n\n![AWS Architecture Overview](/images/aws-architecture.png)\n\n*Đây là kiến trúc tổng quan của hệ thống ECS Advanced Networking mà chúng ta sẽ xây dựng.*\n' content/1-introduction/_index.md
        print_status "Added architecture image to introduction page"
    else
        print_info "Architecture image already exists in introduction page"
    fi
fi

print_info "Testing Hugo build after adding AWS architecture..."
if hugo --gc --minify > /dev/null 2>&1; then
    print_status "Hugo build successful with AWS architecture image"
else
    echo "❌ Hugo build failed"
    hugo --gc --minify --verbose
    exit 1
fi

print_status "🎉 AWS Architecture image successfully added to content!"

echo ""
print_info "📋 What was added:"
echo "• ✅ AWS architecture image reference in main page"
echo "• ✅ Updated introduction page with architecture"
echo "• ✅ Verified Hugo build works correctly"

echo ""
print_info "🎯 Next steps:"
echo "1. Review the changes: git diff"
echo "2. Test locally: hugo server"
echo "3. Commit changes: git add . && git commit -m 'Add AWS architecture image'"
echo "4. Push to GitHub: git push origin main"

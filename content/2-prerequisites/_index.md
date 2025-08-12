---
title : "Prerequisites & Setup"
date : "`r Sys.Date()`"
weight : 2
chapter : false
pre : " <b> 2. </b> "
---

# Prerequisites & Setup

Before diving into the ECS Advanced Networking workshop, let's ensure your environment is properly configured with all necessary tools and permissions.

## AWS Account Requirements

### Account Setup
- **AWS Account** with billing enabled
- **Administrative access** or equivalent permissions for:
  - EC2 (VPC, Security Groups, Load Balancers)
  - ECS (Clusters, Services, Tasks)
  - IAM (Roles, Policies)
  - CloudWatch (Logs, Metrics)
  - Route 53 (for Service Discovery)

### Cost Considerations
- **Estimated workshop cost**: $15-25
- **Free Tier eligible**: Some services (CloudWatch Logs, limited ECS usage)
- **Billing alerts**: Recommended to set up before starting

> **Warning**: This workshop will create AWS resources that incur charges. Make sure to complete the cleanup section at the end!

## Required Tools

### 1. AWS CLI v2
Install and configure the AWS Command Line Interface:

```bash
# Install AWS CLI v2 (Linux/macOS)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

**Configure AWS CLI:**
```bash
aws configure
# Enter your Access Key ID
# Enter your Secret Access Key
# Default region: us-east-1 (recommended for this workshop)
# Default output format: json
```

### 2. Docker Desktop
Install Docker for local container testing:

- **Windows/macOS**: [Docker Desktop](https://www.docker.com/products/docker-desktop)
- **Linux**: [Docker Engine](https://docs.docker.com/engine/install/)

```bash
# Verify Docker installation
docker --version
docker run hello-world
```

### 3. Text Editor/IDE
Recommended editors with AWS/Docker support:
- **Visual Studio Code** with AWS Toolkit extension
- **AWS Cloud9** (browser-based IDE)
- **IntelliJ IDEA** with AWS plugin

### 4. Git (Optional)
For cloning workshop materials:
```bash
git --version
```

## AWS Permissions

### Required IAM Permissions
Your AWS user/role needs the following permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "ecs:*",
                "elasticloadbalancing:*",
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "iam:PassRole",
                "logs:*",
                "servicediscovery:*",
                "route53:*"
            ],
            "Resource": "*"
        }
    ]
}
```

### Service-Linked Roles
ECS will automatically create required service-linked roles. If you encounter permission issues, you may need to create them manually:

```bash
# Create ECS service-linked role
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com
```

## Environment Validation

### 1. AWS CLI Test
Verify your AWS CLI configuration:

```bash
# Test AWS CLI connectivity
aws sts get-caller-identity

# Expected output:
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/YourUsername"
}
```

### 2. Region Check
Ensure you're using the correct AWS region:

```bash
# Check current region
aws configure get region

# List available regions
aws ec2 describe-regions --query 'Regions[].RegionName' --output table
```

### 3. VPC Limits Check
Verify your VPC limits:

```bash
# Check VPC limits
aws ec2 describe-account-attributes --attribute-names supported-platforms
aws ec2 describe-vpcs --query 'length(Vpcs)'
```

## Workshop Materials

### Download Workshop Files
Clone or download the workshop repository:

```bash
# Clone the repository
git clone https://github.com/Binh2423/ECS_Advanced_Networking_Workshop.git
cd ECS_Advanced_Networking_Workshop

# Or download as ZIP from GitHub
```

### Directory Structure
```
ECS_Advanced_Networking_Workshop/
├── cloudformation/          # CloudFormation templates
├── docker/                  # Sample Docker applications
├── scripts/                 # Helper scripts
├── docs/                    # Additional documentation
└── cleanup/                 # Cleanup scripts
```

## Pre-Workshop Checklist

Before proceeding to the next section, ensure you have completed:

- [ ] AWS account with appropriate permissions
- [ ] AWS CLI v2 installed and configured
- [ ] Docker installed and working
- [ ] Text editor/IDE ready
- [ ] Workshop materials downloaded
- [ ] Billing alerts configured (recommended)

### Verification Commands
Run these commands to verify your setup:

```bash
# AWS CLI
aws --version
aws sts get-caller-identity

# Docker
docker --version
docker run hello-world

# Region confirmation
echo "Using AWS region: $(aws configure get region)"
```

## Troubleshooting Common Issues

### AWS CLI Issues
**Problem**: `aws: command not found`
**Solution**: Ensure AWS CLI is in your PATH or reinstall

**Problem**: `Unable to locate credentials`
**Solution**: Run `aws configure` or check environment variables

### Docker Issues
**Problem**: `docker: permission denied`
**Solution**: Add user to docker group (Linux) or restart Docker Desktop

**Problem**: `Cannot connect to Docker daemon`
**Solution**: Start Docker service/application

### Permission Issues
**Problem**: `AccessDenied` errors
**Solution**: Check IAM permissions or contact your AWS administrator

## Next Steps

Once you've completed all prerequisites, you're ready to move on to [ECS Cluster & VPC Configuration](../3-cluster-setup/) where we'll start building our networking infrastructure.

---

**Need Help?**
- Check the [AWS CLI User Guide](https://docs.aws.amazon.com/cli/latest/userguide/)
- Visit [Docker Documentation](https://docs.docker.com/)
- Join our [AWS Study Group](https://www.facebook.com/groups/awsstudygroupfcj/) for community support

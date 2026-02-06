# AWS Partner Revenue Measurement (PRM) Tagging Solutions

Complete toolkit for automatically tagging AWS resources with PRM partner identification tags.

## 📦 What's Included

This package contains **two complete solutions**:

### 1. **CLI Scripts** (Traditional Approach)
Bash scripts for running on EC2, your laptop, or CI/CD pipelines

### 2. **Lambda Function** (Serverless Approach)  
Automated, scheduled tagging using AWS Lambda

---

## 🚀 Quick Decision Guide

**Choose CLI Scripts if you:**
- Want to run tagging manually or in CI/CD pipelines
- Need full control over execution timing
- Prefer traditional scripting approaches
- Want to run from your local machine or EC2 instance

**Choose Lambda if you:**
- Want fully automated, hands-off operation
- Prefer serverless architecture
- Need scheduled automatic tagging
- Want to minimize operational overhead

---

## 📁 File Directory

### **Core Lambda Files**

| File | Purpose |
|------|---------|
| `lambda_function.py` | Main Lambda function code |
| `cloudformation-template.yaml` | Complete infrastructure as code |
| `deploy-lambda.sh` | Automated deployment script |
| `lambda-iam-policy.json` | IAM permissions for Lambda |
| `trust-policy.json` | Lambda execution role trust policy |
| `requirements.txt` | Python dependencies |
| `test-events.json` | Sample test payloads |
| `LAMBDA-README.md` | **START HERE for Lambda** |

### **CLI Script Files**

| File | Purpose |
|------|---------|
| `aws-prm-tagging.sh` | Single-region tagging script |
| `aws-prm-tagging-multi-region.sh` | Multi-region wrapper |
| `verify-prm-tags.sh` | Verification and reporting |
| `iam-policy.json` | IAM permissions for CLI |
| `README.md` | CLI script documentation |
| `QUICKSTART.md` | **START HERE for CLI scripts** |

---

## 🎯 Configuration

Both solutions use the same tag:
- **Tag Key:** `aws-apn-id`
- **Tag Value:** `pc:3jtjsihjubajawpl401j5b27s`

This is pre-configured in all scripts and templates.

---

## 🔧 Installation & Setup

### Option 1: Lambda (Recommended for Production)

```bash
# 1. Review the Lambda README
cat LAMBDA-README.md

# 2. Deploy using the script
chmod +x deploy-lambda.sh
./deploy-lambda.sh

# 3. Test the deployment
aws lambda invoke \
  --function-name prm-auto-tagger \
  --payload '{"dry_run": true}' \
  output.json
```

**What this gives you:**
- Automated daily tagging (configurable schedule)
- Multi-region support
- CloudWatch logging and monitoring
- SNS notifications for errors
- Zero maintenance after setup

### Option 2: CLI Scripts

```bash
# 1. Review the Quick Start guide
cat QUICKSTART.md

# 2. Make scripts executable
chmod +x *.sh

# 3. Test with dry run
DRY_RUN=true ./aws-prm-tagging.sh

# 4. Run for real
./aws-prm-tagging.sh

# 5. Verify tags were applied
./verify-prm-tags.sh
```

**What this gives you:**
- Full control over execution
- Easy to integrate with CI/CD
- Run on-demand or scheduled via cron
- Simple debugging and customization

---

## 📊 Supported AWS Services

Both solutions support **80+ AWS services**, including:

**Compute**
- EC2 (instances, volumes, snapshots)
- Lambda functions
- ECS clusters and services  
- EKS clusters
- Elastic Beanstalk

**Storage**
- S3 buckets
- EBS volumes and snapshots
- EFS file systems
- FSx file systems
- AWS Backup vaults

**Database**
- RDS (all engines)
- DynamoDB
- ElastiCache
- Redshift
- Neptune
- DocumentDB
- MemoryDB

**Networking**
- Load Balancers (ALB, NLB, Classic)
- CloudFront distributions
- API Gateway
- Transit Gateways
- VPC resources

**Analytics**
- Athena workgroups
- Glue jobs
- Kinesis streams
- EMR clusters
- OpenSearch domains
- MSK clusters

**Machine Learning**
- SageMaker endpoints and models
- Bedrock resources

**And many more...**

See the AWS documentation link in the scripts for the complete official list.

---

## 🏃 Common Use Cases

### Use Case 1: First-Time Setup (Lambda)

```bash
# Deploy Lambda function
./deploy-lambda.sh

# Let it run on schedule, or invoke immediately
aws lambda invoke \
  --function-name prm-auto-tagger \
  --payload '{"regions": ["us-east-1", "us-west-2"]}' \
  output.json
```

### Use Case 2: Scheduled Tagging (CLI + Cron)

```bash
# Add to crontab for daily execution
0 2 * * * /path/to/aws-prm-tagging-multi-region.sh >> /var/log/prm-tagging.log 2>&1
```

### Use Case 3: CI/CD Integration

```yaml
# GitHub Actions example
- name: Tag AWS Resources
  run: |
    ./aws-prm-tagging-multi-region.sh
```

### Use Case 4: Multi-Account Tagging (Lambda)

Deploy Lambda via CloudFormation StackSets to multiple accounts:

```bash
aws cloudformation create-stack-set \
  --stack-set-name prm-auto-tagger \
  --template-body file://cloudformation-template.yaml
```

### Use Case 5: On-Demand Tagging (CLI)

```bash
# Tag specific region immediately
AWS_REGION=eu-west-1 ./aws-prm-tagging.sh
```

---

## 📈 Monitoring & Verification

### Verify Tagged Resources

**Using CLI:**
```bash
./verify-prm-tags.sh

# Or check specific region
AWS_REGION=us-west-2 ./verify-prm-tags.sh

# Export as CSV
OUTPUT_FORMAT=csv ./verify-prm-tags.sh
```

**Using AWS CLI:**
```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters "Key=aws-apn-id,Values=pc:3jtjsihjubajawpl401j5b27s" \
  --region us-east-1 \
  --query 'length(ResourceTagMappingList)'
```

### View Lambda Logs

```bash
aws logs tail /aws/lambda/prm-auto-tagger --follow
```

---

## 💰 Cost Estimates

### Lambda Solution
- **Monthly cost:** $0.50 - $2.50
  - Lambda execution: ~$0.00 (free tier)
  - CloudWatch Logs: $0.50 - $2.00
- **Ideal for:** Automated, production deployments

### CLI Scripts  
- **Monthly cost:** $0.00 - $5.00
  - EC2 instance (if running on EC2): $3-5/month (t3.micro)
  - No cost if running locally or in existing CI/CD
- **Ideal for:** On-demand or CI/CD integration

---

## 🔒 Security & Compliance

Both solutions follow AWS best practices:

✅ Least-privilege IAM policies  
✅ CloudTrail audit logging  
✅ Encrypted environment variables (Lambda)  
✅ No hardcoded credentials  
✅ Read-only operations except for tagging  
✅ VPC support (Lambda can run in VPC)  

---

## 🐛 Troubleshooting

### Common Issues

**"Access Denied" Errors**
- Verify IAM permissions match policy files
- Check for Service Control Policies (SCPs)
- Ensure role trust relationships are correct

**Timeout Issues (Lambda)**
- Increase Lambda timeout to 900 seconds
- Process fewer regions per invocation
- Increase memory allocation

**Resources Not Tagged**
- Check CloudWatch logs for errors
- Verify resources exist in target region
- Some services may not support tagging via API

**Script Fails Midway (CLI)**
- Scripts continue on error by default
- Check summary at end for failure count
- Review logs for specific resource errors

---

## 📚 Additional Resources

- **AWS PRM Documentation:** https://docs.aws.amazon.com/PRM/latest/aws-prm-onboarding-guide/
- **AWS Tagging Best Practices:** https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/
- **Lambda Developer Guide:** https://docs.aws.amazon.com/lambda/
- **Boto3 Documentation:** https://boto3.amazonaws.com/v1/documentation/api/latest/

---

## 🤝 Support & Feedback

For issues specific to:
- **AWS Partner Revenue Measurement:** Contact AWS Partner Support
- **Script customization:** Modify the code to fit your needs
- **AWS services:** Refer to AWS documentation

---

## 📝 Next Steps

### For Lambda Deployment:
1. ✅ Read `LAMBDA-README.md`
2. ✅ Run `./deploy-lambda.sh`
3. ✅ Subscribe to SNS notifications
4. ✅ Test with dry run
5. ✅ Monitor CloudWatch logs

### For CLI Scripts:
1. ✅ Read `QUICKSTART.md`
2. ✅ Test with `DRY_RUN=true`
3. ✅ Run actual tagging
4. ✅ Verify with verification script
5. ✅ Schedule if needed

---

## 📄 License

This solution is provided as-is for use with AWS Partner Revenue Measurement requirements.

---

## Summary

You now have **two production-ready solutions** for AWS PRM tagging:

1. **Lambda** - Fully automated, serverless, scheduled execution
2. **CLI Scripts** - Flexible, on-demand, CI/CD-friendly

Choose the approach that best fits your infrastructure and operational model!

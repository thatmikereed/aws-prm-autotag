# Quick Start Guide - AWS PRM Tagging

This guide will help you quickly tag your AWS resources for Partner Revenue Measurement.

## Prerequisites Checklist

- [ ] AWS CLI v2 installed (`aws --version`)
- [ ] AWS credentials configured (`aws sts get-caller-identity`)
- [ ] IAM permissions granted (see iam-policy.json)
- [ ] Bash shell available
- [ ] (Optional) jq installed for verification script

## Step 1: Setup

```bash
# Download or clone the scripts
# Make them executable
chmod +x aws-prm-tagging.sh
chmod +x aws-prm-tagging-multi-region.sh
chmod +x verify-prm-tags.sh
```

## Step 2: Test with Dry Run

**For a single region:**
```bash
# Test in current/default region
DRY_RUN=true ./aws-prm-tagging.sh

# Test in specific region
DRY_RUN=true AWS_REGION=us-west-2 ./aws-prm-tagging.sh
```

**For multiple regions:**
```bash
# Edit aws-prm-tagging-multi-region.sh to set your desired regions
# Then run in dry-run mode
DRY_RUN=true ./aws-prm-tagging-multi-region.sh
```

Review the dry run output to ensure the script can access your resources.

## Step 3: Apply Tags

**Single region:**
```bash
# Apply tags in current/default region
./aws-prm-tagging.sh

# Apply tags in specific region
AWS_REGION=us-west-2 ./aws-prm-tagging.sh
```

**Multiple regions:**
```bash
# Apply tags across all configured regions
./aws-prm-tagging-multi-region.sh
```

**Expected output:**
```
[INFO] Processing EC2 instances...
[SUCCESS] Tagged EC2 instance: i-1234567890abcdef0
[INFO] Processing S3 buckets...
[SUCCESS] Tagged S3 bucket: my-bucket
...
========================================================================
Summary
========================================================================
Total resources found: 150
Successfully tagged: 148
Failed to tag: 2
========================================================================
```

## Step 4: Verify Tags

**Check tags in a single region:**
```bash
./verify-prm-tags.sh

# Or for a specific region
AWS_REGION=eu-west-1 ./verify-prm-tags.sh
```

**Export verification report:**
```bash
# As JSON
OUTPUT_FORMAT=json ./verify-prm-tags.sh

# As CSV
OUTPUT_FORMAT=csv ./verify-prm-tags.sh

# Detailed list
DETAILED=true ./verify-prm-tags.sh
```

## Step 5: Schedule Regular Tagging (Optional)

To automatically tag new resources, you can:

### Option A: AWS Lambda + EventBridge

Create a Lambda function that runs the tagging logic on a schedule or triggered by resource creation events.

### Option B: Cron Job

```bash
# Edit crontab
crontab -e

# Add entry to run daily at 2 AM
0 2 * * * /path/to/aws-prm-tagging-multi-region.sh >> /var/log/aws-prm-tagging.log 2>&1
```

### Option C: CI/CD Pipeline

Integrate the script into your CI/CD pipeline to tag resources as part of your deployment process.

## Common Scenarios

### Scenario 1: New AWS Account
```bash
# Run multi-region tagging for all active regions
./aws-prm-tagging-multi-region.sh

# Verify
for region in us-east-1 us-west-2 eu-west-1; do
    echo "Checking $region..."
    AWS_REGION=$region ./verify-prm-tags.sh
done
```

### Scenario 2: Single Service/Region
```bash
# Tag only in us-east-1
AWS_REGION=us-east-1 ./aws-prm-tagging.sh
```

### Scenario 3: Testing Before Production
```bash
# 1. Test in dry run
DRY_RUN=true ./aws-prm-tagging.sh

# 2. Apply to dev/test account first
AWS_PROFILE=dev-account ./aws-prm-tagging.sh

# 3. Verify
AWS_PROFILE=dev-account ./verify-prm-tags.sh

# 4. If successful, apply to production
AWS_PROFILE=prod-account ./aws-prm-tagging.sh
```

### Scenario 4: Specific Regions Only
```bash
# Edit aws-prm-tagging-multi-region.sh and change REGIONS array:
REGIONS=("us-east-1" "us-west-2" "eu-west-1")

# Then run
./aws-prm-tagging-multi-region.sh
```

## Troubleshooting

### Issue: "Access Denied" errors
**Solution:** 
1. Check IAM permissions using iam-policy.json
2. Verify you're using the correct AWS profile
3. Check for Service Control Policies (SCPs) that might restrict tagging

```bash
# Check current identity
aws sts get-caller-identity

# Test a specific permission
aws ec2 describe-instances --max-results 1
```

### Issue: Resources not found
**Solution:**
1. Verify you're in the correct region
2. Check that resources exist
3. Some services may not be available in all regions

```bash
# List all regions your account is active in
aws ec2 describe-regions --query 'Regions[].RegionName' --output table
```

### Issue: Script runs but doesn't tag anything
**Solution:**
1. Ensure DRY_RUN is not set to true
2. Check that resources exist in the target region
3. Verify AWS CLI is configured correctly

```bash
# Verify AWS CLI configuration
aws configure list

# Check resources exist
aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId'
```

### Issue: Some resources fail to tag
**Solution:**
1. Check the error messages in the output
2. Verify resource-specific permissions
3. Some resources may have tag limits or restrictions

## Monitoring and Maintenance

### Weekly Verification
```bash
#!/bin/bash
# weekly-check.sh
for region in us-east-1 us-west-2 eu-west-1; do
    count=$(AWS_REGION=$region aws resourcegroupstaggingapi get-resources \
        --tag-filters "Key=aws-apn-id,Values=pc:3jtjsihjubajawpl401j5b27s" \
        --query 'length(ResourceTagMappingList)' --output text)
    echo "$region: $count resources tagged"
done
```

### Monthly Full Scan
```bash
# Run full tagging across all regions
./aws-prm-tagging-multi-region.sh

# Generate reports
for region in us-east-1 us-west-2 eu-west-1; do
    OUTPUT_FORMAT=csv AWS_REGION=$region ./verify-prm-tags.sh
done
```

## Best Practices

1. **Always test with dry run first** before applying tags in production
2. **Start with one region** to validate the process
3. **Keep IAM permissions minimal** - only grant what's needed
4. **Schedule regular runs** to catch newly created resources
5. **Monitor the summary output** for any failed resources
6. **Keep logs** of tagging operations for audit purposes
7. **Verify tags** after running the script
8. **Document any customizations** you make to the scripts

## Getting Help

- **AWS Partner Support:** For PRM-specific questions
- **AWS Support:** For general AWS service questions
- **Script Issues:** Review error messages and check permissions

## Additional Resources

- [AWS Partner Revenue Measurement Documentation](https://docs.aws.amazon.com/PRM/latest/aws-prm-onboarding-guide/what-is-service.html)
- [AWS Tagging Strategies](https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/tagging-best-practices.html)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/)

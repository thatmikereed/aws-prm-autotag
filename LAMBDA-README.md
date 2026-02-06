# AWS PRM Auto-Tagging Lambda Function

Automated serverless solution for tagging AWS resources with Partner Revenue Measurement (PRM) tags.

## Overview

This Lambda function automatically discovers and tags AWS resources across multiple regions with the required `aws-apn-id` tag for AWS Partner Revenue Measurement tracking. It can run on a schedule or be triggered manually.

## Features

- ✅ **Automatic tagging** of 80+ AWS services
- ✅ **Multi-region support** - tag resources across all regions in one execution
- ✅ **Scheduled execution** - runs automatically via EventBridge
- ✅ **Dry-run mode** - test before applying changes
- ✅ **Concurrent processing** - fast multi-region execution
- ✅ **Comprehensive logging** - detailed CloudWatch logs
- ✅ **Error notifications** - SNS alerts for failures
- ✅ **Infrastructure as Code** - CloudFormation deployment

## Architecture

```
EventBridge Rule (Schedule)
         ↓
    Lambda Function
         ↓
    ┌────┴────┐
    ↓         ↓
  Region 1  Region 2  (Concurrent)
    ↓         ↓
  Tag Resources
    ↓
CloudWatch Logs + SNS Notifications
```

## Quick Start

### Prerequisites

- AWS CLI v2 installed and configured
- Python 3.12 or later (for local testing)
- IAM permissions to create Lambda functions and IAM roles
- zip utility

### 1. Deploy with CloudFormation

```bash
# Make deployment script executable
chmod +x deploy-lambda.sh

# Deploy with defaults
./deploy-lambda.sh

# Or deploy with custom parameters
STACK_NAME=my-prm-tagger \
AWS_REGION=us-east-1 \
SCHEDULE="rate(12 hours)" \
./deploy-lambda.sh
```

### 2. Manual Deployment Steps

If you prefer manual deployment:

```bash
# 1. Package the Lambda function
zip -r lambda-deployment.zip lambda_function.py

# 2. Create IAM role
aws iam create-role \
  --role-name PRMTaggerLambdaRole \
  --assume-role-policy-document file://trust-policy.json

aws iam put-role-policy \
  --role-name PRMTaggerLambdaRole \
  --policy-name PRMTaggingPolicy \
  --policy-document file://lambda-iam-policy.json

# 3. Create Lambda function
aws lambda create-function \
  --function-name prm-auto-tagger \
  --runtime python3.12 \
  --role arn:aws:iam::ACCOUNT_ID:role/PRMTaggerLambdaRole \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://lambda-deployment.zip \
  --timeout 900 \
  --memory-size 512 \
  --environment Variables="{TAG_KEY=aws-apn-id,TAG_VALUE=pc:3jtjsihjubajawpl401j5b27s}"

# 4. Deploy CloudFormation template (alternative)
aws cloudformation deploy \
  --template-file cloudformation-template.yaml \
  --stack-name prm-auto-tagger \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    TagKey=aws-apn-id \
    TagValue=pc:3jtjsihjubajawpl401j5b27s \
    ScheduleExpression="rate(1 day)"
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TAG_KEY` | `aws-apn-id` | Tag key to apply |
| `TAG_VALUE` | `pc:3jtjsihjubajawpl401j5b27s` | Tag value to apply |
| `DRY_RUN` | `false` | Set to `true` to test without tagging |
| `TARGET_REGIONS` | (current region) | Comma-separated list of regions |

### CloudFormation Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `TagKey` | `aws-apn-id` | Tag key to apply |
| `TagValue` | `pc:3jtjsihjubajawpl401j5b27s` | Tag value |
| `TargetRegions` | (empty) | Comma-separated regions list |
| `ScheduleExpression` | `rate(1 day)` | EventBridge schedule |
| `EnableSchedule` | `true` | Enable automatic scheduling |
| `LambdaTimeout` | `900` | Function timeout (seconds) |
| `LambdaMemory` | `512` | Function memory (MB) |

## Usage

### Manual Invocation

**Test with dry run:**
```bash
aws lambda invoke \
  --function-name prm-auto-tagger \
  --payload '{"dry_run": true}' \
  output.json
```

**Tag resources in current region:**
```bash
aws lambda invoke \
  --function-name prm-auto-tagger \
  output.json
```

**Tag specific regions:**
```bash
aws lambda invoke \
  --function-name prm-auto-tagger \
  --payload '{"regions": ["us-east-1", "us-west-2", "eu-west-1"]}' \
  output.json
```

**Tag specific services:**
```bash
aws lambda invoke \
  --function-name prm-auto-tagger \
  --payload '{"services": ["ec2", "s3", "lambda"]}' \
  output.json
```

### Event Payload Schema

```json
{
  "dry_run": false,
  "regions": ["us-east-1", "us-west-2"],
  "services": ["ec2", "s3", "lambda"],
  "tag_key": "aws-apn-id",
  "tag_value": "pc:3jtjsihjubajawpl401j5b27s"
}
```

All fields are optional. Omitted fields use environment variable defaults.

### Automated Scheduling

The function runs automatically based on the EventBridge schedule. Default schedules:

- `rate(1 hour)` - Every hour
- `rate(6 hours)` - Every 6 hours
- `rate(12 hours)` - Every 12 hours
- `rate(1 day)` - Daily
- `cron(0 2 * * ? *)` - Daily at 2 AM UTC

## Supported AWS Services

The Lambda function tags resources in these service categories:

**Compute:** EC2, Lambda, ECS, EKS, Elastic Beanstalk

**Storage:** S3, EBS, EFS, FSx, Storage Gateway, Backup

**Database:** RDS, DynamoDB, ElastiCache, Redshift, Neptune, DocumentDB, MemoryDB, Keyspaces, Timestream

**Networking:** VPC, Load Balancers, CloudFront, API Gateway, Transit Gateway, Direct Connect, Network Firewall

**Analytics:** Athena, Glue, Kinesis, EMR, OpenSearch, MSK, QuickSight

**Machine Learning:** SageMaker, Bedrock

**Application Integration:** SNS, SQS, Step Functions, EventBridge, MQ, AppSync

**Security:** Secrets Manager, KMS, Certificate Manager

**Developer Tools:** CodeBuild, CodePipeline, CodeStar, ECR

**Migration:** DMS, DataSync, Application Discovery Service

**And many more...**

## Monitoring

### CloudWatch Logs

View logs in real-time:
```bash
aws logs tail /aws/lambda/prm-auto-tagger --follow
```

### CloudWatch Metrics

The Lambda function automatically reports:
- Invocations
- Duration
- Errors
- Concurrent executions

### SNS Notifications

Subscribe to the notification topic for error alerts:
```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:REGION:ACCOUNT:prm-auto-tagger-Notifications \
  --protocol email \
  --notification-endpoint your-email@example.com
```

### Example Log Output

```
[INFO] Event received: {"dry_run": false, "regions": ["us-east-1"]}
[INFO] Processing regions: ['us-east-1']
[INFO] Dry run mode: False
[INFO] Tag: aws-apn-id=pc:3jtjsihjubajawpl401j5b27s
[INFO] Starting processing for region: us-east-1
[INFO] Processing ec2 resources in us-east-1...
[INFO] Tagged EC2 instance: i-1234567890abcdef0
[INFO] Processing s3 resources in us-east-1...
[INFO] Tagged S3 bucket: my-application-bucket
[INFO] Completed region us-east-1: {'total': 150, 'tagged': 148, 'failed': 2}
[INFO] Final statistics: {'total': 150, 'tagged': 148, 'failed': 2}
```

## Cost Optimization

### Estimated Monthly Costs

**Lambda Execution:**
- Memory: 512 MB
- Duration: ~5 minutes per region
- Schedule: Daily (once per day)
- Free tier: 1M requests, 400,000 GB-seconds per month

**Cost breakdown for typical usage:**
- Lambda requests: $0.00 (within free tier)
- Lambda duration: $0.00 - $0.50/month
- CloudWatch Logs: $0.50 - $2.00/month
- Total: **~$0.50 - $2.50/month**

### Cost Reduction Tips

1. **Adjust schedule** - Run less frequently (e.g., weekly instead of daily)
2. **Reduce memory** - Start with 256 MB if adequate
3. **Limit regions** - Only process regions you use
4. **Use dry run** - Test before running on all resources
5. **Archive logs** - Reduce CloudWatch Logs retention period

## Troubleshooting

### Common Issues

**1. Timeout errors**

Increase Lambda timeout:
```bash
aws lambda update-function-configuration \
  --function-name prm-auto-tagger \
  --timeout 900
```

**2. Permission errors**

Ensure IAM role has all required permissions from `lambda-iam-policy.json`.

**3. Out of memory**

Increase memory allocation:
```bash
aws lambda update-function-configuration \
  --function-name prm-auto-tagger \
  --memory-size 1024
```

**4. Some resources not tagged**

Check CloudWatch logs for specific errors. Some resources may require additional permissions or may not support tagging.

### Debugging

**Enable detailed logging:**

Update the function with more verbose logging:
```python
logger.setLevel(logging.DEBUG)
```

**Test locally:**
```bash
python3 -c "
import lambda_function
event = {'dry_run': True, 'regions': ['us-east-1']}
result = lambda_function.lambda_handler(event, None)
print(result)
"
```

## Security Best Practices

1. **Least privilege IAM** - Only grant necessary permissions
2. **Encrypt environment variables** - Use AWS KMS for sensitive data
3. **Enable AWS CloudTrail** - Audit all tagging operations
4. **Use VPC endpoints** - If Lambda is in a VPC
5. **Regular updates** - Keep Lambda runtime updated
6. **Monitor for drift** - Alert on unexpected permission changes

## Maintenance

### Updating the Function

**Update code:**
```bash
# Package new version
zip -r lambda-deployment.zip lambda_function.py

# Update function
aws lambda update-function-code \
  --function-name prm-auto-tagger \
  --zip-file fileb://lambda-deployment.zip
```

**Update configuration:**
```bash
aws lambda update-function-configuration \
  --function-name prm-auto-tagger \
  --environment Variables="{TAG_KEY=new-key,TAG_VALUE=new-value}"
```

### Updating the Schedule

Update CloudFormation stack:
```bash
aws cloudformation update-stack \
  --stack-name prm-auto-tagger \
  --use-previous-template \
  --parameters ParameterKey=ScheduleExpression,ParameterValue="rate(12 hours)" \
  --capabilities CAPABILITY_NAMED_IAM
```

## Advanced Usage

### Multi-Account Deployment

Deploy using StackSets for multiple accounts:

```bash
aws cloudformation create-stack-set \
  --stack-set-name prm-auto-tagger \
  --template-body file://cloudformation-template.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters file://parameters.json

aws cloudformation create-stack-instances \
  --stack-set-name prm-auto-tagger \
  --accounts 111111111111 222222222222 \
  --regions us-east-1
```

### Custom Tagging Logic

Extend `lambda_function.py` to add custom logic:

```python
def should_tag_resource(resource_arn: str) -> bool:
    # Add custom filtering logic
    if 'production' in resource_arn:
        return True
    return False
```

### Integration with Other Services

**Trigger from CloudFormation:**
Add custom resource to tag stack resources immediately.

**Trigger from EventBridge:**
Tag resources when specific events occur (e.g., EC2 instance launch).

**Step Functions orchestration:**
Include as part of larger automation workflows.

## Cleanup

To remove all resources:

```bash
# Delete CloudFormation stack
aws cloudformation delete-stack --stack-name prm-auto-tagger

# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name prm-auto-tagger
```

## Support

- **AWS Documentation:** [Partner Revenue Measurement](https://docs.aws.amazon.com/PRM/latest/aws-prm-onboarding-guide/what-is-service.html)
- **Lambda Documentation:** [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/)
- **Boto3 Documentation:** [AWS SDK for Python](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)

## License

This solution is provided as-is for use with AWS Partner Revenue Measurement requirements.

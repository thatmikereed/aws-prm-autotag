# AWS Partner Revenue Measurement (PRM) Tagging Script

This script automatically identifies and tags AWS resources with the required partner identification tag for AWS Partner Revenue Measurement tracking.

## Tag Information

- **Tag Key:** `aws-apn-id`
- **Tag Value:** `pc:3jtjsihjubajawpl401j5b27s`

## Prerequisites

1. **AWS CLI v2** - Install from https://aws.amazon.com/cli/
2. **Configured AWS credentials** - Run `aws configure` or set environment variables
3. **Appropriate IAM permissions** - See below for required permissions

## Supported AWS Services

This script tags resources across 80+ AWS services as specified in the AWS Partner Revenue Measurement documentation, including:

### Compute
- EC2 instances, EBS volumes, EBS snapshots
- Lambda functions
- ECS clusters and services
- EKS clusters

### Storage
- S3 buckets
- EFS file systems
- FSx file systems
- AWS Backup vaults

### Database
- RDS instances and clusters (all engines)
- DynamoDB tables
- ElastiCache clusters and replication groups
- Redshift clusters
- Neptune clusters
- DocumentDB clusters
- MemoryDB clusters

### Networking & Content Delivery
- Application/Network/Classic Load Balancers
- CloudFront distributions
- Transit Gateways

### Application Integration
- API Gateway (REST and HTTP/WebSocket APIs)
- SNS topics
- SQS queues
- Step Functions state machines

### Analytics
- Kinesis Data Streams
- Athena workgroups
- AWS Glue jobs
- OpenSearch domains
- MSK (Managed Kafka) clusters

### Machine Learning
- SageMaker endpoints and models

### Developer Tools
- ECR repositories
- CodeBuild projects
- CodePipeline pipelines

### Security, Identity & Compliance
- Secrets Manager secrets
- KMS keys (customer-managed only)

### Migration & Transfer
- Database Migration Service (DMS) instances
- DataSync tasks

### End User Computing
- WorkSpaces

## Usage

### Basic Usage

```bash
# Make the script executable
chmod +x aws-prm-tagging.sh

# Run the script
./aws-prm-tagging.sh
```

### Dry Run Mode (Recommended First)

Test the script without actually applying tags:

```bash
DRY_RUN=true ./aws-prm-tagging.sh
```

### Specify a Different Region

```bash
AWS_REGION=us-west-2 ./aws-prm-tagging.sh
```

### Multi-Region Execution

To tag resources across multiple regions, use a wrapper script:

```bash
#!/bin/bash
REGIONS=("us-east-1" "us-west-2" "eu-west-1")

for region in "${REGIONS[@]}"; do
    echo "Processing region: $region"
    AWS_REGION=$region ./aws-prm-tagging.sh
done
```

## Required IAM Permissions

The IAM user or role running this script needs the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "tag:GetResources",
        "tag:TagResources",
        "tag:UntagResources",
        "ec2:DescribeInstances",
        "ec2:DescribeVolumes",
        "ec2:DescribeSnapshots",
        "ec2:DescribeTransitGateways",
        "ec2:CreateTags",
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation",
        "s3:GetBucketTagging",
        "s3:PutBucketTagging",
        "rds:DescribeDBInstances",
        "rds:DescribeDBClusters",
        "rds:AddTagsToResource",
        "lambda:ListFunctions",
        "lambda:TagResource",
        "dynamodb:ListTables",
        "dynamodb:DescribeTable",
        "dynamodb:TagResource",
        "ecs:ListClusters",
        "ecs:ListServices",
        "ecs:TagResource",
        "eks:ListClusters",
        "eks:DescribeCluster",
        "eks:TagResource",
        "elasticache:DescribeCacheClusters",
        "elasticache:DescribeReplicationGroups",
        "elasticache:AddTagsToResource",
        "redshift:DescribeClusters",
        "redshift:CreateTags",
        "cloudfront:ListDistributions",
        "cloudfront:TagResource",
        "apigateway:GET",
        "apigateway:TagResource",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeTags",
        "elasticloadbalancing:AddTags",
        "kinesis:ListStreams",
        "kinesis:AddTagsToStream",
        "sns:ListTopics",
        "sns:TagResource",
        "sqs:ListQueues",
        "sqs:GetQueueAttributes",
        "sqs:TagQueue",
        "states:ListStateMachines",
        "states:TagResource",
        "secretsmanager:ListSecrets",
        "secretsmanager:TagResource",
        "kms:ListKeys",
        "kms:DescribeKey",
        "kms:TagResource",
        "elasticfilesystem:DescribeFileSystems",
        "elasticfilesystem:TagResource",
        "fsx:DescribeFileSystems",
        "fsx:TagResource",
        "backup:ListBackupVaults",
        "backup:TagResource",
        "glue:GetJobs",
        "glue:TagResource",
        "sagemaker:ListEndpoints",
        "sagemaker:ListModels",
        "sagemaker:AddTags",
        "es:ListDomainNames",
        "es:DescribeDomain",
        "es:AddTags",
        "kafka:ListClustersV2",
        "kafka:TagResource",
        "neptune:DescribeDBClusters",
        "neptune:AddTagsToResource",
        "docdb:DescribeDBClusters",
        "docdb:AddTagsToResource",
        "athena:ListWorkGroups",
        "athena:TagResource",
        "ecr:DescribeRepositories",
        "ecr:TagResource",
        "codebuild:ListProjects",
        "codebuild:UpdateProject",
        "codepipeline:ListPipelines",
        "codepipeline:TagResource",
        "dms:DescribeReplicationInstances",
        "dms:AddTagsToResource",
        "datasync:ListTasks",
        "datasync:TagResource",
        "workspaces:DescribeWorkspaces",
        "workspaces:CreateTags",
        "memorydb:DescribeClusters",
        "memorydb:TagResource",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

## Output

The script provides colored output showing:
- **Blue [INFO]** - Informational messages
- **Green [SUCCESS]** - Successfully tagged resources
- **Yellow [WARNING]** - Warnings and dry run notifications
- **Red [ERROR]** - Failed operations

Example output:
```
[INFO] Processing EC2 instances...
[SUCCESS] Tagged EC2 instance: i-1234567890abcdef0
[SUCCESS] Tagged EC2 instance: i-0fedcba0987654321
[INFO] Processing S3 buckets...
[SUCCESS] Tagged S3 bucket: my-application-bucket
...
========================================================================
Summary
========================================================================
Total resources found: 150
Successfully tagged: 148
Failed to tag: 2
========================================================================
```

## Important Notes

1. **Regional Resources**: Most AWS resources are regional. Run the script in each region where you have resources, or use the multi-region wrapper script.

2. **Global Services**: Some services like S3, CloudFront, and IAM are global. The script handles these appropriately.

3. **Existing Tags**: The script adds tags to resources without removing existing tags.

4. **Permissions**: Ensure you have the necessary permissions before running. Use dry run mode to test.

5. **Cost**: There is no cost for tagging resources, but be aware of any API rate limits.

6. **Excluded Resources**: Some resource types within supported services are explicitly excluded per AWS PRM requirements (see the AWS documentation link in the script).

## Troubleshooting

### "Access Denied" errors
- Verify your IAM permissions include all required actions
- Check if there are any SCPs (Service Control Policies) restricting tagging

### Resources not found
- Ensure you're running the script in the correct region
- Some resources might not support tagging via the Resource Groups Tagging API

### Script fails midway
- The script is designed to continue even if individual resources fail
- Check the summary at the end to see which resources failed
- Review error messages for specific issues

## Verification

After running the script, you can verify tags were applied:

```bash
# List all resources with the tag
aws resourcegroupstaggingapi get-resources \
  --tag-filters "Key=aws-apn-id,Values=pc:3jtjsihjubajawpl401j5b27s" \
  --region us-east-1

# Count resources with the tag
aws resourcegroupstaggingapi get-resources \
  --tag-filters "Key=aws-apn-id,Values=pc:3jtjsihjubajawpl401j5b27s" \
  --region us-east-1 \
  --query 'length(ResourceTagMappingList)'
```

## Additional Resources

- [AWS Partner Revenue Measurement Documentation](https://docs.aws.amazon.com/PRM/latest/aws-prm-onboarding-guide/what-is-service.html)
- [AWS Resource Tagging Best Practices](https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/tagging-best-practices.html)
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)

## Support

For issues related to:
- **AWS Partner Revenue Measurement**: Contact AWS Partner Support
- **This script**: Review the script code and modify as needed for your environment
- **AWS CLI**: Refer to AWS CLI documentation

## License

This script is provided as-is for use with AWS Partner Revenue Measurement requirements.  Consider this as proof-of-concept code, not "production ready."  

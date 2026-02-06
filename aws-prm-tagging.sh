#!/bin/bash

################################################################################
# AWS Partner Revenue Measurement (PRM) Resource Tagging Script
# 
# Purpose: Tag all eligible AWS resources with partner identification tag
# Tag Key: aws-apn-id
# Tag Value: pc:3jtjsihjubajawpl401j5b27s
#
# Requirements:
# - AWS CLI v2 installed and configured
# - Appropriate IAM permissions to list and tag resources
# - jq installed for JSON processing
################################################################################

set -e

# Configuration
TAG_KEY="aws-apn-id"
TAG_VALUE="pc:3jtjsihjubajawpl401j5b27s"
REGION="${AWS_REGION:-$(aws configure get region)}"
DRY_RUN="${DRY_RUN:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_RESOURCES=0
TAGGED_RESOURCES=0
FAILED_RESOURCES=0

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

tag_resource() {
    local resource_arn="$1"
    local service_name="$2"
    
    TOTAL_RESOURCES=$((TOTAL_RESOURCES + 1))
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would tag: $resource_arn"
        return 0
    fi
    
    if aws resourcegroupstaggingapi tag-resources \
        --resource-arn-list "$resource_arn" \
        --tags "${TAG_KEY}=${TAG_VALUE}" \
        --region "$REGION" 2>/dev/null; then
        log_success "Tagged $service_name: $resource_arn"
        TAGGED_RESOURCES=$((TAGGED_RESOURCES + 1))
        return 0
    else
        log_error "Failed to tag $service_name: $resource_arn"
        FAILED_RESOURCES=$((FAILED_RESOURCES + 1))
        return 1
    fi
}

################################################################################
# Service-Specific Tagging Functions
################################################################################

tag_ec2_instances() {
    log_info "Processing EC2 instances..."
    local instances=$(aws ec2 describe-instances \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for instance in $instances; do
        if [ -n "$instance" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would tag EC2 instance: $instance"
                TOTAL_RESOURCES=$((TOTAL_RESOURCES + 1))
            else
                aws ec2 create-tags \
                    --resources "$instance" \
                    --tags "Key=${TAG_KEY},Value=${TAG_VALUE}" \
                    --region "$REGION" 2>/dev/null && \
                    log_success "Tagged EC2 instance: $instance" && \
                    TAGGED_RESOURCES=$((TAGGED_RESOURCES + 1)) || \
                    log_error "Failed to tag EC2 instance: $instance" && \
                    FAILED_RESOURCES=$((FAILED_RESOURCES + 1))
                TOTAL_RESOURCES=$((TOTAL_RESOURCES + 1))
            fi
        fi
    done
}

tag_ebs_volumes() {
    log_info "Processing EBS volumes..."
    local volumes=$(aws ec2 describe-volumes \
        --query 'Volumes[].VolumeId' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for volume in $volumes; do
        if [ -n "$volume" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would tag EBS volume: $volume"
                TOTAL_RESOURCES=$((TOTAL_RESOURCES + 1))
            else
                aws ec2 create-tags \
                    --resources "$volume" \
                    --tags "Key=${TAG_KEY},Value=${TAG_VALUE}" \
                    --region "$REGION" 2>/dev/null && \
                    log_success "Tagged EBS volume: $volume" && \
                    TAGGED_RESOURCES=$((TAGGED_RESOURCES + 1)) || \
                    log_error "Failed to tag EBS volume: $volume" && \
                    FAILED_RESOURCES=$((FAILED_RESOURCES + 1))
                TOTAL_RESOURCES=$((TOTAL_RESOURCES + 1))
            fi
        fi
    done
}

tag_ebs_snapshots() {
    log_info "Processing EBS snapshots..."
    local snapshots=$(aws ec2 describe-snapshots \
        --owner-ids self \
        --query 'Snapshots[].SnapshotId' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for snapshot in $snapshots; do
        if [ -n "$snapshot" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would tag EBS snapshot: $snapshot"
                TOTAL_RESOURCES=$((TOTAL_RESOURCES + 1))
            else
                aws ec2 create-tags \
                    --resources "$snapshot" \
                    --tags "Key=${TAG_KEY},Value=${TAG_VALUE}" \
                    --region "$REGION" 2>/dev/null && \
                    log_success "Tagged EBS snapshot: $snapshot" && \
                    TAGGED_RESOURCES=$((TAGGED_RESOURCES + 1)) || \
                    log_error "Failed to tag EBS snapshot: $snapshot" && \
                    FAILED_RESOURCES=$((FAILED_RESOURCES + 1))
                TOTAL_RESOURCES=$((TOTAL_RESOURCES + 1))
            fi
        fi
    done
}

tag_s3_buckets() {
    log_info "Processing S3 buckets..."
    local buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null || echo "")
    
    for bucket in $buckets; do
        if [ -n "$bucket" ]; then
            # Check bucket region
            bucket_region=$(aws s3api get-bucket-location --bucket "$bucket" --output text 2>/dev/null || echo "us-east-1")
            [ "$bucket_region" = "None" ] && bucket_region="us-east-1"
            
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would tag S3 bucket: $bucket"
                TOTAL_RESOURCES=$((TOTAL_RESOURCES + 1))
            else
                aws s3api put-bucket-tagging \
                    --bucket "$bucket" \
                    --tagging "TagSet=[{Key=${TAG_KEY},Value=${TAG_VALUE}}]" \
                    --region "$bucket_region" 2>/dev/null && \
                    log_success "Tagged S3 bucket: $bucket" && \
                    TAGGED_RESOURCES=$((TAGGED_RESOURCES + 1)) || \
                    log_error "Failed to tag S3 bucket: $bucket" && \
                    FAILED_RESOURCES=$((FAILED_RESOURCES + 1))
                TOTAL_RESOURCES=$((TOTAL_RESOURCES + 1))
            fi
        fi
    done
}

tag_rds_instances() {
    log_info "Processing RDS instances..."
    local db_instances=$(aws rds describe-db-instances \
        --query 'DBInstances[].DBInstanceArn' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $db_instances; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "RDS Instance"
        fi
    done
}

tag_rds_clusters() {
    log_info "Processing RDS clusters..."
    local clusters=$(aws rds describe-db-clusters \
        --query 'DBClusters[].DBClusterArn' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $clusters; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "RDS Cluster"
        fi
    done
}

tag_lambda_functions() {
    log_info "Processing Lambda functions..."
    local functions=$(aws lambda list-functions \
        --query 'Functions[].FunctionArn' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $functions; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "Lambda Function"
        fi
    done
}

tag_dynamodb_tables() {
    log_info "Processing DynamoDB tables..."
    local tables=$(aws dynamodb list-tables \
        --query 'TableNames[]' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for table in $tables; do
        if [ -n "$table" ]; then
            local arn=$(aws dynamodb describe-table \
                --table-name "$table" \
                --query 'Table.TableArn' \
                --output text \
                --region "$REGION" 2>/dev/null || echo "")
            if [ -n "$arn" ]; then
                tag_resource "$arn" "DynamoDB Table"
            fi
        fi
    done
}

tag_ecs_clusters() {
    log_info "Processing ECS clusters..."
    local clusters=$(aws ecs list-clusters \
        --query 'clusterArns[]' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $clusters; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "ECS Cluster"
        fi
    done
}

tag_ecs_services() {
    log_info "Processing ECS services..."
    local clusters=$(aws ecs list-clusters \
        --query 'clusterArns[]' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for cluster in $clusters; do
        local services=$(aws ecs list-services \
            --cluster "$cluster" \
            --query 'serviceArns[]' \
            --output text \
            --region "$REGION" 2>/dev/null || echo "")
        
        for arn in $services; do
            if [ -n "$arn" ]; then
                tag_resource "$arn" "ECS Service"
            fi
        done
    done
}

tag_eks_clusters() {
    log_info "Processing EKS clusters..."
    local clusters=$(aws eks list-clusters \
        --query 'clusters[]' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for cluster in $clusters; do
        if [ -n "$cluster" ]; then
            local arn=$(aws eks describe-cluster \
                --name "$cluster" \
                --query 'cluster.arn' \
                --output text \
                --region "$REGION" 2>/dev/null || echo "")
            if [ -n "$arn" ]; then
                tag_resource "$arn" "EKS Cluster"
            fi
        fi
    done
}

tag_elasticache_clusters() {
    log_info "Processing ElastiCache clusters..."
    local clusters=$(aws elasticache describe-cache-clusters \
        --query 'CacheClusters[].ARN' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $clusters; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "ElastiCache Cluster"
        fi
    done
}

tag_elasticache_replication_groups() {
    log_info "Processing ElastiCache replication groups..."
    local groups=$(aws elasticache describe-replication-groups \
        --query 'ReplicationGroups[].ARN' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $groups; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "ElastiCache Replication Group"
        fi
    done
}

tag_redshift_clusters() {
    log_info "Processing Redshift clusters..."
    local clusters=$(aws redshift describe-clusters \
        --query 'Clusters[].ClusterIdentifier' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for cluster in $clusters; do
        if [ -n "$cluster" ]; then
            # Construct ARN
            local account_id=$(aws sts get-caller-identity --query Account --output text)
            local arn="arn:aws:redshift:${REGION}:${account_id}:cluster:${cluster}"
            tag_resource "$arn" "Redshift Cluster"
        fi
    done
}

tag_cloudfront_distributions() {
    log_info "Processing CloudFront distributions..."
    local distributions=$(aws cloudfront list-distributions \
        --query 'DistributionList.Items[].ARN' \
        --output text 2>/dev/null || echo "")
    
    for arn in $distributions; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "CloudFront Distribution"
        fi
    done
}

tag_api_gateway_apis() {
    log_info "Processing API Gateway REST APIs..."
    local apis=$(aws apigateway get-rest-apis \
        --query 'items[].id' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for api_id in $apis; do
        if [ -n "$api_id" ]; then
            local account_id=$(aws sts get-caller-identity --query Account --output text)
            local arn="arn:aws:apigateway:${REGION}::/restapis/${api_id}"
            tag_resource "$arn" "API Gateway REST API"
        fi
    done
}

tag_api_gateway_v2_apis() {
    log_info "Processing API Gateway V2 APIs (HTTP/WebSocket)..."
    local apis=$(aws apigatewayv2 get-apis \
        --query 'Items[].ApiId' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for api_id in $apis; do
        if [ -n "$api_id" ]; then
            local account_id=$(aws sts get-caller-identity --query Account --output text)
            local arn="arn:aws:apigateway:${REGION}::/apis/${api_id}"
            tag_resource "$arn" "API Gateway V2 API"
        fi
    done
}

tag_load_balancers() {
    log_info "Processing Application/Network Load Balancers..."
    local lbs=$(aws elbv2 describe-load-balancers \
        --query 'LoadBalancers[].LoadBalancerArn' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $lbs; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "Load Balancer (ALB/NLB)"
        fi
    done
}

tag_classic_load_balancers() {
    log_info "Processing Classic Load Balancers..."
    local lbs=$(aws elb describe-load-balancers \
        --query 'LoadBalancerDescriptions[].LoadBalancerName' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for lb_name in $lbs; do
        if [ -n "$lb_name" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would tag Classic Load Balancer: $lb_name"
                TOTAL_RESOURCES=$((TOTAL_RESOURCES + 1))
            else
                aws elb add-tags \
                    --load-balancer-names "$lb_name" \
                    --tags "Key=${TAG_KEY},Value=${TAG_VALUE}" \
                    --region "$REGION" 2>/dev/null && \
                    log_success "Tagged Classic Load Balancer: $lb_name" && \
                    TAGGED_RESOURCES=$((TAGGED_RESOURCES + 1)) || \
                    log_error "Failed to tag Classic Load Balancer: $lb_name" && \
                    FAILED_RESOURCES=$((FAILED_RESOURCES + 1))
                TOTAL_RESOURCES=$((TOTAL_RESOURCES + 1))
            fi
        fi
    done
}

tag_kinesis_streams() {
    log_info "Processing Kinesis Data Streams..."
    local streams=$(aws kinesis list-streams \
        --query 'StreamNames[]' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for stream in $streams; do
        if [ -n "$stream" ]; then
            local account_id=$(aws sts get-caller-identity --query Account --output text)
            local arn="arn:aws:kinesis:${REGION}:${account_id}:stream/${stream}"
            tag_resource "$arn" "Kinesis Stream"
        fi
    done
}

tag_sns_topics() {
    log_info "Processing SNS topics..."
    local topics=$(aws sns list-topics \
        --query 'Topics[].TopicArn' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $topics; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "SNS Topic"
        fi
    done
}

tag_sqs_queues() {
    log_info "Processing SQS queues..."
    local queues=$(aws sqs list-queues \
        --query 'QueueUrls[]' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for queue_url in $queues; do
        if [ -n "$queue_url" ]; then
            local arn=$(aws sqs get-queue-attributes \
                --queue-url "$queue_url" \
                --attribute-names QueueArn \
                --query 'Attributes.QueueArn' \
                --output text \
                --region "$REGION" 2>/dev/null || echo "")
            if [ -n "$arn" ]; then
                tag_resource "$arn" "SQS Queue"
            fi
        fi
    done
}

tag_step_functions() {
    log_info "Processing Step Functions state machines..."
    local state_machines=$(aws stepfunctions list-state-machines \
        --query 'stateMachines[].stateMachineArn' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $state_machines; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "Step Functions State Machine"
        fi
    done
}

tag_secrets_manager() {
    log_info "Processing Secrets Manager secrets..."
    local secrets=$(aws secretsmanager list-secrets \
        --query 'SecretList[].ARN' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $secrets; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "Secrets Manager Secret"
        fi
    done
}

tag_kms_keys() {
    log_info "Processing KMS keys..."
    local keys=$(aws kms list-keys \
        --query 'Keys[].KeyId' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for key_id in $keys; do
        if [ -n "$key_id" ]; then
            # Check if key is customer managed
            local key_manager=$(aws kms describe-key \
                --key-id "$key_id" \
                --query 'KeyMetadata.KeyManager' \
                --output text \
                --region "$REGION" 2>/dev/null || echo "")
            
            if [ "$key_manager" = "CUSTOMER" ]; then
                local arn=$(aws kms describe-key \
                    --key-id "$key_id" \
                    --query 'KeyMetadata.Arn' \
                    --output text \
                    --region "$REGION" 2>/dev/null || echo "")
                if [ -n "$arn" ]; then
                    tag_resource "$arn" "KMS Key"
                fi
            fi
        fi
    done
}

tag_efs_filesystems() {
    log_info "Processing EFS file systems..."
    local filesystems=$(aws efs describe-file-systems \
        --query 'FileSystems[].FileSystemId' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for fs_id in $filesystems; do
        if [ -n "$fs_id" ]; then
            local account_id=$(aws sts get-caller-identity --query Account --output text)
            local arn="arn:aws:elasticfilesystem:${REGION}:${account_id}:file-system/${fs_id}"
            tag_resource "$arn" "EFS File System"
        fi
    done
}

tag_fsx_filesystems() {
    log_info "Processing FSx file systems..."
    local filesystems=$(aws fsx describe-file-systems \
        --query 'FileSystems[].ResourceARN' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $filesystems; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "FSx File System"
        fi
    done
}

tag_backup_vaults() {
    log_info "Processing AWS Backup vaults..."
    local vaults=$(aws backup list-backup-vaults \
        --query 'BackupVaultList[].BackupVaultArn' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $vaults; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "Backup Vault"
        fi
    done
}

tag_glue_jobs() {
    log_info "Processing AWS Glue jobs..."
    local jobs=$(aws glue get-jobs \
        --query 'Jobs[].Name' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for job_name in $jobs; do
        if [ -n "$job_name" ]; then
            local account_id=$(aws sts get-caller-identity --query Account --output text)
            local arn="arn:aws:glue:${REGION}:${account_id}:job/${job_name}"
            tag_resource "$arn" "Glue Job"
        fi
    done
}

tag_sagemaker_endpoints() {
    log_info "Processing SageMaker endpoints..."
    local endpoints=$(aws sagemaker list-endpoints \
        --query 'Endpoints[].EndpointArn' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $endpoints; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "SageMaker Endpoint"
        fi
    done
}

tag_sagemaker_models() {
    log_info "Processing SageMaker models..."
    local models=$(aws sagemaker list-models \
        --query 'Models[].ModelArn' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $models; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "SageMaker Model"
        fi
    done
}

tag_opensearch_domains() {
    log_info "Processing OpenSearch domains..."
    local domains=$(aws opensearch list-domain-names \
        --query 'DomainNames[].DomainName' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for domain in $domains; do
        if [ -n "$domain" ]; then
            local arn=$(aws opensearch describe-domain \
                --domain-name "$domain" \
                --query 'DomainStatus.ARN' \
                --output text \
                --region "$REGION" 2>/dev/null || echo "")
            if [ -n "$arn" ]; then
                tag_resource "$arn" "OpenSearch Domain"
            fi
        fi
    done
}

tag_msk_clusters() {
    log_info "Processing MSK clusters..."
    local clusters=$(aws kafka list-clusters-v2 \
        --query 'ClusterInfoList[].ClusterArn' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $clusters; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "MSK Cluster"
        fi
    done
}

tag_neptune_clusters() {
    log_info "Processing Neptune clusters..."
    local clusters=$(aws neptune describe-db-clusters \
        --query 'DBClusters[].DBClusterArn' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $clusters; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "Neptune Cluster"
        fi
    done
}

tag_documentdb_clusters() {
    log_info "Processing DocumentDB clusters..."
    local clusters=$(aws docdb describe-db-clusters \
        --query 'DBClusters[].DBClusterArn' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $clusters; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "DocumentDB Cluster"
        fi
    done
}

tag_athena_workgroups() {
    log_info "Processing Athena workgroups..."
    local workgroups=$(aws athena list-work-groups \
        --query 'WorkGroups[].Name' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for workgroup in $workgroups; do
        if [ -n "$workgroup" ] && [ "$workgroup" != "primary" ]; then
            local account_id=$(aws sts get-caller-identity --query Account --output text)
            local arn="arn:aws:athena:${REGION}:${account_id}:workgroup/${workgroup}"
            tag_resource "$arn" "Athena Workgroup"
        fi
    done
}

tag_ecr_repositories() {
    log_info "Processing ECR repositories..."
    local repos=$(aws ecr describe-repositories \
        --query 'repositories[].repositoryArn' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $repos; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "ECR Repository"
        fi
    done
}

tag_codebuild_projects() {
    log_info "Processing CodeBuild projects..."
    local projects=$(aws codebuild list-projects \
        --query 'projects[]' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for project in $projects; do
        if [ -n "$project" ]; then
            local account_id=$(aws sts get-caller-identity --query Account --output text)
            local arn="arn:aws:codebuild:${REGION}:${account_id}:project/${project}"
            tag_resource "$arn" "CodeBuild Project"
        fi
    done
}

tag_codepipeline_pipelines() {
    log_info "Processing CodePipeline pipelines..."
    local pipelines=$(aws codepipeline list-pipelines \
        --query 'pipelines[].name' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for pipeline in $pipelines; do
        if [ -n "$pipeline" ]; then
            local account_id=$(aws sts get-caller-identity --query Account --output text)
            local arn="arn:aws:codepipeline:${REGION}:${account_id}:${pipeline}"
            tag_resource "$arn" "CodePipeline Pipeline"
        fi
    done
}

tag_transit_gateways() {
    log_info "Processing Transit Gateways..."
    local tgws=$(aws ec2 describe-transit-gateways \
        --query 'TransitGateways[].TransitGatewayId' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for tgw_id in $tgws; do
        if [ -n "$tgw_id" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would tag Transit Gateway: $tgw_id"
                TOTAL_RESOURCES=$((TOTAL_RESOURCES + 1))
            else
                aws ec2 create-tags \
                    --resources "$tgw_id" \
                    --tags "Key=${TAG_KEY},Value=${TAG_VALUE}" \
                    --region "$REGION" 2>/dev/null && \
                    log_success "Tagged Transit Gateway: $tgw_id" && \
                    TAGGED_RESOURCES=$((TAGGED_RESOURCES + 1)) || \
                    log_error "Failed to tag Transit Gateway: $tgw_id" && \
                    FAILED_RESOURCES=$((FAILED_RESOURCES + 1))
                TOTAL_RESOURCES=$((TOTAL_RESOURCES + 1))
            fi
        fi
    done
}

tag_dms_instances() {
    log_info "Processing DMS replication instances..."
    local instances=$(aws dms describe-replication-instances \
        --query 'ReplicationInstances[].ReplicationInstanceArn' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $instances; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "DMS Replication Instance"
        fi
    done
}

tag_datasync_tasks() {
    log_info "Processing DataSync tasks..."
    local tasks=$(aws datasync list-tasks \
        --query 'Tasks[].TaskArn' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $tasks; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "DataSync Task"
        fi
    done
}

tag_workspaces() {
    log_info "Processing WorkSpaces..."
    local workspaces=$(aws workspaces describe-workspaces \
        --query 'Workspaces[].WorkspaceId' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for ws_id in $workspaces; do
        if [ -n "$ws_id" ]; then
            local account_id=$(aws sts get-caller-identity --query Account --output text)
            local arn="arn:aws:workspaces:${REGION}:${account_id}:workspace/${ws_id}"
            tag_resource "$arn" "WorkSpace"
        fi
    done
}

tag_memorydb_clusters() {
    log_info "Processing MemoryDB clusters..."
    local clusters=$(aws memorydb describe-clusters \
        --query 'Clusters[].ARN' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for arn in $clusters; do
        if [ -n "$arn" ]; then
            tag_resource "$arn" "MemoryDB Cluster"
        fi
    done
}

################################################################################
# Main Execution
################################################################################

main() {
    echo "========================================================================"
    echo "AWS Partner Revenue Measurement (PRM) Tagging Script"
    echo "========================================================================"
    echo "Tag Key: $TAG_KEY"
    echo "Tag Value: $TAG_VALUE"
    echo "Region: $REGION"
    echo "Dry Run: $DRY_RUN"
    echo "========================================================================"
    echo ""
    
    # Check for required tools
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Verify AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are not configured or invalid."
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    log_info "Processing account: $account_id"
    echo ""
    
    # Tag resources by service
    # Compute
    tag_ec2_instances
    tag_lambda_functions
    tag_ecs_clusters
    tag_ecs_services
    tag_eks_clusters
    
    # Storage
    tag_ebs_volumes
    tag_ebs_snapshots
    tag_s3_buckets
    tag_efs_filesystems
    tag_fsx_filesystems
    tag_backup_vaults
    
    # Database
    tag_rds_instances
    tag_rds_clusters
    tag_dynamodb_tables
    tag_elasticache_clusters
    tag_elasticache_replication_groups
    tag_redshift_clusters
    tag_neptune_clusters
    tag_documentdb_clusters
    tag_memorydb_clusters
    
    # Networking
    tag_load_balancers
    tag_classic_load_balancers
    tag_cloudfront_distributions
    tag_transit_gateways
    
    # Application Integration
    tag_api_gateway_apis
    tag_api_gateway_v2_apis
    tag_sns_topics
    tag_sqs_queues
    tag_step_functions
    
    # Analytics
    tag_kinesis_streams
    tag_athena_workgroups
    tag_glue_jobs
    tag_opensearch_domains
    tag_msk_clusters
    
    # Machine Learning
    tag_sagemaker_endpoints
    tag_sagemaker_models
    
    # Developer Tools
    tag_ecr_repositories
    tag_codebuild_projects
    tag_codepipeline_pipelines
    
    # Security & Management
    tag_secrets_manager
    tag_kms_keys
    
    # Migration & Transfer
    tag_dms_instances
    tag_datasync_tasks
    
    # End User Computing
    tag_workspaces
    
    # Summary
    echo ""
    echo "========================================================================"
    echo "Summary"
    echo "========================================================================"
    echo "Total resources found: $TOTAL_RESOURCES"
    echo "Successfully tagged: $TAGGED_RESOURCES"
    echo "Failed to tag: $FAILED_RESOURCES"
    echo "========================================================================"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo ""
        log_warning "DRY RUN MODE - No resources were actually tagged"
        echo "To apply tags, run without DRY_RUN=true"
    fi
}

# Run main function
main "$@"

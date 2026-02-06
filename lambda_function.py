"""
AWS Partner Revenue Measurement (PRM) Auto-Tagging Lambda Function

This Lambda function automatically tags AWS resources with the required
partner identification tag for revenue measurement tracking.

Tag Key: aws-apn-id
Tag Value: pc:3jtjsihjubajawpl401j5b27s

Environment Variables:
    TAG_KEY: Override default tag key (default: aws-apn-id)
    TAG_VALUE: Override default tag value (default: pc:3jtjsihjubajawpl401j5b27s)
    DRY_RUN: Set to 'true' to test without applying tags (default: false)
    TARGET_REGIONS: Comma-separated list of regions to process (default: current region only)
    
Event Payload (optional):
    {
        "dry_run": true,
        "regions": ["us-east-1", "us-west-2"],
        "services": ["ec2", "s3", "lambda"]  // Optional: limit to specific services
    }
"""

import os
import json
import boto3
import logging
from typing import List, Dict, Any, Optional
from botocore.exceptions import ClientError
from concurrent.futures import ThreadPoolExecutor, as_completed

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Configuration
TAG_KEY = os.environ.get('TAG_KEY', 'aws-apn-id')
TAG_VALUE = os.environ.get('TAG_VALUE', 'pc:3jtjsihjubajawpl401j5b27s')
DRY_RUN = os.environ.get('DRY_RUN', 'false').lower() == 'true'

class ResourceTagger:
    """Handle tagging operations for AWS resources"""
    
    def __init__(self, region: str, tag_key: str, tag_value: str, dry_run: bool = False):
        self.region = region
        self.tag_key = tag_key
        self.tag_value = tag_value
        self.dry_run = dry_run
        self.stats = {
            'total': 0,
            'tagged': 0,
            'failed': 0,
            'skipped': 0
        }
        
        # Initialize clients lazily
        self._clients = {}
    
    def get_client(self, service: str):
        """Get or create boto3 client for service"""
        if service not in self._clients:
            self._clients[service] = boto3.client(service, region_name=self.region)
        return self._clients[service]
    
    def tag_using_resource_groups_api(self, resource_arn: str) -> bool:
        """Tag resource using Resource Groups Tagging API"""
        if self.dry_run:
            logger.info(f"[DRY RUN] Would tag: {resource_arn}")
            self.stats['total'] += 1
            return True
        
        try:
            client = self.get_client('resourcegroupstaggingapi')
            client.tag_resources(
                ResourceARNList=[resource_arn],
                Tags={self.tag_key: self.tag_value}
            )
            logger.info(f"Tagged: {resource_arn}")
            self.stats['total'] += 1
            self.stats['tagged'] += 1
            return True
        except ClientError as e:
            logger.error(f"Failed to tag {resource_arn}: {e}")
            self.stats['total'] += 1
            self.stats['failed'] += 1
            return False
    
    def tag_ec2_resources(self) -> List[str]:
        """Tag EC2 instances, volumes, snapshots, and transit gateways"""
        results = []
        ec2 = self.get_client('ec2')
        
        try:
            # Tag EC2 instances
            instances = ec2.describe_instances()
            for reservation in instances['Reservations']:
                for instance in reservation['Instances']:
                    instance_id = instance['InstanceId']
                    if not self.dry_run:
                        ec2.create_tags(
                            Resources=[instance_id],
                            Tags=[{'Key': self.tag_key, 'Value': self.tag_value}]
                        )
                        logger.info(f"Tagged EC2 instance: {instance_id}")
                        self.stats['tagged'] += 1
                    else:
                        logger.info(f"[DRY RUN] Would tag EC2 instance: {instance_id}")
                    self.stats['total'] += 1
                    results.append(f"ec2-instance:{instance_id}")
            
            # Tag EBS volumes
            volumes = ec2.describe_volumes()
            for volume in volumes['Volumes']:
                volume_id = volume['VolumeId']
                if not self.dry_run:
                    ec2.create_tags(
                        Resources=[volume_id],
                        Tags=[{'Key': self.tag_key, 'Value': self.tag_value}]
                    )
                    logger.info(f"Tagged EBS volume: {volume_id}")
                    self.stats['tagged'] += 1
                else:
                    logger.info(f"[DRY RUN] Would tag EBS volume: {volume_id}")
                self.stats['total'] += 1
                results.append(f"ebs-volume:{volume_id}")
            
            # Tag EBS snapshots (owned by this account)
            snapshots = ec2.describe_snapshots(OwnerIds=['self'])
            for snapshot in snapshots['Snapshots']:
                snapshot_id = snapshot['SnapshotId']
                if not self.dry_run:
                    ec2.create_tags(
                        Resources=[snapshot_id],
                        Tags=[{'Key': self.tag_key, 'Value': self.tag_value}]
                    )
                    logger.info(f"Tagged EBS snapshot: {snapshot_id}")
                    self.stats['tagged'] += 1
                else:
                    logger.info(f"[DRY RUN] Would tag EBS snapshot: {snapshot_id}")
                self.stats['total'] += 1
                results.append(f"ebs-snapshot:{snapshot_id}")
            
            # Tag Transit Gateways
            transit_gateways = ec2.describe_transit_gateways()
            for tgw in transit_gateways['TransitGateways']:
                tgw_id = tgw['TransitGatewayId']
                if not self.dry_run:
                    ec2.create_tags(
                        Resources=[tgw_id],
                        Tags=[{'Key': self.tag_key, 'Value': self.tag_value}]
                    )
                    logger.info(f"Tagged Transit Gateway: {tgw_id}")
                    self.stats['tagged'] += 1
                else:
                    logger.info(f"[DRY RUN] Would tag Transit Gateway: {tgw_id}")
                self.stats['total'] += 1
                results.append(f"transit-gateway:{tgw_id}")
                
        except ClientError as e:
            logger.error(f"Error processing EC2 resources: {e}")
            self.stats['failed'] += 1
        
        return results
    
    def tag_s3_buckets(self) -> List[str]:
        """Tag S3 buckets"""
        results = []
        s3 = self.get_client('s3')
        
        try:
            buckets = s3.list_buckets()
            for bucket in buckets['Buckets']:
                bucket_name = bucket['Name']
                
                try:
                    # Get bucket region
                    location = s3.get_bucket_location(Bucket=bucket_name)
                    bucket_region = location['LocationConstraint'] or 'us-east-1'
                    
                    # Only tag if bucket is in current region or we're processing globally
                    if bucket_region == self.region or bucket_region == 'us-east-1':
                        if not self.dry_run:
                            # Get existing tags
                            try:
                                existing_tags = s3.get_bucket_tagging(Bucket=bucket_name)
                                tag_set = existing_tags['TagSet']
                            except ClientError:
                                tag_set = []
                            
                            # Add our tag
                            tag_set.append({'Key': self.tag_key, 'Value': self.tag_value})
                            
                            s3.put_bucket_tagging(
                                Bucket=bucket_name,
                                Tagging={'TagSet': tag_set}
                            )
                            logger.info(f"Tagged S3 bucket: {bucket_name}")
                            self.stats['tagged'] += 1
                        else:
                            logger.info(f"[DRY RUN] Would tag S3 bucket: {bucket_name}")
                        self.stats['total'] += 1
                        results.append(f"s3-bucket:{bucket_name}")
                except ClientError as e:
                    logger.error(f"Error tagging S3 bucket {bucket_name}: {e}")
                    self.stats['failed'] += 1
        
        except ClientError as e:
            logger.error(f"Error listing S3 buckets: {e}")
            self.stats['failed'] += 1
        
        return results
    
    def tag_lambda_functions(self) -> List[str]:
        """Tag Lambda functions"""
        results = []
        lambda_client = self.get_client('lambda')
        
        try:
            paginator = lambda_client.get_paginator('list_functions')
            for page in paginator.paginate():
                for function in page['Functions']:
                    function_arn = function['FunctionArn']
                    if self.tag_using_resource_groups_api(function_arn):
                        results.append(f"lambda:{function['FunctionName']}")
        except ClientError as e:
            logger.error(f"Error processing Lambda functions: {e}")
            self.stats['failed'] += 1
        
        return results
    
    def tag_rds_resources(self) -> List[str]:
        """Tag RDS instances and clusters"""
        results = []
        rds = self.get_client('rds')
        
        try:
            # Tag DB instances
            paginator = rds.get_paginator('describe_db_instances')
            for page in paginator.paginate():
                for db in page['DBInstances']:
                    db_arn = db['DBInstanceArn']
                    if self.tag_using_resource_groups_api(db_arn):
                        results.append(f"rds-instance:{db['DBInstanceIdentifier']}")
            
            # Tag DB clusters
            paginator = rds.get_paginator('describe_db_clusters')
            for page in paginator.paginate():
                for cluster in page['DBClusters']:
                    cluster_arn = cluster['DBClusterArn']
                    if self.tag_using_resource_groups_api(cluster_arn):
                        results.append(f"rds-cluster:{cluster['DBClusterIdentifier']}")
                        
        except ClientError as e:
            logger.error(f"Error processing RDS resources: {e}")
            self.stats['failed'] += 1
        
        return results
    
    def tag_dynamodb_tables(self) -> List[str]:
        """Tag DynamoDB tables"""
        results = []
        dynamodb = self.get_client('dynamodb')
        
        try:
            paginator = dynamodb.get_paginator('list_tables')
            for page in paginator.paginate():
                for table_name in page['TableNames']:
                    table = dynamodb.describe_table(TableName=table_name)
                    table_arn = table['Table']['TableArn']
                    if self.tag_using_resource_groups_api(table_arn):
                        results.append(f"dynamodb:{table_name}")
        except ClientError as e:
            logger.error(f"Error processing DynamoDB tables: {e}")
            self.stats['failed'] += 1
        
        return results
    
    def tag_ecs_resources(self) -> List[str]:
        """Tag ECS clusters and services"""
        results = []
        ecs = self.get_client('ecs')
        
        try:
            # Tag clusters
            cluster_paginator = ecs.get_paginator('list_clusters')
            for page in cluster_paginator.paginate():
                for cluster_arn in page['clusterArns']:
                    if self.tag_using_resource_groups_api(cluster_arn):
                        results.append(f"ecs-cluster:{cluster_arn.split('/')[-1]}")
                    
                    # Tag services in each cluster
                    service_paginator = ecs.get_paginator('list_services')
                    for service_page in service_paginator.paginate(cluster=cluster_arn):
                        for service_arn in service_page['serviceArns']:
                            if self.tag_using_resource_groups_api(service_arn):
                                results.append(f"ecs-service:{service_arn.split('/')[-1]}")
        except ClientError as e:
            logger.error(f"Error processing ECS resources: {e}")
            self.stats['failed'] += 1
        
        return results
    
    def tag_eks_clusters(self) -> List[str]:
        """Tag EKS clusters"""
        results = []
        eks = self.get_client('eks')
        
        try:
            paginator = eks.get_paginator('list_clusters')
            for page in paginator.paginate():
                for cluster_name in page['clusters']:
                    cluster = eks.describe_cluster(name=cluster_name)
                    cluster_arn = cluster['cluster']['arn']
                    if self.tag_using_resource_groups_api(cluster_arn):
                        results.append(f"eks:{cluster_name}")
        except ClientError as e:
            logger.error(f"Error processing EKS clusters: {e}")
            self.stats['failed'] += 1
        
        return results
    
    def tag_elasticache_resources(self) -> List[str]:
        """Tag ElastiCache clusters and replication groups"""
        results = []
        elasticache = self.get_client('elasticache')
        
        try:
            # Tag cache clusters
            paginator = elasticache.get_paginator('describe_cache_clusters')
            for page in paginator.paginate():
                for cluster in page['CacheClusters']:
                    if 'ARN' in cluster:
                        if self.tag_using_resource_groups_api(cluster['ARN']):
                            results.append(f"elasticache-cluster:{cluster['CacheClusterId']}")
            
            # Tag replication groups
            paginator = elasticache.get_paginator('describe_replication_groups')
            for page in paginator.paginate():
                for rg in page['ReplicationGroups']:
                    if 'ARN' in rg:
                        if self.tag_using_resource_groups_api(rg['ARN']):
                            results.append(f"elasticache-rg:{rg['ReplicationGroupId']}")
        except ClientError as e:
            logger.error(f"Error processing ElastiCache resources: {e}")
            self.stats['failed'] += 1
        
        return results
    
    def tag_load_balancers(self) -> List[str]:
        """Tag Application/Network and Classic Load Balancers"""
        results = []
        
        try:
            # ALB/NLB
            elbv2 = self.get_client('elbv2')
            paginator = elbv2.get_paginator('describe_load_balancers')
            for page in paginator.paginate():
                for lb in page['LoadBalancers']:
                    if self.tag_using_resource_groups_api(lb['LoadBalancerArn']):
                        results.append(f"alb-nlb:{lb['LoadBalancerName']}")
            
            # Classic ELB
            elb = self.get_client('elb')
            paginator = elb.get_paginator('describe_load_balancers')
            for page in paginator.paginate():
                for lb in page['LoadBalancerDescriptions']:
                    lb_name = lb['LoadBalancerName']
                    if not self.dry_run:
                        elb.add_tags(
                            LoadBalancerNames=[lb_name],
                            Tags=[{'Key': self.tag_key, 'Value': self.tag_value}]
                        )
                        logger.info(f"Tagged Classic LB: {lb_name}")
                        self.stats['tagged'] += 1
                    else:
                        logger.info(f"[DRY RUN] Would tag Classic LB: {lb_name}")
                    self.stats['total'] += 1
                    results.append(f"classic-lb:{lb_name}")
        except ClientError as e:
            logger.error(f"Error processing Load Balancers: {e}")
            self.stats['failed'] += 1
        
        return results
    
    def tag_additional_services(self) -> List[str]:
        """Tag other supported services"""
        results = []
        
        # SNS Topics
        try:
            sns = self.get_client('sns')
            paginator = sns.get_paginator('list_topics')
            for page in paginator.paginate():
                for topic in page['Topics']:
                    if self.tag_using_resource_groups_api(topic['TopicArn']):
                        results.append(f"sns:{topic['TopicArn'].split(':')[-1]}")
        except ClientError as e:
            logger.error(f"Error processing SNS topics: {e}")
        
        # SQS Queues
        try:
            sqs = self.get_client('sqs')
            paginator = sqs.get_paginator('list_queues')
            for page in paginator.paginate():
                for queue_url in page.get('QueueUrls', []):
                    attrs = sqs.get_queue_attributes(QueueUrl=queue_url, AttributeNames=['QueueArn'])
                    queue_arn = attrs['Attributes']['QueueArn']
                    if self.tag_using_resource_groups_api(queue_arn):
                        results.append(f"sqs:{queue_url.split('/')[-1]}")
        except ClientError as e:
            logger.error(f"Error processing SQS queues: {e}")
        
        # Step Functions
        try:
            sfn = self.get_client('stepfunctions')
            paginator = sfn.get_paginator('list_state_machines')
            for page in paginator.paginate():
                for sm in page['stateMachines']:
                    if self.tag_using_resource_groups_api(sm['stateMachineArn']):
                        results.append(f"stepfunctions:{sm['name']}")
        except ClientError as e:
            logger.error(f"Error processing Step Functions: {e}")
        
        # Secrets Manager
        try:
            sm = self.get_client('secretsmanager')
            paginator = sm.get_paginator('list_secrets')
            for page in paginator.paginate():
                for secret in page['SecretList']:
                    if self.tag_using_resource_groups_api(secret['ARN']):
                        results.append(f"secret:{secret['Name']}")
        except ClientError as e:
            logger.error(f"Error processing Secrets Manager: {e}")
        
        # EFS File Systems
        try:
            efs = self.get_client('efs')
            paginator = efs.get_paginator('describe_file_systems')
            for page in paginator.paginate():
                for fs in page['FileSystems']:
                    # Construct ARN
                    sts = boto3.client('sts')
                    account_id = sts.get_caller_identity()['Account']
                    fs_arn = f"arn:aws:elasticfilesystem:{self.region}:{account_id}:file-system/{fs['FileSystemId']}"
                    if self.tag_using_resource_groups_api(fs_arn):
                        results.append(f"efs:{fs['FileSystemId']}")
        except ClientError as e:
            logger.error(f"Error processing EFS: {e}")
        
        return results
    
    def tag_all_resources(self, services: Optional[List[str]] = None) -> Dict[str, Any]:
        """Tag all supported resources"""
        all_results = {}
        
        service_methods = {
            'ec2': self.tag_ec2_resources,
            's3': self.tag_s3_buckets,
            'lambda': self.tag_lambda_functions,
            'rds': self.tag_rds_resources,
            'dynamodb': self.tag_dynamodb_tables,
            'ecs': self.tag_ecs_resources,
            'eks': self.tag_eks_clusters,
            'elasticache': self.tag_elasticache_resources,
            'elb': self.tag_load_balancers,
            'additional': self.tag_additional_services
        }
        
        # If services specified, filter to those
        if services:
            service_methods = {k: v for k, v in service_methods.items() if k in services}
        
        for service_name, method in service_methods.items():
            logger.info(f"Processing {service_name} resources in {self.region}...")
            try:
                results = method()
                all_results[service_name] = results
            except Exception as e:
                logger.error(f"Unexpected error processing {service_name}: {e}")
                self.stats['failed'] += 1
        
        return {
            'region': self.region,
            'resources': all_results,
            'statistics': self.stats
        }


def process_region(region: str, tag_key: str, tag_value: str, dry_run: bool, services: Optional[List[str]] = None) -> Dict[str, Any]:
    """Process a single region"""
    logger.info(f"Starting processing for region: {region}")
    tagger = ResourceTagger(region, tag_key, tag_value, dry_run)
    result = tagger.tag_all_resources(services)
    logger.info(f"Completed region {region}: {result['statistics']}")
    return result


def lambda_handler(event, context):
    """
    Lambda handler function
    
    Event payload:
    {
        "dry_run": true,  // Optional: override environment variable
        "regions": ["us-east-1", "us-west-2"],  // Optional: specific regions
        "services": ["ec2", "s3", "lambda"]  // Optional: specific services
    }
    """
    logger.info(f"Event received: {json.dumps(event)}")
    
    # Get configuration from event or environment
    dry_run = event.get('dry_run', DRY_RUN)
    tag_key = event.get('tag_key', TAG_KEY)
    tag_value = event.get('tag_value', TAG_VALUE)
    services = event.get('services')  # Optional filter
    
    # Determine regions to process
    if 'regions' in event:
        regions = event['regions']
    elif 'TARGET_REGIONS' in os.environ:
        regions = os.environ['TARGET_REGIONS'].split(',')
    else:
        # Default to current region
        regions = [os.environ.get('AWS_REGION', 'us-east-1')]
    
    logger.info(f"Processing regions: {regions}")
    logger.info(f"Dry run mode: {dry_run}")
    logger.info(f"Tag: {tag_key}={tag_value}")
    
    # Process regions in parallel
    results = []
    with ThreadPoolExecutor(max_workers=min(len(regions), 5)) as executor:
        futures = {
            executor.submit(process_region, region, tag_key, tag_value, dry_run, services): region 
            for region in regions
        }
        
        for future in as_completed(futures):
            region = futures[future]
            try:
                result = future.result()
                results.append(result)
            except Exception as e:
                logger.error(f"Failed to process region {region}: {e}")
                results.append({
                    'region': region,
                    'error': str(e),
                    'statistics': {'total': 0, 'tagged': 0, 'failed': 1}
                })
    
    # Aggregate statistics
    total_stats = {
        'total': sum(r['statistics']['total'] for r in results),
        'tagged': sum(r['statistics']['tagged'] for r in results),
        'failed': sum(r['statistics']['failed'] for r in results)
    }
    
    response = {
        'statusCode': 200,
        'body': {
            'message': 'AWS PRM tagging completed',
            'dry_run': dry_run,
            'regions_processed': len(regions),
            'total_statistics': total_stats,
            'region_details': results
        }
    }
    
    logger.info(f"Final statistics: {total_stats}")
    
    return response

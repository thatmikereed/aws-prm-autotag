#!/bin/bash

################################################################################
# AWS Lambda Deployment Script for PRM Tagging
#
# This script packages and deploys the PRM tagging Lambda function
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Configuration
STACK_NAME="${STACK_NAME:-prm-auto-tagger}"
REGION="${AWS_REGION:-us-east-1}"
TAG_KEY="${TAG_KEY:-aws-apn-id}"
TAG_VALUE="${TAG_VALUE:-pc:3jtjsihjubajawpl401j5b27s}"
SCHEDULE="${SCHEDULE:-rate(1 day)}"
ENABLE_SCHEDULE="${ENABLE_SCHEDULE:-true}"

echo "========================================================================"
echo "AWS PRM Tagging Lambda Deployment"
echo "========================================================================"
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Tag: $TAG_KEY=$TAG_VALUE"
echo "Schedule: $SCHEDULE"
echo "========================================================================"
echo ""

# Check prerequisites
log_info "Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed"
    exit 1
fi

if ! command -v zip &> /dev/null; then
    log_error "zip is not installed"
    exit 1
fi

# Verify AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials are not configured"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log_success "AWS Account ID: $ACCOUNT_ID"

# Create deployment package
log_info "Creating Lambda deployment package..."

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copy Lambda function
cp lambda_function.py "$TEMP_DIR/"

# Install dependencies if requirements.txt exists
if [ -f "requirements.txt" ]; then
    log_info "Installing Python dependencies..."
    pip install -r requirements.txt -t "$TEMP_DIR/" --quiet || log_warning "Failed to install dependencies"
fi

# Create ZIP file
cd "$TEMP_DIR"
zip -r lambda-deployment.zip . > /dev/null
cd - > /dev/null

DEPLOYMENT_PACKAGE="$TEMP_DIR/lambda-deployment.zip"
PACKAGE_SIZE=$(du -h "$DEPLOYMENT_PACKAGE" | cut -f1)
log_success "Deployment package created: $PACKAGE_SIZE"

# Upload to S3 (optional but recommended for larger packages)
S3_BUCKET="${S3_BUCKET:-}"
if [ -n "$S3_BUCKET" ]; then
    log_info "Uploading deployment package to S3..."
    S3_KEY="prm-tagger/lambda-deployment-$(date +%Y%m%d-%H%M%S).zip"
    aws s3 cp "$DEPLOYMENT_PACKAGE" "s3://${S3_BUCKET}/${S3_KEY}" --region "$REGION"
    log_success "Uploaded to s3://${S3_BUCKET}/${S3_KEY}"
fi

# Check if stack exists
log_info "Checking if CloudFormation stack exists..."
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" &> /dev/null; then
    OPERATION="update"
    log_info "Stack exists, will update"
else
    OPERATION="create"
    log_info "Stack does not exist, will create"
fi

# Prepare CloudFormation parameters
PARAMETERS="ParameterKey=TagKey,ParameterValue=$TAG_KEY \
            ParameterKey=TagValue,ParameterValue=$TAG_VALUE \
            ParameterKey=ScheduleExpression,ParameterValue=\"$SCHEDULE\" \
            ParameterKey=EnableSchedule,ParameterValue=$ENABLE_SCHEDULE"

# Deploy CloudFormation stack
log_info "Deploying CloudFormation stack..."

if [ "$OPERATION" = "create" ]; then
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://cloudformation-template.yaml \
        --parameters $PARAMETERS \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION" \
        --tags "Key=$TAG_KEY,Value=$TAG_VALUE" "Key=ManagedBy,Value=CloudFormation"
    
    log_info "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
else
    aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://cloudformation-template.yaml \
        --parameters $PARAMETERS \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION" 2>&1 | grep -v "No updates are to be performed" || true
    
    log_info "Waiting for stack update to complete..."
    aws cloudformation wait stack-update-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION" 2>/dev/null || log_warning "Update may have had no changes"
fi

# Get the Lambda function name from stack outputs
log_info "Retrieving stack outputs..."
FUNCTION_NAME=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionName`].OutputValue' \
    --output text)

if [ -z "$FUNCTION_NAME" ]; then
    log_error "Failed to retrieve Lambda function name"
    exit 1
fi

log_success "Lambda function name: $FUNCTION_NAME"

# Update Lambda function code
log_info "Updating Lambda function code..."
aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file "fileb://$DEPLOYMENT_PACKAGE" \
    --region "$REGION" > /dev/null

log_success "Lambda function code updated"

# Wait for function to be ready
log_info "Waiting for function to be ready..."
aws lambda wait function-updated \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION"

log_success "Function is ready"

# Get stack outputs
echo ""
echo "========================================================================"
echo "Deployment Complete!"
echo "========================================================================"

FUNCTION_ARN=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionArn`].OutputValue' \
    --output text)

SNS_TOPIC=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`NotificationTopicArn`].OutputValue' \
    --output text)

echo "Lambda Function ARN: $FUNCTION_ARN"
echo "Function Name: $FUNCTION_NAME"
echo "SNS Topic: $SNS_TOPIC"
echo "Region: $REGION"
echo ""

# Test invocation
log_info "Testing Lambda function with dry run..."
cat > /tmp/test-event.json <<EOF
{
    "dry_run": true,
    "regions": ["$REGION"]
}
EOF

aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload file:///tmp/test-event.json \
    --region "$REGION" \
    /tmp/lambda-response.json > /dev/null

if [ -f /tmp/lambda-response.json ]; then
    log_success "Test invocation successful!"
    echo ""
    echo "Response:"
    cat /tmp/lambda-response.json | python3 -m json.tool 2>/dev/null || cat /tmp/lambda-response.json
    echo ""
fi

# Provide next steps
echo ""
echo "========================================================================"
echo "Next Steps"
echo "========================================================================"
echo ""
echo "1. Subscribe to SNS notifications:"
echo "   aws sns subscribe --topic-arn $SNS_TOPIC --protocol email --notification-endpoint your-email@example.com"
echo ""
echo "2. Manually invoke the function:"
echo "   aws lambda invoke --function-name $FUNCTION_NAME --region $REGION output.json"
echo ""
echo "3. Invoke with custom parameters:"
echo "   aws lambda invoke --function-name $FUNCTION_NAME --region $REGION \\"
echo "     --payload '{\"dry_run\": false, \"regions\": [\"us-east-1\", \"us-west-2\"]}' output.json"
echo ""
echo "4. View logs:"
echo "   aws logs tail /aws/lambda/$FUNCTION_NAME --follow --region $REGION"
echo ""
echo "5. Update schedule:"
echo "   Update the CloudFormation stack with new ScheduleExpression parameter"
echo ""
echo "========================================================================"

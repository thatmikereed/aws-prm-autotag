#!/bin/bash

################################################################################
# AWS PRM Tag Verification Script
#
# This script verifies which resources have been tagged with the PRM tag
# and provides a detailed report
################################################################################

set -e

# Configuration
TAG_KEY="aws-apn-id"
TAG_VALUE="pc:3jtjsihjubajawpl401j5b27s"
REGION="${AWS_REGION:-$(aws configure get region)}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-table}" # table, json, or csv

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

echo "========================================================================"
echo "AWS PRM Tag Verification Script"
echo "========================================================================"
echo "Tag Key: $TAG_KEY"
echo "Tag Value: $TAG_VALUE"
echo "Region: $REGION"
echo "========================================================================"
echo ""

# Check for required tools
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    log_warning "jq is not installed. Some features may be limited."
fi

# Verify AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials are not configured or invalid."
    exit 1
fi

account_id=$(aws sts get-caller-identity --query Account --output text)
log_info "Checking account: $account_id"
log_info "Region: $REGION"
echo ""

# Get all resources with the tag
log_info "Fetching tagged resources..."
tagged_resources=$(aws resourcegroupstaggingapi get-resources \
    --tag-filters "Key=${TAG_KEY},Values=${TAG_VALUE}" \
    --region "$REGION" 2>/dev/null || echo "{}")

# Count total tagged resources
if command -v jq &> /dev/null; then
    total_count=$(echo "$tagged_resources" | jq '.ResourceTagMappingList | length')
else
    total_count=$(aws resourcegroupstaggingapi get-resources \
        --tag-filters "Key=${TAG_KEY},Values=${TAG_VALUE}" \
        --region "$REGION" \
        --query 'length(ResourceTagMappingList)' \
        --output text 2>/dev/null || echo "0")
fi

echo ""
log_success "Found $total_count resources with the PRM tag"
echo ""

if [ "$total_count" -eq 0 ]; then
    log_warning "No resources found with tag ${TAG_KEY}=${TAG_VALUE}"
    exit 0
fi

# Group by service
log_info "Grouping resources by service..."
echo ""

if command -v jq &> /dev/null; then
    # Extract service from ARN and count
    service_counts=$(echo "$tagged_resources" | jq -r '
        .ResourceTagMappingList |
        group_by(.ResourceARN | split(":")[2]) |
        map({
            service: (.[0].ResourceARN | split(":")[2]),
            count: length,
            resources: map(.ResourceARN)
        }) |
        sort_by(.count) |
        reverse
    ')
    
    echo "========================================================================="
    echo "RESOURCES BY SERVICE"
    echo "========================================================================="
    printf "%-30s %s\n" "SERVICE" "COUNT"
    echo "-------------------------------------------------------------------------"
    
    echo "$service_counts" | jq -r '.[] | "\(.service)\t\(.count)"' | while IFS=$'\t' read -r service count; do
        printf "%-30s %d\n" "$service" "$count"
    done
    
    echo "========================================================================="
    echo ""
    
    # Detailed breakdown
    if [ "${DETAILED:-false}" = "true" ]; then
        echo ""
        echo "========================================================================="
        echo "DETAILED RESOURCE LIST"
        echo "========================================================================="
        echo ""
        
        echo "$service_counts" | jq -r '.[] | "\n[\(.service)] - \(.count) resources:\n" + (.resources | join("\n"))' 
        
        echo ""
        echo "========================================================================="
    fi
    
    # Export options
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        output_file="prm-tagged-resources-${REGION}-$(date +%Y%m%d-%H%M%S).json"
        echo "$tagged_resources" > "$output_file"
        log_success "JSON report saved to: $output_file"
    elif [ "$OUTPUT_FORMAT" = "csv" ]; then
        output_file="prm-tagged-resources-${REGION}-$(date +%Y%m%d-%H%M%S).csv"
        echo "Service,ResourceARN" > "$output_file"
        echo "$tagged_resources" | jq -r '.ResourceTagMappingList[] | [(.ResourceARN | split(":")[2]), .ResourceARN] | @csv' >> "$output_file"
        log_success "CSV report saved to: $output_file"
    fi
else
    # Fallback without jq
    log_warning "Install jq for detailed service breakdown"
    
    if [ "$OUTPUT_FORMAT" = "table" ]; then
        echo "All tagged resources:"
        aws resourcegroupstaggingapi get-resources \
            --tag-filters "Key=${TAG_KEY},Values=${TAG_VALUE}" \
            --region "$REGION" \
            --query 'ResourceTagMappingList[].ResourceARN' \
            --output table
    elif [ "$OUTPUT_FORMAT" = "json" ]; then
        output_file="prm-tagged-resources-${REGION}-$(date +%Y%m%d-%H%M%S).json"
        aws resourcegroupstaggingapi get-resources \
            --tag-filters "Key=${TAG_KEY},Values=${TAG_VALUE}" \
            --region "$REGION" > "$output_file"
        log_success "JSON report saved to: $output_file"
    fi
fi

echo ""
echo "========================================================================="
echo "VERIFICATION COMPLETE"
echo "========================================================================="
echo "Total tagged resources in $REGION: $total_count"
echo "========================================================================="
echo ""

# Provide suggestions
echo "Next steps:"
echo "  - To verify tags in other regions, run: AWS_REGION=<region> $0"
echo "  - To export as JSON: OUTPUT_FORMAT=json $0"
echo "  - To export as CSV: OUTPUT_FORMAT=csv $0"
echo "  - To see detailed resource list: DETAILED=true $0"
echo ""

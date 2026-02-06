#!/bin/bash

################################################################################
# Multi-Region AWS PRM Tagging Wrapper Script
#
# This script runs the AWS PRM tagging script across multiple AWS regions
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAGGING_SCRIPT="${SCRIPT_DIR}/aws-prm-tagging.sh"
DRY_RUN="${DRY_RUN:-false}"

# Define regions to process
# Customize this list based on where you have resources
REGIONS=(
    "us-east-1"      # US East (N. Virginia)
    "us-east-2"      # US East (Ohio)
    "us-west-1"      # US West (N. California)
    "us-west-2"      # US West (Oregon)
    "eu-west-1"      # Europe (Ireland)
    "eu-west-2"      # Europe (London)
    "eu-west-3"      # Europe (Paris)
    "eu-central-1"   # Europe (Frankfurt)
    "eu-north-1"     # Europe (Stockholm)
    "ap-south-1"     # Asia Pacific (Mumbai)
    "ap-northeast-1" # Asia Pacific (Tokyo)
    "ap-northeast-2" # Asia Pacific (Seoul)
    "ap-northeast-3" # Asia Pacific (Osaka)
    "ap-southeast-1" # Asia Pacific (Singapore)
    "ap-southeast-2" # Asia Pacific (Sydney)
    "ca-central-1"   # Canada (Central)
    "sa-east-1"      # South America (São Paulo)
)

# You can also limit to specific regions by uncommenting and modifying:
# REGIONS=("us-east-1" "us-west-2" "eu-west-1")

# Summary variables
TOTAL_REGIONS=0
SUCCESSFUL_REGIONS=0
FAILED_REGIONS=0
TOTAL_RESOURCES_ALL_REGIONS=0
TAGGED_RESOURCES_ALL_REGIONS=0
FAILED_RESOURCES_ALL_REGIONS=0

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_region() {
    echo -e "${CYAN}[REGION]${NC} $1"
}

# Check if tagging script exists
if [ ! -f "$TAGGING_SCRIPT" ]; then
    log_error "Tagging script not found at: $TAGGING_SCRIPT"
    exit 1
fi

# Make sure it's executable
chmod +x "$TAGGING_SCRIPT"

echo "========================================================================"
echo "Multi-Region AWS PRM Tagging Script"
echo "========================================================================"
echo "Dry Run: $DRY_RUN"
echo "Regions to process: ${#REGIONS[@]}"
echo "========================================================================"
echo ""

# Process each region
for region in "${REGIONS[@]}"; do
    TOTAL_REGIONS=$((TOTAL_REGIONS + 1))
    
    echo ""
    log_region "========================================"
    log_region "Processing region: $region (${TOTAL_REGIONS}/${#REGIONS[@]})"
    log_region "========================================"
    echo ""
    
    # Run the tagging script for this region
    if AWS_REGION=$region DRY_RUN=$DRY_RUN "$TAGGING_SCRIPT" 2>&1 | tee "/tmp/aws-prm-tag-${region}.log"; then
        SUCCESSFUL_REGIONS=$((SUCCESSFUL_REGIONS + 1))
        log_success "Completed region: $region"
        
        # Extract statistics from log if not in dry run
        if [ "$DRY_RUN" != "true" ]; then
            # Parse the summary from the log
            total=$(grep "Total resources found:" "/tmp/aws-prm-tag-${region}.log" | tail -1 | awk '{print $NF}')
            tagged=$(grep "Successfully tagged:" "/tmp/aws-prm-tag-${region}.log" | tail -1 | awk '{print $NF}')
            failed=$(grep "Failed to tag:" "/tmp/aws-prm-tag-${region}.log" | tail -1 | awk '{print $NF}')
            
            TOTAL_RESOURCES_ALL_REGIONS=$((TOTAL_RESOURCES_ALL_REGIONS + total))
            TAGGED_RESOURCES_ALL_REGIONS=$((TAGGED_RESOURCES_ALL_REGIONS + tagged))
            FAILED_RESOURCES_ALL_REGIONS=$((FAILED_RESOURCES_ALL_REGIONS + failed))
        fi
    else
        FAILED_REGIONS=$((FAILED_REGIONS + 1))
        log_error "Failed to process region: $region"
    fi
    
    # Small delay between regions to avoid API throttling
    sleep 2
done

# Final summary
echo ""
echo ""
echo "========================================================================"
echo "MULTI-REGION SUMMARY"
echo "========================================================================"
echo "Total regions processed: $TOTAL_REGIONS"
echo "Successful regions: $SUCCESSFUL_REGIONS"
echo "Failed regions: $FAILED_REGIONS"

if [ "$DRY_RUN" != "true" ]; then
    echo ""
    echo "RESOURCE SUMMARY (All Regions Combined):"
    echo "Total resources found: $TOTAL_RESOURCES_ALL_REGIONS"
    echo "Successfully tagged: $TAGGED_RESOURCES_ALL_REGIONS"
    echo "Failed to tag: $FAILED_RESOURCES_ALL_REGIONS"
fi

echo "========================================================================"
echo ""

if [ "$DRY_RUN" = "true" ]; then
    echo ""
    log_info "DRY RUN MODE - No resources were actually tagged"
    echo "To apply tags, run without DRY_RUN=true"
    echo ""
fi

# Save combined logs
if [ "$DRY_RUN" != "true" ]; then
    log_info "Individual region logs saved to: /tmp/aws-prm-tag-*.log"
fi

# Exit with error if any regions failed
if [ $FAILED_REGIONS -gt 0 ]; then
    exit 1
fi

exit 0

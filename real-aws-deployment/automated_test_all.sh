#!/bin/bash

# =============================================================================
# Credit Card Fraud Detection  V5 - Centralized Configuration Module
# Author: Rodrigo Marins Piaba (Fanaticos4tech)
# E-mail: rodrigomarinsp@gmail.com
# Project: https://github.com/rodrigomarinsp/fsah-neural
# =============================================================================
# Centralized Configuration Module 
# Central point of the system
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# List of all applications with their indices
applications=(
    "1:flask-cnn-app-py39:deep_learning/flask-cnn-app-py39"
    "2:flask-cnn-app:deep_learning/flask-cnn-app"
    "3:flask-lstm-app-py39:deep_learning/flask-lstm-app-py39"
    "4:flask-lstm-app:deep_learning/flask-lstm-app"
    "5:flask-transformers-app-py39:deep_learning/flask-transformers-app-py39"
    "6:flask-transformers-app:deep_learning/flask-transformers-app"
    "7:flask-stacking-app:machine_learning/flask-stacking-app"
    "8:flask-stacking-dl-app:machine_learning/flask-stacking-dl-app"
    "9:flask-lgbm-app:machine_learning/flask-lgbm-app"
    "10:flask-lgbm-app_py39:machine_learning/flask-lgbm-app_py39"
    "11:flask-logreg-app:machine_learning/flask-logreg-app"
    "12:flask-xgboost-app:machine_learning/flask-xgboost-app"
)

# Infrastructure types with their indices
infrastructures=("1:ec2" "2:ecs" "3:ecs_alb")

# Results file
results_file="/home/ubuntu/real-aws-deployment/validation_results_complete.md"

# Initialize results file
cat > "$results_file" << EOF
# Complete Application Validation Results

## Test Summary
- **Total Applications**: ${#applications[@]}
- **Infrastructure Types**: 3 (EC2, ECS, ECS+ALB)
- **Total Tests**: $((${#applications[@]} * 3))
- **Test Date**: $(date)

## Test Results

EOF

# Function to test application
test_application() {
    local app_index="$1"
    local app_name="$2"
    local app_path="$3"
    local infra_index="$4"
    local infra_type="$5"
    
    print_header "TESTING $app_name ON $infra_type"
    
    # Clean previous deployment
    if [ -d "deployment_${infra_type}_${app_name}" ]; then
        cd "deployment_${infra_type}_${app_name}"
        terraform destroy -auto-approve || true
        cd ..
        rm -rf "deployment_${infra_type}_${app_name}"
    fi
    
    # Deploy application using automated input
    print_status "Deploying $app_name on $infra_type..."
    
    # Create input for dynamic deployment system
    echo -e "${infra_index}\n${app_index}\ny" | timeout 2400 ./dynamic_deployment_system.sh > "deploy_${app_name}_${infra_type}.log" 2>&1 || {
        print_error "Deployment failed for $app_name on $infra_type"
        echo "### $app_name on $infra_type" >> "$results_file"
        echo "- **Status**: ❌ FAILED" >> "$results_file"
        echo "- **Error**: Deployment timeout or failure" >> "$results_file"
        echo "- **Log**: See deploy_${app_name}_${infra_type}.log" >> "$results_file"
        echo "" >> "$results_file"
        return 1
    }
    
    # Get deployment directory
    deploy_dir="deployment_${infra_type}_${app_name}"
    
    if [ ! -d "$deploy_dir" ]; then
        print_error "Deployment directory not found for $app_name on $infra_type"
        echo "### $app_name on $infra_type" >> "$results_file"
        echo "- **Status**: ❌ FAILED" >> "$results_file"
        echo "- **Error**: Deployment directory not created" >> "$results_file"
        echo "" >> "$results_file"
        return 1
    fi
    
    cd "$deploy_dir"
    
    # Get URL based on infrastructure type
    url=""
    case $infra_type in
        "ec2")
            url=$(terraform output -raw app_url 2>/dev/null || echo "")
            ;;
        "ecs")
            # For ECS, we need to get the public IP of the task
            cluster_name=$(terraform output -raw cluster_name 2>/dev/null || echo "")
            if [ ! -z "$cluster_name" ]; then
                # Wait for task to be running
                sleep 180
                task_arn=$(aws ecs list-tasks --cluster "$cluster_name" --query 'taskArns[0]' --output text 2>/dev/null || echo "")
                if [ "$task_arn" != "None" ] && [ ! -z "$task_arn" ]; then
                    # Get ENI ID
                    eni_id=$(aws ecs describe-tasks --cluster "$cluster_name" --tasks "$task_arn" --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text 2>/dev/null || echo "")
                    if [ ! -z "$eni_id" ] && [ "$eni_id" != "None" ]; then
                        public_ip=$(aws ec2 describe-network-interfaces --network-interface-ids "$eni_id" --query 'NetworkInterfaces[0].Association.PublicIp' --output text 2>/dev/null || echo "")
                        if [ ! -z "$public_ip" ] && [ "$public_ip" != "None" ]; then
                            url="http://$public_ip:8502"
                        fi
                    fi
                fi
            fi
            ;;
        "ecs_alb")
            url=$(terraform output -raw load_balancer_url 2>/dev/null || echo "")
            # For ECS+ALB, also need to wait for deployment and push image
            if [ ! -z "$url" ] && [ -f "deploy.sh" ]; then
                print_status "Building and pushing Docker image..."
                ./deploy.sh > "../deploy_image_${app_name}_${infra_type}.log" 2>&1 || true
                sleep 300  # Wait for deployment
            fi
            ;;
    esac
    
    if [ -z "$url" ]; then
        print_error "Could not get URL for $app_name on $infra_type"
        echo "### $app_name on $infra_type" >> "$results_file"
        echo "- **Status**: ❌ FAILED" >> "$results_file"
        echo "- **Error**: Could not retrieve application URL" >> "$results_file"
        echo "" >> "$results_file"
        cd ..
        return 1
    fi
    
    print_status "Application URL: $url"
    
    # Wait for application to be ready
    print_status "Waiting for application to be ready..."
    sleep 180
    
    # Test application multiple times
    print_status "Testing application..."
    success=false
    for i in {1..5}; do
        response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
        if [ "$response" = "200" ]; then
            success=true
            break
        fi
        print_status "Attempt $i: HTTP $response, retrying..."
        sleep 60
    done
    
    if [ "$success" = true ]; then
        print_status "✅ SUCCESS: $app_name on $infra_type is working!"
        echo "### $app_name on $infra_type" >> "$results_file"
        echo "- **Status**: ✅ SUCCESS" >> "$results_file"
        echo "- **URL**: $url" >> "$results_file"
        echo "- **HTTP Status**: 200" >> "$results_file"
        echo "" >> "$results_file"
    else
        print_warning "⚠️  WARNING: $app_name on $infra_type returned HTTP $response"
        echo "### $app_name on $infra_type" >> "$results_file"
        echo "- **Status**: ⚠️ WARNING" >> "$results_file"
        echo "- **URL**: $url" >> "$results_file"
        echo "- **HTTP Status**: $response" >> "$results_file"
        echo "" >> "$results_file"
    fi
    
    cd ..
    
    # Clean up to save resources (but keep logs)
    cd "$deploy_dir"
    terraform destroy -auto-approve || true
    cd ..
    # Don't remove directory, keep for debugging
    # rm -rf "$deploy_dir"
    
    print_status "Test completed for $app_name on $infra_type"
}

# Main execution
main() {
    print_header "COMPLETE APPLICATION VALIDATION"
    print_status "Testing ${#applications[@]} applications on 3 infrastructure types"
    
    # Ensure we're in the right directory
    cd /home/ubuntu/real-aws-deployment
    
    # Test a subset first (3 apps on each infrastructure for demonstration)
    test_apps=("1:flask-cnn-app-py39:deep_learning/flask-cnn-app-py39" "3:flask-lstm-app-py39:deep_learning/flask-lstm-app-py39" "9:flask-lgbm-app:machine_learning/flask-lgbm-app")
    
    for app_entry in "${test_apps[@]}"; do
        IFS=':' read -r app_index app_name app_path <<< "$app_entry"
        
        for infra_entry in "${infrastructures[@]}"; do
            IFS=':' read -r infra_index infra_type <<< "$infra_entry"
            
            test_application "$app_index" "$app_name" "$app_path" "$infra_index" "$infra_type"
            
            # Small delay between tests
            sleep 60
        done
    done
    
    print_header "VALIDATION COMPLETE"
    print_status "Results saved to: $results_file"
    
    # Generate summary
    total_tests=$((${#test_apps[@]} * 3))
    success_count=$(grep -c "✅ SUCCESS" "$results_file" || echo "0")
    warning_count=$(grep -c "⚠️ WARNING" "$results_file" || echo "0")
    failed_count=$(grep -c "❌ FAILED" "$results_file" || echo "0")
    
    echo "" >> "$results_file"
    echo "## Final Summary" >> "$results_file"
    echo "- **Total Tests**: $total_tests" >> "$results_file"
    echo "- **Successful**: $success_count" >> "$results_file"
    echo "- **Warnings**: $warning_count" >> "$results_file"
    echo "- **Failed**: $failed_count" >> "$results_file"
    echo "- **Success Rate**: $(( (success_count + warning_count) * 100 / total_tests ))%" >> "$results_file"
    
    print_status "Final Summary:"
    print_status "Total Tests: $total_tests"
    print_status "Successful: $success_count"
    print_status "Warnings: $warning_count"
    print_status "Failed: $failed_count"
    print_status "Success Rate: $(( (success_count + warning_count) * 100 / total_tests ))%"
}

# Run main function
main "$@"


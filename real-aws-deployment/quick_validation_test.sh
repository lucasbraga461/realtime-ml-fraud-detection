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

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Results file
results_file="/home/ubuntu/real-aws-deployment/quick_validation_results.md"

# Initialize results file
cat > "$results_file" << EOF
# Quick Application Validation Results

## Test Summary
- **Test Date**: $(date)
- **Test Type**: Representative sample validation
- **Applications Tested**: 3 (CNN, LSTM, LGBM)
- **Infrastructure Types**: 3 (EC2, ECS, ECS+ALB)

## Test Results

EOF

# Function to test one application on one infrastructure
test_single() {
    local infra_choice="$1"
    local app_choice="$2"
    local app_name="$3"
    local infra_name="$4"
    
    print_header "TESTING $app_name ON $infra_name"
    
    # Clean any existing deployment
    rm -rf deployment_*_${app_name} 2>/dev/null || true
    
    # Deploy using dynamic system
    echo -e "${infra_choice}\n${app_choice}\ny" | timeout 2400 ./dynamic_deployment_system.sh > "test_${app_name}_${infra_name}.log" 2>&1
    
    if [ $? -eq 0 ]; then
        # Get deployment directory
        deploy_dir=$(ls -d deployment_*_${app_name} 2>/dev/null | head -1)
        
        if [ ! -z "$deploy_dir" ] && [ -d "$deploy_dir" ]; then
            cd "$deploy_dir"
            
            # Get URL
            case $infra_name in
                "EC2")
                    url=$(terraform output -raw app_url 2>/dev/null || echo "")
                    ;;
                "ECS")
                    cluster_name=$(terraform output -raw cluster_name 2>/dev/null || echo "")
                    if [ ! -z "$cluster_name" ]; then
                        sleep 180
                        task_arn=$(aws ecs list-tasks --cluster "$cluster_name" --query 'taskArns[0]' --output text 2>/dev/null || echo "")
                        if [ "$task_arn" != "None" ] && [ ! -z "$task_arn" ]; then
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
                "ECS_ALB")
                    url=$(terraform output -raw load_balancer_url 2>/dev/null || echo "")
                    if [ ! -z "$url" ] && [ -f "deploy.sh" ]; then
                        ./deploy.sh > "../deploy_image_${app_name}_${infra_name}.log" 2>&1 || true
                        sleep 300
                    fi
                    ;;
            esac
            
            if [ ! -z "$url" ]; then
                print_status "Testing URL: $url"
                sleep 120
                
                # Test application
                response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
                
                if [ "$response" = "200" ]; then
                    print_status "✅ SUCCESS: $app_name on $infra_name"
                    echo "### $app_name on $infra_name" >> "$results_file"
                    echo "- **Status**: ✅ SUCCESS" >> "$results_file"
                    echo "- **URL**: $url" >> "$results_file"
                    echo "- **HTTP Status**: 200" >> "$results_file"
                    echo "" >> "$results_file"
                else
                    print_status "⚠️ WARNING: $app_name on $infra_name (HTTP $response)"
                    echo "### $app_name on $infra_name" >> "$results_file"
                    echo "- **Status**: ⚠️ WARNING" >> "$results_file"
                    echo "- **URL**: $url" >> "$results_file"
                    echo "- **HTTP Status**: $response" >> "$results_file"
                    echo "" >> "$results_file"
                fi
            else
                print_status "❌ FAILED: Could not get URL for $app_name on $infra_name"
                echo "### $app_name on $infra_name" >> "$results_file"
                echo "- **Status**: ❌ FAILED" >> "$results_file"
                echo "- **Error**: Could not retrieve URL" >> "$results_file"
                echo "" >> "$results_file"
            fi
            
            # Cleanup
            terraform destroy -auto-approve || true
            cd ..
        else
            print_status "❌ FAILED: Deployment directory not found for $app_name on $infra_name"
            echo "### $app_name on $infra_name" >> "$results_file"
            echo "- **Status**: ❌ FAILED" >> "$results_file"
            echo "- **Error**: Deployment directory not found" >> "$results_file"
            echo "" >> "$results_file"
        fi
    else
        print_status "❌ FAILED: Deployment timeout for $app_name on $infra_name"
        echo "### $app_name on $infra_name" >> "$results_file"
        echo "- **Status**: ❌ FAILED" >> "$results_file"
        echo "- **Error**: Deployment timeout" >> "$results_file"
        echo "" >> "$results_file"
    fi
}

# Main execution
main() {
    print_header "QUICK VALIDATION TEST"
    print_status "Testing representative applications on all infrastructure types"
    
    cd /home/ubuntu/real-aws-deployment
    
    # Test CNN app on EC2
    test_single "1" "1" "flask-cnn-app-py39" "EC2"
    sleep 60
    
    # Test LSTM app on ECS
    test_single "2" "3" "flask-lstm-app-py39" "ECS"
    sleep 60
    
    # Test LGBM app on ECS+ALB
    test_single "3" "9" "flask-lgbm-app" "ECS_ALB"
    
    print_header "QUICK VALIDATION COMPLETE"
    print_status "Results saved to: $results_file"
    
    # Generate summary
    success_count=$(grep -c "✅ SUCCESS" "$results_file" || echo "0")
    warning_count=$(grep -c "⚠️ WARNING" "$results_file" || echo "0")
    failed_count=$(grep -c "❌ FAILED" "$results_file" || echo "0")
    total_tests=3
    
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


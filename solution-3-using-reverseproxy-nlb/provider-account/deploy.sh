#!/usr/bin/env bash

set -e

echo "Setting AWS_PROFILE=${AWS_PROVIDER_PROFILE}"
export AWS_PROFILE=${AWS_PROVIDER_PROFILE}

if [ -z $AWS_PROFILE ]; then
    echo "AWS_PROFILE environment variable is not set."
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

deploy_infra(){
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-infra\" containing Networking components and other infra components.."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-infra" \
        --template-file "${DIR}/infra-stack/cf-infra-stack.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}" 
}
deploy_serviceA(){
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-serviceA\" containing Service A configuration..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-serviceA" \
        --template-file "${DIR}/ecs-services-stack/cf-serviceA-stack.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}" "ServiceAImage=${SERVICE_A_IMAGE}" "ServiceAContainerPort=${SERVICE_A_PORT}"
}
deploy_reverse_proxy(){
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-reverse-pro\" containing Network Load Balancer configuration..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-rp" \
        --template-file "${DIR}/reverseproxy-stack/cf-rp-stack.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}" \
        "NLBVPCEndpointServiceConsumerUserName=${VPC_ENDPOINT_CONSUMER_USER_NAME}" \
        "NLBVPCEndpointServiceConsumerAccountId=${VPC_ENDPOINT_CONSUMER_ACCOUNTID}" \
        "NLBVPCEndpointServiceConsumerRoleName=${VPC_ENDPOINT_CONSUMER_ROLE_NAME}" \
        "NLBVPCEndpointServiceConsumerRoleName=${VPC_ENDPOINT_CONSUMER_ROLE_NAME}" \
        "KeyPair=${KEY_PAIR_PROVIDER_ACCOUNT}" \
        "ALBDNSEndpoint=${ALB_ENDPOINT}"
}
get_alb_endpoint(){
    export AWS_PROFILE=${AWS_PROVIDER_PROFILE}
    albendpoint=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-infra" \
        --query="Stacks[0].Outputs[?OutputKey=='ALBLoadBalancerDNSEndpoint'].OutputValue" \
        --output=text)
    export ALB_ENDPOINT=${albendpoint}
    echo "*******ALB endpoint is ${ALB_ENDPOINT}"
}

deploy_stacks() {
    deploy_infra
    deploy_serviceA
    get_alb_endpoint
    deploy_reverse_proxy
}
delete_cfn_stack() {
    stack_name=$1
    echo "Deleting Cloud Formation stack: \"${stack_name}\"..."
    aws cloudformation delete-stack --stack-name $stack_name
    echo 'Waiting for the stack to be deleted, this may take a few minutes...'
    aws cloudformation wait stack-delete-complete --stack-name $stack_name
    echo 'Done'
}
delete_stacks() {
    delete_cfn_stack "${PROJECT_NAME}-rp"
    delete_cfn_stack "${PROJECT_NAME}-serviceA"
    delete_cfn_stack "${PROJECT_NAME}-infra"
    echo "all resources for primary account have been deleted"
}
action=${1:-"deploy"}

if [ "$action" == "delete" ]; then
    delete_stacks
    exit 0
fi

if [ "$action" == "deploy" ]; then
    deploy_stacks
    exit 0
fi
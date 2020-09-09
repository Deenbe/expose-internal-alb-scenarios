#!/usr/bin/env bash

set -e

echo "Setting AWS_PROFILE=${AWS_CONSUMER_PROFILE}"
export AWS_PROFILE=${AWS_CONSUMER_PROFILE}



DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

deploy_infra_stack(){
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-infra\" containing Networking components and other infra components.."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-infra" \
        --template-file "${DIR}/infra-stack/cf-infra-stack.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}" "KeyPair=${KEY_PAIR_CONSUMER_ACCOUNT}" \
        "VPCEndpointServiceName=${SERVICE_PROVIDER_VPC_ENDPOINT_SERVICENAME}"
}
delete_infra_stack() {
    stack_name=$1
    echo "Deleting Cloud Formation stack: \"${PROJECT_NAME}-infra\"..."
    aws cloudformation delete-stack --stack-name ${PROJECT_NAME}-infra
    echo 'Waiting for the stack to be deleted, this may take a few minutes...'
    aws cloudformation wait stack-delete-complete --stack-name ${PROJECT_NAME}-infra
    echo 'Done'
}


action=${1:-"deploy"}
if [ "$action" == "delete" ]; then
    delete_infra_stack
    exit 0
fi
if [ "$action" == "deploy" ]; then
    deploy_infra_stack
    exit 0
fi
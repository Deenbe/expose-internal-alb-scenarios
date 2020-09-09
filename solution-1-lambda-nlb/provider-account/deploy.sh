#!/usr/bin/env bash

set -e

echo "Setting AWS_PROFILE=${AWS_PROVIDER_PROFILE}"
export AWS_PROFILE=${AWS_PROVIDER_PROFILE}

if [ -z $AWS_PROFILE ]; then
    echo "AWS_PROFILE environment variable is not set."
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

deploy_lamdba_function(){
    echo '********************** Uploading Lambda Zip file to S3 ***********************'
    rm -rf ${DIR}/deployment_package
    aws s3 rb s3://${LAMBDA_FUNCTION_BUCKET} --force
    mkdir ${DIR}/deployment_package
    pip3 install --target ${DIR}/deployment_package dnspython
    cp ${DIR}/lambda-function/populate_NLB_TG_with_ALB.py ${DIR}/deployment_package
    cd ${DIR}/deployment_package
    zip -r9 populate_NLB_TG_with_ALB.zip .
    aws s3 mb s3://${LAMBDA_FUNCTION_BUCKET}
    aws s3 cp populate_NLB_TG_with_ALB.zip s3://${LAMBDA_FUNCTION_BUCKET}/populate_NLB_TG_with_ALB.zip
    echo '******************** Lambda Zip file uploaded to S3 Completed ***************'
}

copy_lambda_function(){
    echo '********************** Uploading Lambda Zip file to S3 ***********************'
    mkdir ${DIR}/deployment_package
    pip3 install --target ${DIR}/deployment_package dnspython
    cp ${DIR}/lambda-function/populate_NLB_TG_with_ALB.py ${DIR}/deployment_package
    cd ${DIR}/deployment_package
    zip -r9 populate_NLB_TG_with_ALB.zip .
    aws s3 mb s3://${LAMBDA_FUNCTION_BUCKET}
    aws s3 cp populate_NLB_TG_with_ALB.zip s3://${LAMBDA_FUNCTION_BUCKET}/populate_NLB_TG_with_ALB.zip
    echo '******************** Lambda Zip file uploaded to S3 Completed ***************'
}
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
deploy_nlb(){
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-nlb\" containing Network Load Balancer configuration..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-nlb" \
        --template-file "${DIR}/network-load-balancer-stack/network-load-balancer.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}" \
        "LambdaFunctionBucketName=${LAMBDA_FUNCTION_BUCKET}" \
        "NLBVPCEndpointServiceConsumerUserName=${VPC_ENDPOINT_CONSUMER_USER_NAME}" \
        "NLBVPCEndpointServiceConsumerAccountId=${VPC_ENDPOINT_CONSUMER_ACCOUNTID}" \
        "NLBVPCEndpointServiceConsumerRoleName=${VPC_ENDPOINT_CONSUMER_ROLE_NAME}"
}
deploy_changed_lambda_function(){
    copy_lambda_function-2
}
deploy_stacks() {
    copy_lambda_function
    deploy_infra
    deploy_serviceA
    deploy_nlb
}
delete_lambda_function(){
    if ! aws s3api head-bucket --bucket $LAMBDA_FUNCTION_BUCKET 2>&1 | grep -q 'Not Found'; then
        echo '******************** Deleting Lambda Zip file and bucket ********************'
        aws s3 rb s3://lambda-invocation-tracking-${VPC_ENDPOINT_PROVIDER_ACCOUNTID} --force
        aws s3 rb s3://${LAMBDA_FUNCTION_BUCKET} --force
        rm -rf ${DIR}/deployment_package
    fi
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
    delete_lambda_function
    delete_cfn_stack "${PROJECT_NAME}-nlb"
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

if [ "$action" == "lambda" ]; then
    deploy_lamdba_function
    exit 0
fi


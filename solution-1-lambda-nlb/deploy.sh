#!/usr/bin/env bash

set -e

if [ -z $PROJECT_NAME ]; then
    echo "Project name is not set"
    exit 1
fi

if [ -z $SERVICE_A_IMAGE ]; then
    echo "Service A Image is not set"
    exit 1
fi

if [ -z $SERVICE_A_PORT ]; then
    echo "Service A Port is not set"
    exit 1
fi

if [ -z $LAMBDA_FUNCTION_BUCKET ]; then
    echo "Lambda Function Bucket name not defined"
    exit 1
fi

if [ -z $AWS_PROVIDER_PROFILE ]; then
    echo "AWS_PROVIDER_PROFILE not set"
    exit 1
fi

if [ -z $AWS_CONSUMER_PROFILE ]; then
    echo "AWS_CONSUMER_PROFILE not set"
    exit 1
fi

if [ -z $VPC_ENDPOINT_CONSUMER_ROLE_NAME ]; then
    echo "VPC_ENDPOINT_CONSUMER_ROLE_NAME not set"
    exit 1
fi

if [ -z $VPC_ENDPOINT_CONSUMER_USER_NAME ]; then
    echo "VPC_ENDPOINT_CONSUMER_USER_NAME not set"
    exit 1
fi

if [ -z $KEY_PAIR_CONSUMER_ACCOUNT ]; then
    echo "KEY_PAIR_CONSUMER_ACCOUNT not set"
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PROVIDER_ACCOUNT_DIR="${DIR}/provider-account"
CONSUMER_ACCOUNT_DIR="${DIR}/consumer-account"


get_vpc_endpointservice(){
    export AWS_PROFILE=${AWS_PROVIDER_PROFILE}
    vpcendpointservice_name=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-nlb" \
        --query="Stacks[0].Outputs[?OutputKey=='NetworkLoadBalancerVPCEndpointService'].OutputValue" \
        --output=text)
    export SERVICE_PROVIDER_VPC_ENDPOINT_SERVICENAME=${vpcendpointservice_name}
    echo "*******VPC endpoint service name is ${SERVICE_PROVIDER_VPC_ENDPOINT_SERVICENAME}"
}

action=${1:-"deploy"}

if [ "$action" == "deploy" ]; then
    ${PROVIDER_ACCOUNT_DIR}/deploy.sh deploy
    get_vpc_endpointservice
    ${CONSUMER_ACCOUNT_DIR}/deploy.sh deploy
fi

if [ "$action" == "delete" ]; then
    ${CONSUMER_ACCOUNT_DIR}/deploy.sh delete
    ${PROVIDER_ACCOUNT_DIR}/deploy.sh delete
    exit 0
fi

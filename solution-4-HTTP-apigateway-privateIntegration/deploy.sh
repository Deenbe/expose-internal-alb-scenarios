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

print_apiendpoint(){
    export AWS_PROFILE=${AWS_PROVIDER_PROFILE}
    apiInvokeURL=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-httpapi" \
        --query="Stacks[0].Outputs[?OutputKey=='apiInvokeURL'].OutputValue" \
        --output=text)
    export API_INVOKE_URL=${apiInvokeURL}
}
print_bastion_and_serviceconsumer_host_ip(){
    export AWS_PROFILE=${AWS_CONSUMER_PROFILE}
    bastionIP=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-cons-infra" \
        --query="Stacks[0].Outputs[?OutputKey=='BastionIp'].OutputValue" \
        --output=text)
    
    serviceConsumerHostIP=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-cons-infra" \
        --query="Stacks[0].Outputs[?OutputKey=='ServiceConsumerHostIP'].OutputValue" \
        --output=text)

    export bastionIP
    export serviceConsumerHostIP
}

action=${1:-"deploy"}
if [ "$action" == "deploy" ]; then
    ${PROVIDER_ACCOUNT_DIR}/deploy.sh deploy
    print_apiendpoint
    ${CONSUMER_ACCOUNT_DIR}/deploy.sh deploy
    print_bastion_and_serviceconsumer_host_ip
    echo "**************************"
    echo "Login into Bastion Host ${bastionIP} with Consumer Keypair"
    echo "Once you login to Bastion Host login to Service Consumer Host ${serviceConsumerHostIP} and curl "
    echo "${API_INVOKE_URL}/democall      to invoke HTTP API"
    echo "HTTP API calls internal ALB in service provider account"
fi

if [ "$action" == "delete" ]; then
    ${CONSUMER_ACCOUNT_DIR}/deploy.sh delete
    ${PROVIDER_ACCOUNT_DIR}/deploy.sh delete
    exit 0
fi

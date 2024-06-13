#!/bin/bash
set -e

# Constants
PATH=$PATH:/usr/local/bin; export PATH
REGION=ap-south-1
REPOSITORY_NAME=tedxntua
CLUSTER=Laravel-app
SERVICE_NAME=laravel-app-service
IMAGE_TAG=latest1 # Define the image tag, update as needed
ECR_URI=730335380624.dkr.ecr.${REGION}.amazonaws.com/${REPOSITORY_NAME}:${IMAGE_TAG}



#docker build -t ${REPOSITORY_NAME}:${IMAGE_TAG} .
#aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_URI}
#docker tag ${REPOSITORY_NAME}:${IMAGE_TAG} ${ECR_URI}
#docker push ${ECR_URI}

CURRENT_TASK_DEFINITION_ARN=$(aws ecs describe-services --cluster ${CLUSTER} --services ${SERVICE_NAME} --query 'services[0].taskDefinition' --output text)

echo "CURRENT_TASK_DEFINITION_ARN= $CURRENT_TASK_DEFINITION_ARN"

echo ""

CURRENT_TASK_DEFINITION=$(aws ecs describe-task-definition --task-definition ${CURRENT_TASK_DEFINITION_ARN})


EXISTING_EXECUTION_ROLE_ARN=$(echo "${CURRENT_TASK_DEFINITION}" | jq -r '.taskDefinition.executionRoleArn')
EXISTING_NETWORK_MODE=$(echo "${CURRENT_TASK_DEFINITION}" | jq -r '.taskDefinition.networkMode')
EXISTING_REQUIRES_COMPATIBILITIES=$(echo "${CURRENT_TASK_DEFINITION}" | jq -r '.taskDefinition.requiresCompatibilities[0]')
EXISTING_CPU=$(echo "${CURRENT_TASK_DEFINITION}" | jq -r '.taskDefinition.cpu')
EXISTING_MEMORY=$(echo "${CURRENT_TASK_DEFINITION}" | jq -r '.taskDefinition.memory')


echo "CURRENT_TASK_DEFINITION= $CURRENT_TASK_DEFINITION"

echo ""


NEW_CONTAINER_DEFINITION=$(echo ${CURRENT_TASK_DEFINITION} | jq --arg ECR_URI "${ECR_URI}" '.taskDefinition.containerDefinitions | map(.image = $ECR_URI)')

echo "NEW_CONTAINER_DEFINITION= $NEW_CONTAINER_DEFINITION"

echo ""

NEW_TASK_DEF=$(echo ${CURRENT_TASK_DEFINITION} | jq 'del(.taskDefinition.status, .taskDefinition.requiresAttributes, .taskDefinition.compatibilities, .taskDefinition.revision, .taskDefinition.registeredAt, .taskDefinition.registeredBy, .taskDefinition.taskDefinitionArn) | .taskDefinition.containerDefinitions = '"${NEW_CONTAINER_DEFINITION}"' | .taskDefinition.family = "laravel-app-TD"') 
#echo "NEW_TASK_DEF= $NEW_TASK_DEF"

echo ""

echo "*****"

TASK_DEF_OUTPUT=$(aws ecs register-task-definition \
    --family "laravel-app-TD" \
    --container-definitions "${NEW_CONTAINER_DEFINITION}" \
    --execution-role-arn "${EXISTING_EXECUTION_ROLE_ARN}" \
    --network-mode "${EXISTING_NETWORK_MODE}" \
    --requires-compatibilities "${EXISTING_REQUIRES_COMPATIBILITIES}" \
    --cpu "${EXISTING_CPU}" \
    --memory "${EXISTING_MEMORY}")

NEW_TASK_DEFINITION_ARN=$(echo "${TASK_DEF_OUTPUT}" | jq -r '.taskDefinition.taskDefinitionArn') 
aws ecs update-service --cluster ${CLUSTER} --service ${SERVICE_NAME} --task-definition ${NEW_TASK_DEFINITION_ARN}

echo "Deployment successful!


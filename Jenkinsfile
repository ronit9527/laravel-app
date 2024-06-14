pipeline {
    agent any

    environment {
        REGION = 'ap-south-1'
        REPOSITORY_NAME = 'tedxntua'
        CLUSTER = 'Laravel-app'
        SERVICE_NAME = 'laravel-app-service'
        IMAGE_TAG = 'latest1'
        ECR_URI = "730335380624.dkr.ecr.${REGION}.amazonaws.com/${REPOSITORY_NAME}:${IMAGE_TAG}"
        EMAIL_RECIPIENTS = "ronitj1211@gmail.com" 
        SCANNER_HOME = tool 'Sonar'
    }

    stages {
        stage('Checkout') {
            steps {
                // Checkout the code from the repository
                checkout scm
            }
        }
        
    stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh "${SCANNER_HOME}/bin/sonar-scanner \
                            -D sonar.projectVersion=1.0-SNAPSHOT \
                            -D sonar.qualityProfile=testing \
                            -D sonar.projectBaseDir=${WORKSPACE} \
                            -D sonar.projectKey=laravel-application \
                            -D sonar.sourceEncoding=UTF-8 \
                            -D sonar.language=php \
                            -D sonar.host.url=http://laravel.infydevops.work.gd:9000"
                }
            }
        }


        stage('Build Docker Image') {
            steps {
                script {
                    // Build Docker image
                    sh '''
                        docker build -t ${REPOSITORY_NAME}:${IMAGE_TAG} .
                    '''
                }
            }
        }

        stage('Login to ECR') {
            steps {
                script {
                    // Login to Amazon ECR
                    sh '''
                        aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_URI}
                    '''
                }
            }
        }

        stage('Tag and Push Docker Image') {
            steps {
                script {
                    // Tag and push the Docker image to ECR
                    sh '''
                        docker tag ${REPOSITORY_NAME}:${IMAGE_TAG} ${ECR_URI}
                        docker push ${ECR_URI}
                    '''
                }
            }
        }

        stage('Update ECS Task Definition') {
            steps {
                script {
                    // Update ECS Task Definition
                    sh '''
                        #!/bin/bash
                        set -e

                        CURRENT_TASK_DEFINITION_ARN=$(aws ecs describe-services --cluster ${CLUSTER} --services ${SERVICE_NAME} --query 'services[0].taskDefinition' --output text)
                        echo "CURRENT_TASK_DEFINITION_ARN= $CURRENT_TASK_DEFINITION_ARN"
                        CURRENT_TASK_DEFINITION=$(aws ecs describe-task-definition --task-definition ${CURRENT_TASK_DEFINITION_ARN})
                        EXISTING_EXECUTION_ROLE_ARN=$(echo "${CURRENT_TASK_DEFINITION}" | jq -r '.taskDefinition.executionRoleArn')
                        EXISTING_NETWORK_MODE=$(echo "${CURRENT_TASK_DEFINITION}" | jq -r '.taskDefinition.networkMode')
                        EXISTING_REQUIRES_COMPATIBILITIES=$(echo "${CURRENT_TASK_DEFINITION}" | jq -r '.taskDefinition.requiresCompatibilities[0]')
                        EXISTING_CPU=$(echo "${CURRENT_TASK_DEFINITION}" | jq -r '.taskDefinition.cpu')
                        EXISTING_MEMORY=$(echo "${CURRENT_TASK_DEFINITION}" | jq -r '.taskDefinition.memory')
                        NEW_CONTAINER_DEFINITION=$(echo ${CURRENT_TASK_DEFINITION} | jq --arg ECR_URI "${ECR_URI}" '.taskDefinition.containerDefinitions | map(.image = $ECR_URI)')
                        NEW_TASK_DEF=$(echo ${CURRENT_TASK_DEFINITION} | jq 'del(.taskDefinition.status, .taskDefinition.requiresAttributes, .taskDefinition.compatibilities, .taskDefinition.revision, .taskDefinition.registeredAt, .taskDefinition.registeredBy, .taskDefinition.taskDefinitionArn) | .taskDefinition.containerDefinitions = '"${NEW_CONTAINER_DEFINITION}"' | .taskDefinition.family = "laravel-app-TD"')
                        TASK_DEF_OUTPUT=$(aws ecs register-task-definition --family "laravel-app-TD" --container-definitions "${NEW_CONTAINER_DEFINITION}" --execution-role-arn "${EXISTING_EXECUTION_ROLE_ARN}" --network-mode "${EXISTING_NETWORK_MODE}" --requires-compatibilities "${EXISTING_REQUIRES_COMPATIBILITIES}" --cpu "${EXISTING_CPU}" --memory "${EXISTING_MEMORY}")
                        NEW_TASK_DEFINITION_ARN=$(echo "${TASK_DEF_OUTPUT}" | jq -r '.taskDefinition.taskDefinitionArn')
                        aws ecs update-service --cluster ${CLUSTER} --service ${SERVICE_NAME} --task-definition ${NEW_TASK_DEFINITION_ARN}
                        echo "Deployment successful!"
                    '''
                }
            }
        }
    }

    post {
        success {
            emailext(
                to: "${EMAIL_RECIPIENTS}",
                subject: "Build Successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "Congratulations!\n\nThe build for ${env.JOB_NAME} #${env.BUILD_NUMBER} was successful.\n\nJob Details: ${env.BUILD_URL}",
                mimeType: 'text/html'
            )
        }
        failure {
            emailext(
                to: "${EMAIL_RECIPIENTS}",
                subject: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "Alert!\n\nThe build for ${env.JOB_NAME} #${env.BUILD_NUMBER} has failed.\n\nJob Details: ${env.BUILD_URL}",
                mimeType: 'text/html'
            )
        }
        always {
            emailext(
                to: "${EMAIL_RECIPIENTS}",
                subject: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "Alert!\n\nThe build for ${env.JOB_NAME} #${env.BUILD_NUMBER} has failed.\n\nJob Details: ${env.BUILD_URL}",
                mimeType: 'text/html'
                )
            cleanWs() // Clean up workspace after the build
        }
    }
}


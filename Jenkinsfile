pipeline {
    agent { label 'linux-docker' }

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 45, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '30'))
    }

    environment {
        AWS_REGION = 'us-east-1'
        TF_DIR = 'terraform/environments/prod'
        TFVARS = 'prod.tfvars'
        DEPLOYMENT_APPLIED = 'false'
    }

    stages {
        stage('Checkout Source Code') {
            steps {
                checkout scm
                configFileProvider([
                    configFile(fileId: 'terraform-backend-prod', variable: 'TF_BACKEND_FILE'),
                    configFile(fileId: 'terraform-vars-prod', variable: 'TFVARS_FILE')
                ]) {
                    sh '''
                        install -m 600 "${TFVARS_FILE}" "${TF_DIR}/${TFVARS}"
                        terraform -chdir="${TF_DIR}" init -input=false \
                          -backend-config="${TF_BACKEND_FILE}"
                    '''
                }
                script {
                    env.IMAGE_TAG = "sha-${env.GIT_COMMIT.take(12)}-${env.BUILD_NUMBER}"
                    env.ECR_REPOSITORY = sh(
                        returnStdout: true,
                        script: 'terraform -chdir="${TF_DIR}" output -raw ecr_repository_url'
                    ).trim()
                }
            }
        }

        stage('SonarQube Code Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'sonar-scanner -Dsonar.projectVersion="${BUILD_NUMBER}"'
                }
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Unit Testing') {
            steps {
                sh 'python3 -m unittest discover -s tests -v'
            }
        }

        stage('Dependency Scan') {
            steps {
                sh '''
                    trivy fs --scanners vuln \
                      --severity HIGH,CRITICAL --exit-code 1 .
                '''
            }
        }

        stage('Trivy Security Scan') {
            steps {
                sh '''
                    trivy fs --scanners secret \
                      --severity HIGH,CRITICAL --exit-code 1 .
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build --pull --tag "ypp-fiber-site:${IMAGE_TAG}" .'
            }
        }

        stage('Push Docker Image to ECR') {
            steps {
                sh '''
                    trivy image --severity HIGH,CRITICAL --exit-code 1 \
                      "ypp-fiber-site:${IMAGE_TAG}"
                    ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
                    REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    aws ecr get-login-password --region "${AWS_REGION}" \
                      | docker login --username AWS --password-stdin "${REGISTRY}"
                    docker tag "ypp-fiber-site:${IMAGE_TAG}" "${ECR_REPOSITORY}:${IMAGE_TAG}"
                    docker push "${ECR_REPOSITORY}:${IMAGE_TAG}"
                    REPOSITORY_NAME="${ECR_REPOSITORY##*/}"
                    if ! aws ecr describe-images --repository-name "${REPOSITORY_NAME}" \
                      --image-ids imageTag=bootstrap >/dev/null 2>&1; then
                      docker tag "ypp-fiber-site:${IMAGE_TAG}" "${ECR_REPOSITORY}:bootstrap"
                      docker push "${ECR_REPOSITORY}:bootstrap"
                    fi
                '''
            }
        }

        stage('Terraform Plan') {
            steps {
                sh '''
                    test -f "${TF_DIR}/${TFVARS}" || {
                      echo "Missing ${TF_DIR}/${TFVARS}; provision the deployment configuration first." >&2
                      exit 1
                    }
                    terraform -chdir="${TF_DIR}" validate
                    terraform -chdir="${TF_DIR}" plan -input=false \
                      -var-file="${TFVARS}" -var="image_tag=${IMAGE_TAG}" \
                      -out=tfplan
                    terraform -chdir="${TF_DIR}" show -no-color tfplan > "${TF_DIR}/terraform-plan.txt"
                '''
                archiveArtifacts artifacts: "${TF_DIR}/terraform-plan.txt",
                                 fingerprint: true
            }
        }

        stage('Manual Approval') {
            steps {
                input message: "Deploy ${IMAGE_TAG} to production?", ok: 'Deploy',
                      submitter: 'production-approvers'
            }
        }

        stage('Terraform Apply') {
            steps {
                script {
                    env.PREVIOUS_TASK_DEFINITION = sh(
                        returnStdout: true,
                        script: '''
                            aws ecs describe-services \
                              --cluster $(terraform -chdir="${TF_DIR}" output -raw ecs_cluster_name) \
                              --services $(terraform -chdir="${TF_DIR}" output -raw ecs_service_name) \
                              --query 'services[0].taskDefinition' --output text 2>/dev/null || true
                        '''
                    ).trim()
                }
                sh 'terraform -chdir="${TF_DIR}" apply -input=false -auto-approve tfplan'
                script { env.DEPLOYMENT_APPLIED = 'true' }
            }
        }

        stage('ECS Service Deployment') {
            steps {
                sh '''
                    CLUSTER="$(terraform -chdir=${TF_DIR} output -raw ecs_cluster_name)"
                    SERVICE="$(terraform -chdir=${TF_DIR} output -raw ecs_service_name)"
                    aws ecs wait services-stable --cluster "${CLUSTER}" --services "${SERVICE}"
                '''
            }
        }

        stage('Smoke Testing') {
            steps {
                sh '''
                    URL="$(terraform -chdir=${TF_DIR} output -raw application_url)"
                    curl --fail --silent --show-error --retry 5 --retry-delay 5 \
                      --retry-connrefused "${URL}/healthz"
                    curl --fail --silent --show-error "${URL}/" | grep -q '<title>'
                '''
            }
        }

        stage('Health Check Validation') {
            steps {
                sh '''
                    TARGET_GROUP="$(terraform -chdir=${TF_DIR} output -raw target_group_arn)"
                    for attempt in $(seq 1 20); do
                      HEALTHY="$(aws elbv2 describe-target-health \
                        --target-group-arn "${TARGET_GROUP}" \
                        --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
                        --output text)"
                      if [ "${HEALTHY}" -ge 2 ]; then
                        echo "Healthy targets: ${HEALTHY}"
                        exit 0
                      fi
                      echo "Waiting for two healthy targets; currently ${HEALTHY} (attempt ${attempt}/20)"
                      sleep 15
                    done
                    echo "Timed out waiting for ALB targets to become healthy." >&2
                    aws elbv2 describe-target-health --target-group-arn "${TARGET_GROUP}" >&2
                    exit 1
                '''
            }
        }

        stage('Deployment Notification') {
            steps {
                script {
                    def topic = sh(
                        returnStdout: true,
                        script: 'terraform -chdir="${TF_DIR}" output -raw alarm_topic_arn 2>/dev/null || true'
                    ).trim()
                    if (topic && topic != 'null') {
                        sh """
                            aws sns publish --region "${AWS_REGION}" --topic-arn "${topic}" \\
                              --subject "Production deployment succeeded" \\
                              --message "Build ${BUILD_NUMBER} deployed ${IMAGE_TAG}. ${BUILD_URL}"
                        """
                    } else {
                        echo 'No SNS alarm topic configured; use Jenkins email-ext notifications if required.'
                    }
                }
            }
        }
    }

    post {
        failure {
            script {
                if (env.DEPLOYMENT_APPLIED == 'true' && env.PREVIOUS_TASK_DEFINITION?.trim()) {
                    withEnv(["PREVIOUS_TASK_DEFINITION=${env.PREVIOUS_TASK_DEFINITION}"]) {
                      sh '''
                        aws ecs update-service \
                          --cluster $(terraform -chdir="${TF_DIR}" output -raw ecs_cluster_name) \
                          --service $(terraform -chdir="${TF_DIR}" output -raw ecs_service_name) \
                          --task-definition "${PREVIOUS_TASK_DEFINITION}" >/dev/null
                        aws ecs wait services-stable \
                          --cluster $(terraform -chdir="${TF_DIR}" output -raw ecs_cluster_name) \
                          --services $(terraform -chdir="${TF_DIR}" output -raw ecs_service_name)
                      '''
                    }
                }
            }
        }
        cleanup {
            sh 'docker image prune --force || true'
            deleteDir()
        }
    }
}

pipeline {
  agent any
  environment {
        APP_NAME="phonebook"
        APP_REPO_NAME="clarusway-repo/${APP_NAME}-app"
        AWS_ACCOUNT_ID=sh(script:'aws sts get-caller-identity --query Account --output text', returnStdout:true).trim()
        AWS_REGION="us-east-1"
        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        CLUSTER_URL="https://172.31.32.78:6443"
    }
  stages {
    stage('Create ECR Repo') {
      steps {
        echo "Creating ECR Repo for ${APP_NAME} app"
        sh '''
        aws ecr describe-repositories --region ${AWS_REGION} --repository-name ${APP_REPO_NAME} || \
            aws ecr create-repository \
            --repository-name ${APP_REPO_NAME} \
            --image-scanning-configuration scanOnPush=true \
            --image-tag-mutability MUTABLE \
            --region ${AWS_REGION}
         '''
        }
      }
    stage('Build App Docker Images') {
      steps {
        echo 'Building App Dev Images'
        sh "docker build -t ${ECR_REGISTRY}/${APP_REPO_NAME}:web-b${BUILD_NUMBER} ${WORKSPACE}/images/image_for_web_server"
        sh "docker build -t ${ECR_REGISTRY}/${APP_REPO_NAME}:result-b${BUILD_NUMBER} ${WORKSPACE}/images/image_for_result_server"
        sh 'docker image ls'
        }
      }
    stage('Push Images to ECR Repo') {
        steps {
          echo "Pushing ${APP_NAME} App Images to ECR Repo"
          sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
          sh "docker push ${ECR_REGISTRY}/${APP_REPO_NAME}:web-b${BUILD_NUMBER}"
          sh "docker push ${ECR_REGISTRY}/${APP_REPO_NAME}:result-b${BUILD_NUMBER}"
        }
      }
    stage('deploy application') {
      steps {
        withKubeCredentials(
          kubectlCredentials: [
            [clusterName: 'kube-cluster-1', contextName: 'kubernetes-admin@kubernetest', credentialsId: 'kube_token', namespace: 'default', serverUrl: "${CLUSTER_URL}"]
          ]
        ) {
          sh 'kubectl get nodes'
          sh '''
          kubectl delete secret regcred || true
          kubectl create secret generic regcred \
            --from-file=.dockerconfigjson=/var/lib/jenkins/.docker/config.json \
            --type=kubernetes.io/dockerconfigjson
          sed -i "s|IMAGE_TAG_WEB_SERVER|${ECR_REGISTRY}/${APP_REPO_NAME}:web-b${BUILD_NUMBER}|" k8s/webserver-deploy.yaml
          sed -i "s|IMAGE_TAG_RESULT_SERVER|${ECR_REGISTRY}/${APP_REPO_NAME}:result-b${BUILD_NUMBER}|" k8s/resultserver-deploy.yaml          
          kubectl apply -f k8s
          '''
        }
      }
    }
  }
}
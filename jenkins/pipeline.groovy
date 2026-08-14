pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  triggers {
    githubPush()
  }

  environment {
    AWS_REGION        = 'us-east-2'
    AWS_ACCOUNT_ID    = '506570851351'
    ECR_REPOSITORY    = 'node-app'
    EKS_CLUSTER       = 'devops-eks-cluster'
    K8S_NAMESPACE     = 'node-app'
    HELM_RELEASE      = 'node-app'
    GITHUB_REPOSITORY = 'https://github.com/uukomadu/devops-code-challenge2.git'
    ECR_REGISTRY      = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  }

  stages {
    stage('Checkout') {
      steps {
        git branch: 'main',
            credentialsId: 'github-credentials',
            url: env.GITHUB_REPOSITORY

        script {
          env.IMAGE_TAG = sh(
            script: 'git rev-parse --short=12 HEAD',
            returnStdout: true
          ).trim()
          env.IMAGE_URI = "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}"
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        sh 'docker build --tag ${IMAGE_URI}:${IMAGE_TAG} .'
      }
    }

    stage('Push to Amazon ECR') {
      steps {
        sh '''
          set -e
          aws ecr describe-repositories \
            --repository-names "$ECR_REPOSITORY" \
            --region "$AWS_REGION" >/dev/null 2>&1 || \
          aws ecr create-repository \
            --repository-name "$ECR_REPOSITORY" \
            --image-scanning-configuration scanOnPush=true \
            --region "$AWS_REGION"

          aws ecr get-login-password --region "$AWS_REGION" | \
            docker login --username AWS --password-stdin "$ECR_REGISTRY"

          docker push "$IMAGE_URI:$IMAGE_TAG"
          docker tag "$IMAGE_URI:$IMAGE_TAG" "$IMAGE_URI:latest"
          docker push "$IMAGE_URI:latest"
        '''
      }
    }

    stage('Connect to EKS') {
      steps {
        sh '''
          set -e
          aws eks update-kubeconfig \
            --name "$EKS_CLUSTER" \
            --region "$AWS_REGION"
          kubectl get nodes
          kubectl create namespace "$K8S_NAMESPACE" \
            --dry-run=client -o yaml | kubectl apply -f -
        '''
      }
    }

    stage('Deploy with Helm') {
      steps {
        sh '''
          set -e
          helm lint helm/node-app
          helm upgrade --install "$HELM_RELEASE" helm/node-app \
            --namespace "$K8S_NAMESPACE" \
            --set image.repository="$IMAGE_URI" \
            --set image.tag="$IMAGE_TAG" \
            --set image.pullPolicy=IfNotPresent \
            --wait \
            --timeout 10m
        '''
      }
    }

    stage('Verify Deployment') {
      steps {
        sh '''
          set -e
          kubectl rollout status \
            deployment/${HELM_RELEASE}-node-app \
            --namespace "$K8S_NAMESPACE" \
            --timeout=5m
          kubectl get pods,service,ingress \
            --namespace "$K8S_NAMESPACE"
        '''
      }
    }
  }

  post {
    always {
      sh 'docker logout "$ECR_REGISTRY" || true'
    }
    success {
      echo "Deployed ${IMAGE_URI}:${IMAGE_TAG} to ${EKS_CLUSTER}"
    }
  }
}

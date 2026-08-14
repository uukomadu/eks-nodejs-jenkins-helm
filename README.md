# Overview

This repository contains a Dockerized Node.js application that is deployed to an Amazon EKS cluster.

# Objective

Provision an Amazon EKS environment with Terraform, expose the application through an internet-facing Application Load Balancer, and use Jenkins to build and deploy the application.

The deployment includes:

1. An EKS managed node group that always runs at least one `t3.small` node and can scale to four nodes.
2. A Kubernetes deployment that starts with one pod and uses a Horizontal Pod Autoscaler to scale to three pods at 50% CPU or memory utilization.
3. An AWS Load Balancer Controller that creates an internet-facing Application Load Balancer.
4. A Jenkins pipeline that builds the Docker image, pushes it to Amazon ECR, and deploys the Helm chart to EKS.

# Submission

1. A GitHub repository containing the application, Terraform modules, Kubernetes manifests, Helm chart, and Jenkins pipeline.
2. This README file with instructions for:

- Setting up the environment
- Deploying the application
- Understanding the Terraform code and Jenkins pipeline

# Solution Overview

Terraform creates the AWS network, EKS cluster, managed worker node group, AWS Load Balancer Controller, and Jenkins EC2 instance. Jenkins builds the application image, pushes commit-specific and `latest` tags to Amazon ECR, and deploys the application with Helm.

The application listens on container port `3000`. Kubernetes exposes it through a NodePort Service on port `80`. The AWS Load Balancer Controller creates an internet-facing ALB and registers the EKS worker instance as the target.

The deployed application is available at:
http://k8s-nodeapp-nodeappn-01de46926b-31407617.us-east-2.elb.amazonaws.com

The current deployment uses HTTP. A production deployment should use a domain, an AWS Certificate Manager certificate, and an HTTPS listener.

# Architecture

The AWS infrastructure includes:

1. One VPC with the CIDR range `10.0.0.0/16`
2. Two public subnets in `us-east-2a` and `us-east-2b`
3. Two private subnets in `us-east-2a` and `us-east-2b`
4. One internet gateway
5. Two NAT gateways, one for each private subnet
6. One Amazon EKS cluster
7. One EKS managed node group using `t3.small` instances
8. One AWS Load Balancer Controller installed with Helm
9. One internet-facing Application Load Balancer
10. One Amazon ECR repository named `node-app`
11. One EC2 instance running Jenkins with an Elastic IP address
12. IAM roles for EKS, worker nodes, Jenkins, and the AWS Load Balancer Controller
13. Kubernetes Metrics Server for CPU and memory metrics
14. Kubernetes Cluster Autoscaler with IRSA permissions

The request and deployment flow is:

```
GitHub push
   |
Jenkins Pipeline
   |
   |-- Build Docker image --> Amazon ECR
   |
   `-- Helm deployment ----> Amazon EKS
                                  |
Internet --> Application Load Balancer --> NodePort Service --> Node.js Pod
```

# Tools Needed

The following tools are required to repeat this deployment:

1. Git
2. GitHub account
3. Node.js and npm
4. Docker
5. AWS CLI v2
6. Terraform
7. kubectl
8. Helm
9. AWS account
10. An EC2 key pair named `1PU`

Verify the local tools:

```
git --version
node --version
npm --version
docker --version
aws --version
terraform --version
kubectl version --client
helm version
```

# AWS CLI Setup

Configure the AWS CLI:

```
aws configure
```

Enter the IAM access key, secret access key, default region, and output format when prompted. This deployment uses the region `us-east-2`.

Verify the AWS identity:

```
aws sts get-caller-identity
```

The account number and ARN returned by this command should match the AWS account intended for the deployment.

# Running the Application Locally

Install the Node.js dependencies and start the server:

```
npm install
npm start
```

The application is available at:

```
http://localhost:3000
```

A successful request returns:

```
Hello, World!
```

# Docker Setup

Build the application image locally:

```
docker build -t node-app:latest .
```

Run the container:

```
docker run --rm -p 3000:3000 node-app:latest
```

Verify the container:

```
curl http://localhost:3000
```

# Terraform Guide

All Terraform configuration files are stored in the `aws-eks-terraform` directory. The reusable modules are stored in `aws-eks-terraform/modules`.

The root Terraform variables include:

1. AWS region
2. Project name and environment
3. VPC and subnet CIDR ranges
4. Availability zones
5. EKS cluster name and Kubernetes version
6. Managed node group instance types and scaling values
7. Jenkins instance type, EC2 key pair, and allowed CIDR blocks

Before applying the infrastructure, confirm that the `1PU` EC2 key pair exists in `us-east-2`:

```
aws ec2 describe-key-pairs --key-names 1PU --region us-east-2
```

Confirm that the S3 state bucket named in the backend configuration exists. If it does not exist, create it before running `terraform init`:

```
aws s3api create-bucket \
  --bucket tech-challenge-2-bucket \
  --region us-east-2 \
  --create-bucket-configuration LocationConstraint=us-east-2
```

Enter the Terraform directory:

```
cd aws-eks-terraform
```

Initialize Terraform:

```
terraform init
```

Format the Terraform files:

```
terraform fmt -recursive
```

Validate the configuration:

```
terraform validate
```

Preview the resources:

```
terraform plan
```

Create the infrastructure:

```
terraform apply
```

Enter `yes` when prompted.

Display the Terraform outputs:

```
terraform output
```

Terraform displays the EKS endpoint, AWS Load Balancer Controller role ARN, Jenkins URL, Jenkins instance ID, Jenkins security group ID, and Jenkins IAM role ARN.

Terraform state files, provider binaries, private keys, environment files, and Node.js dependencies must not be committed to GitHub. The repository `.gitignore` excludes these files.

# Terraform Modules

The `vpc` module creates the VPC, public and private subnets, internet gateway, NAT gateways, route tables, and Kubernetes subnet discovery tags. Public subnets host internet-facing resources. EKS worker nodes use the private subnets and reach external services through the NAT gateways.

The `eks` module creates the EKS control plane, cluster IAM role, worker-node IAM role, and managed node group. It also adds the Auto Scaling group discovery tags used by Cluster Autoscaler. The node group uses `t3.small` instances with the following scaling configuration:

```
Minimum nodes: 1
Desired nodes: 1
Maximum nodes: 4
```

The `alb` module creates the EKS OIDC provider and an IAM role for service accounts. It attaches the permissions required by the AWS Load Balancer Controller and installs the controller through its official Helm chart. Kubernetes Ingress resources then cause the controller to create and manage ALBs, listeners, target groups, security groups, and registered targets.

The `autoscaling` module installs Metrics Server and Cluster Autoscaler with Helm. Metrics Server supplies CPU and memory utilization to the HPA. Cluster Autoscaler uses IRSA and tagged managed node groups to adjust the worker-node count between one and four when pods cannot be scheduled or nodes remain underused.

The `jenkins` module creates an Amazon Linux 2023 EC2 instance, encrypted root volume, IAM instance profile, security group, and Elastic IP address. The instance role lets Jenkins push images to ECR and describe the EKS cluster. Terraform also creates an EKS access entry and associates the cluster administrator policy with the Jenkins role so the pipeline can deploy with kubectl and Helm.

# Configure kubectl

Update the local kubeconfig after Terraform creates the cluster:

```
aws eks update-kubeconfig \
  --name devops-eks-cluster \
  --region us-east-2
```

Verify access and the current node count:

```
kubectl get nodes
kubectl get nodes -o wide
```

The node group starts with one node and can scale to a maximum of four. The maximum is capacity, not a requirement to run four nodes continuously.

# Kubernetes and Helm Configuration

The Helm chart is stored in `helm/node-app`. It creates:

1. A Deployment with one initial replica
2. A NodePort Service that forwards port `80` to container port `3000`
3. Readiness and liveness probes on `/`
4. A Horizontal Pod Autoscaler
5. An ALB Ingress

The Horizontal Pod Autoscaler uses the following settings:

```
Minimum pods: 1
Maximum pods: 3
CPU target: 50%
Memory target: 50%
```

The ALB Ingress is internet-facing, uses instance targets, and checks `/` for target health. Instance mode is paired with a NodePort Service so the ALB can route traffic to the worker node.

The `kubernetes/app.yaml` file contains equivalent plain Kubernetes manifests for reference or manual deployment. Jenkins deploys the Helm chart.

# Metrics Server and Cluster Autoscaler

Terraform installs both cluster services in the `kube-system` namespace. Verify their deployments:

```
kubectl rollout status deployment/metrics-server --namespace kube-system
kubectl rollout status deployment/cluster-autoscaler-aws-cluster-autoscaler --namespace kube-system
kubectl top nodes
kubectl top pods --namespace node-app
```

If the exact Cluster Autoscaler deployment name differs in a newer chart version, locate it with:

```
kubectl get deployments --namespace kube-system | grep autoscaler
```

# Jenkins Setup

Display the Jenkins URL:

```
cd aws-eks-terraform
terraform output -raw jenkins_url
```

Move the downloaded EC2 private key to the SSH directory and restrict its permissions:

```
mv ~/Downloads/1PU.pem ~/.ssh/
chmod 400 ~/.ssh/1PU.pem
```

Connect to the Jenkins instance:

```
ssh -i ~/.ssh/1PU.pem ec2-user@JENKINS_ELASTIC_IP
```

Install Jenkins, Docker, Git, AWS CLI v2, kubectl, and Helm on the Amazon Linux 2023 instance. Start Jenkins and Docker, and ensure the `jenkins` user can run Docker commands.

Verify the required commands as the Jenkins user:

```
sudo -u jenkins git --version
sudo -u jenkins docker version
sudo -u jenkins aws --version
sudo -u jenkins kubectl version --client
sudo -u jenkins helm version
```

Open Jenkins in a browser:

```
http://JENKINS_ELASTIC_IP:8080
```

The detailed Jenkins website configuration is also documented in `jenkins/README.md`.

# Jenkins Plugins

Install the following plugins from `Manage Jenkins`, then `Plugins`:

1. Pipeline
2. Git
3. GitHub
4. Credentials Binding
5. Timestamper

Restart Jenkins if requested.

# Jenkins Credentials

The GitHub repository is private. Create a fine-grained GitHub personal access token limited to `uukomadu/devops-code-challenge2` with `Contents: Read-only` access.

Create the credential under `Manage Jenkins`, then `Credentials`, then `System`, then `Global credentials`:

```
Kind: Username with password
Username: YOUR_GITHUB_USERNAME
Password: YOUR_GITHUB_TOKEN
ID: github-credentials
```

The credential ID is case-sensitive and must exactly match `github-credentials`, which is referenced by `jenkins/pipeline.groovy`. Do not commit the token to GitHub.

AWS access keys are not stored in Jenkins. The EC2 instance profile supplies temporary AWS credentials.

# Jenkins Pipeline

Create a Pipeline job using the Jenkins website:

1. Select `New Item`.
2. Enter `devops-code-challenge2`.
3. Select `Pipeline`, then select `OK`.
4. Select `GitHub project` and enter `https://github.com/uukomadu/devops-code-challenge2/`.
5. Enable `GitHub hook trigger for GITScm polling`.
6. Under Pipeline, select `Pipeline script`.
7. Copy the complete contents of `jenkins/pipeline.groovy` into the Script box.
8. Save the job and select `Build Now`.

The pipeline performs the following stages:

1. Checks out the `main` branch from GitHub
2. Uses the first 12 characters of the Git commit SHA as an immutable image tag
3. Builds the Docker image
4. Creates the ECR repository if it does not already exist
5. Authenticates Docker to Amazon ECR
6. Pushes the commit-specific and `latest` image tags
7. Updates the Jenkins kubeconfig for the EKS cluster
8. Creates the `node-app` namespace if needed
9. Validates and deploys the Helm chart
10. Waits for the Kubernetes deployment rollout
11. Prints the pods, Service, and Ingress

# GitHub Webhook

Open the GitHub repository settings and add a webhook.

Use the following configuration:

1. Payload URL: `http://JENKINS_ELASTIC_IP:8080/github-webhook/`
2. Content type: `application/json`
3. Event: Push events
4. Active: enabled

Keep the trailing slash in `/github-webhook/`. A successful GitHub delivery displays a green check mark. Each push to `main` then starts the Jenkins pipeline automatically.

# Deploy the Application

The preferred deployment method is the Jenkins pipeline. Push a commit to `main` or select `Build Now` in Jenkins.

To deploy the chart manually, first ensure the image exists in ECR, then run:

```
aws eks update-kubeconfig \
  --name devops-eks-cluster \
  --region us-east-2

kubectl create namespace node-app \
  --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install node-app helm/node-app \
  --namespace node-app \
  --set image.repository=506570851351.dkr.ecr.us-east-2.amazonaws.com/node-app \
  --set image.tag=latest \
  --wait \
  --timeout 10m
```

# Verify the Deployment

Verify the rollout and Kubernetes resources:

```
kubectl rollout status deployment/node-app-node-app \
  --namespace node-app \
  --timeout=5m

kubectl get pods,service,ingress \
  --namespace node-app
```

Display the ALB hostname:

```
kubectl get ingress node-app-node-app \
  --namespace node-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Open the hostname in a browser or test it with curl:

```
curl http://k8s-nodeapp-nodeappn-01de46926b-31407617.us-east-2.elb.amazonaws.com/
```

A successful deployment returns:

```
Hello, World!
```

# Verify Autoscaling

Check the node group configuration:

```
aws eks describe-nodegroup \
  --cluster-name devops-eks-cluster \
  --nodegroup-name standard_workers \
  --region us-east-2 \
  --query 'nodegroup.scalingConfig'
```

Check the current nodes, pods, and HPA:

```
kubectl get nodes
kubectl get pods --namespace node-app -o wide
kubectl get hpa --namespace node-app
```

The HPA controls the total application replica count from one to three. A required hostname topology-spread constraint permits one application replica per worker node, so additional HPA replicas remain pending until Cluster Autoscaler adds capacity. Cluster Autoscaler independently controls the managed node group from one to four nodes. HPA does not provide a per-node replica limit; it sets the workload's total replicas.

Monitor both scaling layers during a load test:

```
watch kubectl get nodes,pods,hpa --namespace node-app
```

View Cluster Autoscaler decisions:

```
kubectl logs deployment/cluster-autoscaler-aws-cluster-autoscaler \
  --namespace kube-system \
  --tail=200
```

# Troubleshooting

If the ALB displays `503 Service Temporarily Unavailable`, check the Ingress, Service endpoints, controller logs, and target health:

```
kubectl describe ingress node-app-node-app --namespace node-app
kubectl get endpoints node-app-node-app --namespace node-app
kubectl logs deployment/aws-load-balancer-controller \
  --namespace kube-system \
  --tail=200
```

In the AWS console, open `EC2`, then `Target Groups`, select the Kubernetes target group, and confirm the registered target is healthy.

If the controller reports `ec2:DescribeInstances` or another denied action, apply the current ALB IAM policy and restart the controller if needed:

```
cd aws-eks-terraform
terraform apply -target=module.alb.aws_iam_policy.controller

kubectl rollout restart deployment/aws-load-balancer-controller \
  --namespace kube-system
```

If Terraform reports that the EKS cluster authentication mode does not support access entries, enable API authentication once:

```
aws eks update-cluster-config \
  --name devops-eks-cluster \
  --region us-east-2 \
  --access-config authenticationMode=API_AND_CONFIG_MAP

aws eks wait cluster-active \
  --name devops-eks-cluster \
  --region us-east-2
```

If Terraform reports that the AWS Load Balancer Controller Helm release name is already in use, import the existing release into Terraform state or remove the unmanaged release before applying again. Do not create a second controller with the same name.

# Security Improvements

The following changes are recommended for a production deployment:

1. Configure HTTPS using a domain, ACM certificate, and ALB HTTPS listener.
2. Redirect HTTP traffic to HTTPS.
3. Restrict Jenkins ports `22` and `8080` to trusted CIDR ranges or place Jenkins behind an authenticated reverse proxy.
4. Keep GitHub tokens in Jenkins credentials and rotate them regularly.
5. Continue using EC2 instance-profile credentials instead of long-lived AWS keys.
6. Reduce the Jenkins EKS permissions from cluster administrator to the required namespaces and resources.
7. Enable S3 bucket versioning and restrict access to the Terraform state bucket.
8. Add CloudWatch alarms for unhealthy targets, failed deployments, and high utilization.
9. Add Pod Disruption Budgets for critical workloads before using this design in production.

# Cleanup

Destroy the Terraform-managed resources when they are no longer needed:

```
cd aws-eks-terraform
terraform destroy
```

The EKS cluster currently uses `prevent_destroy = true`. Remove that lifecycle protection only when the cluster is intentionally being retired, then run `terraform destroy` again.

Review the destroy plan before approving it. Confirm that the EKS cluster, node group, load balancer, target groups, NAT gateways, Elastic IP addresses, Jenkins instance, and ECR images have been removed to avoid additional AWS charges.

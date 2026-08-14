# Jenkins Pipeline Setup

The pipeline is configured through the Jenkins website. The repository keeps
`pipeline.groovy` as a reviewed, copy-and-paste source for the UI definition;
Jenkins does not load a root `Jenkinsfile`.

## 0. Enable EKS access entries in place

For an existing cluster, enable API authentication without asking Terraform to
replace the cluster:

```bash
aws eks update-cluster-config \
  --name devops-eks-cluster \
  --region us-east-2 \
  --access-config authenticationMode=API_AND_CONFIG_MAP

aws eks wait cluster-active \
  --name devops-eks-cluster \
  --region us-east-2
```

Run this once before applying the Jenkins EKS access entry. The EKS Terraform
resource has `prevent_destroy = true` to protect the cluster and its node group.

## 1. Prepare the Jenkins server

SSH to the Amazon Linux 2023 Jenkins instance and install Jenkins, Docker,
Git, AWS CLI, kubectl, and Helm. Confirm the Jenkins user can run each command:

```bash
sudo -u jenkins git --version
sudo -u jenkins docker version
sudo -u jenkins aws --version
sudo -u jenkins kubectl version --client
sudo -u jenkins helm version
```

The EC2 instance profile supplies temporary AWS credentials. Do not store AWS
access keys in Jenkins.

## 2. Install Jenkins plugins

In **Manage Jenkins → Plugins**, install:

- Pipeline
- Git
- GitHub
- Credentials Binding
- Timestamper

Restart Jenkins if requested.

## 3. Add the GitHub credential

Because the repository is private, create a fine-grained GitHub personal
access token limited to `uukomadu/devops-code-challenge2` with **Contents:
Read-only** access. In **Manage Jenkins → Credentials → System → Global
credentials**, add:

- Kind: Username with password
- Username: your GitHub username
- Password: the GitHub token
- ID: `github-credentials`

Never commit this token to the repository.

## 4. Create the Pipeline job

1. Select **New Item**.
2. Enter `devops-code-challenge2`.
3. Select **Pipeline**, then **OK**.
4. In **General**, select **GitHub project** and enter:
   `https://github.com/uukomadu/devops-code-challenge2/`
5. Under **Build Triggers**, select **GitHub hook trigger for GITScm polling**.
6. Under **Pipeline**, select **Pipeline script**.
7. Copy the complete contents of `jenkins/pipeline.groovy` into the Script box.
8. Select **Save**, then **Build Now** once to confirm repository access.

## 5. Add the GitHub webhook

In GitHub, open **Settings → Webhooks → Add webhook** for the repository and
configure:

- Payload URL: `http://JENKINS_ELASTIC_IP:8080/github-webhook/`
- Content type: `application/json`
- Events: **Just the push event**
- Active: enabled

Replace `JENKINS_ELASTIC_IP` with Terraform's `jenkins_url` host. Keep the
trailing slash in `/github-webhook/`. After saving, GitHub should show a green
delivery. A push to `main` will then start the Pipeline job automatically.

The project security group currently permits public port 8080 access so GitHub
can deliver the webhook and the mentor can view Jenkins. Use HTTPS and tighter
network controls for a long-lived environment.

The job checks out `main`, builds the Docker image, pushes commit and `latest`
tags to ECR, connects to EKS with kubectl, deploys the Helm release, and waits
for the rollout to complete.

## 6. Verify

The final Jenkins stage prints the pods, service, and ALB Ingress. The deployed
image tag is the first 12 characters of the Git commit SHA, making each release
traceable and suitable for Helm rollback.

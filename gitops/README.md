# GitOps Alternative

This branch keeps the Jenkins implementation intact on `main` and provides the
required GitOps alternative with GitHub Actions and Argo CD.

## Flow

1. A push to `gitops` starts `.github/workflows/gitops-ci.yaml`.
2. GitHub exchanges its OIDC token for the least-privilege AWS IAM role created
   by the Terraform `gitops` module.
3. The workflow builds the Docker image and pushes the commit SHA and `latest`
   tags to Amazon ECR.
4. The workflow writes the immutable commit SHA to
   `helm/node-app/values.yaml` and commits that desired state to `gitops`.
5. Argo CD detects the commit and automatically synchronizes the Helm chart to
   the `node-app` namespace in EKS.

## Bootstrap

Apply Terraform from the GitOps branch to install Argo CD and create the GitHub
Actions OIDC role:

```bash
cd gitops/terraform
terraform init
terraform plan
terraform apply
```

This bootstrap uses `gitops/terraform-state-file` in the existing S3 state
bucket. Its state is intentionally separate from the Jenkins infrastructure
state, so applying either branch cannot remove resources owned by the other.

Copy the role ARN from Terraform:

```bash
terraform output -raw github_actions_role_arn
```

In the GitHub repository, create the Actions variable
`AWS_GITHUB_ACTIONS_ROLE_ARN` and set it to that ARN. This is not a secret; the
role trust policy restricts it to this repository and the `gitops` branch.

Because this repository is private, register it with Argo CD without committing
credentials:

```bash
argocd repo add https://github.com/uukomadu/devops-code-challenge2.git \
  --username uukomadu \
  --password "$GITHUB_TOKEN"
```

The token should be a fine-grained GitHub token limited to this repository with
read-only Contents access. Keep it out of Git and shell history.

Create the Argo CD Application once:

```bash
kubectl apply -f gitops/argocd/application.yaml
```

Trigger the first build from **Actions → GitOps CI → Run workflow**, or push an
application change to `gitops`.

## Verification

```bash
kubectl get pods -n argocd
kubectl get application node-app -n argocd
argocd app get node-app
kubectl get pods,service,ingress,hpa -n node-app
```

The application should report `Synced` and `Healthy`. The workload image tag
should match the Git commit SHA written to `helm/node-app/values.yaml`.

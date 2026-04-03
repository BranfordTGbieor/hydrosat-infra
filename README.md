# Hydrosat Infrastructure

Infrastructure repository for the Hydrosat Dagster platform.

This repo owns:

- AWS infrastructure provisioned with Terraform
- the Dagster Helm chart and runtime configuration
- Argo CD GitOps applications
- observability stack manifests and values
- External Secrets configuration
- infrastructure CI and governed Terraform delivery

The Dagster application source code is intended to live in a separate `hydrosat-data` repository. This infra repo consumes a pre-built container image, and Argo CD reconciles the Helm release from Git.

## Layout

| Path | Purpose |
| --- | --- |
| `terraform/` | Main AWS platform stack |
| `terraform/bootstrap/` | Remote-state bootstrap stack |
| `terraform/modules/` | Reusable infrastructure modules |
| `helm/dagster/` | Dagster Helm chart |
| `gitops/argocd/` | Argo CD bootstrap, apps, and values |
| `gitops/external-secrets/` | External Secrets resources |
| `.github/workflows/ci.yml` | Infra validation workflow |
| `.github/workflows/terraform-delivery.yml` | Governed Terraform plan/apply workflow |

## Operating Model

- the application image is built and published from the separate app repo
- this infra repo owns the image tag or values consumed by Helm and Argo CD
- Argo CD is the steady-state deployment path
- Terraform apply is separated from general CI and intended to be environment-gated

## Validation

```bash
terraform fmt -check -recursive terraform terraform/bootstrap

cd terraform/bootstrap
terraform init -backend=false
terraform validate

cd ../
terraform init -backend=false
terraform validate

cd ..
helm lint helm/dagster
helm template hydrosat-dagster helm/dagster
```

## Notes

- the repo stays cost-conscious by default for demo use
- `db_multi_az` is intentionally disabled by default and documented as a production override
- Docker Hub can be used as the image registry to mirror the team’s stated tooling

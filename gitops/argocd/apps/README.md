# Argo CD Applications

Argo CD is the primary steady-state deployment path for this repository.

Bootstrap model:

1. Install Argo CD in the same EKS cluster for demo simplicity.
2. Replace `REPLACE_WITH_GIT_REPOSITORY_URL` in:
   - `gitops/argocd/bootstrap/root-application.yaml`
   - `gitops/argocd/apps/project.yaml`
   - `gitops/argocd/apps/hydrosat-dagster.yaml`
3. Replace the AWS-specific placeholders in:
   - `gitops/argocd/values/external-secrets-values.yaml`
   - `gitops/external-secrets/cluster-secret-store.yaml`
   - `gitops/external-secrets/dagster-db-external-secret.yaml`
   - `gitops/external-secrets/alertmanager-config-external-secret.yaml`
4. Apply `gitops/argocd/bootstrap/root-application.yaml`.

What the root application manages:

- `gitops/argocd/apps/project.yaml`
- `gitops/argocd/apps/external-secrets-operator.yaml`
- `gitops/argocd/apps/external-secrets-resources.yaml`
- `gitops/argocd/apps/hydrosat-dagster.yaml`
- `gitops/argocd/apps/monitoring-kube-prometheus-stack.yaml`
- `gitops/argocd/apps/monitoring-loki.yaml`
- `gitops/argocd/apps/monitoring-alloy.yaml`

Sync ordering:

- wave `-1`: Argo CD project
- wave `0`: External Secrets Operator
- wave `1`: ExternalSecret and ClusterSecretStore resources
- wave `2`: Dagster application, kube-prometheus-stack, Loki
- wave `3`: Alloy

Design note:

- same-cluster Argo CD is intentional for this take-home to reduce bootstrap overhead
- a separate management cluster is the better long-term pattern for larger estates

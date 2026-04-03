# Hydrosat Infrastructure Validation Runbook

This runbook is a high-fidelity, end-to-end validation guide for the `hydrosat-infra` repository. It is intentionally redundant with the main README and optimized for stepwise system verification.

Use this document when you want to prove that:

- Terraform configuration is valid
- AWS infrastructure provisions correctly
- the EKS cluster is reachable
- the S3-backed data lake bucket and Dagster IRSA role are provisioned correctly
- Argo CD can reconcile the platform
- External Secrets can sync runtime secrets
- Dagster can start against RDS
- monitoring, logging, and alerting are functioning

This runbook assumes:

- repo root is `hydrosat-infra/`
- AWS credentials are available locally or via an assumed role
- `kubectl`, `helm`, `terraform`, `aws`, `docker`, and `argocd` are installed
- the separate `hydrosat-data` repo has already produced a Docker image tag you can reference

## 1. Validation Order

Run these sections in order:

1. Local static validation
2. Placeholder replacement validation
3. GitHub Environment protection validation
4. Bootstrap backend validation
5. Platform Terraform validation
6. Terraform plan and apply
7. Cluster access validation
8. Data lake and IRSA validation
9. GitOps and Argo CD validation
10. External Secrets validation
11. Dagster runtime validation
12. Monitoring and logging validation
13. Alerting validation
14. Negative-path validation
15. Destroy and cleanup validation

## 2. Test Fixtures and Placeholder Values

Create a working copy of the example vars:

```bash
cd /home/branford-t-gbieor/Desktop/gbieor/applications/exercises/hydrosat/hydrosat-infra
cp terraform/bootstrap/terraform.tfvars.example terraform/bootstrap/terraform.tfvars
cp terraform/backend.hcl.example terraform/backend.hcl
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Suggested demo test values:

| Component | Sample value |
| --- | --- |
| `project_name` | `hydrosat` |
| `environment` | `dev` |
| `aws_region` | `us-east-1` |
| `cluster_endpoint_public_access_cidrs` | `["203.0.113.10/32"]` |
| Dagster image | `docker.io/<your-user>/hydrosat-dagster:v0.1.0` |
| Data lake bucket | value returned by Terraform output `data_lake_bucket_name` |
| Slack webhook secret name | `hydrosat/dev/alertmanager` |
| RDS secret name | value returned by Terraform output `rds_master_secret_arn` |

Update `terraform/terraform.tfvars` with real values for your environment.

Update [helm/dagster/values-gitops.yaml](/home/branford-t-gbieor/Desktop/gbieor/applications/exercises/hydrosat/hydrosat-infra/helm/dagster/values-gitops.yaml) before Argo CD sync:

```yaml
image:
  repository: docker.io/<your-user>/hydrosat-dagster
  tag: v0.1.0

database:
  host: <terraform-rds-address>
```

Update [gitops/argocd/apps/hydrosat-dagster.yaml](/home/branford-t-gbieor/Desktop/gbieor/applications/exercises/hydrosat/hydrosat-infra/gitops/argocd/apps/hydrosat-dagster.yaml):

```yaml
spec:
  source:
    repoURL: git@github.com:BranfordTGbieor/hydrosat-infra.git
```

## 3. Placeholder Replacement Validation

### 3.1 Component: Remaining Placeholder Inventory

Commands:

```bash
rg -n "REPLACE_WITH" .
```

Expected success:

- the output only shows files you intentionally have not populated yet for the current demo environment
- you understand each remaining placeholder before attempting a real apply or Argo CD sync

Failure signs:

- placeholder values remain in files that will be used immediately for the live demo
- the same runtime value must be replaced in multiple places and has not been reconciled

### 3.2 Component: Live Demo Replacement Surface

Critical files to check:

- `helm/dagster/values-gitops.yaml`
- `gitops/argocd/bootstrap/root-application.yaml`
- `gitops/argocd/apps/project.yaml`
- `gitops/argocd/apps/hydrosat-dagster.yaml`
- `gitops/argocd/apps/external-secrets-operator.yaml`
- `gitops/argocd/apps/external-secrets-resources.yaml`
- `gitops/argocd/apps/monitoring-kube-prometheus-stack.yaml`
- `gitops/argocd/apps/monitoring-loki.yaml`
- `gitops/argocd/apps/monitoring-alloy.yaml`
- `gitops/external-secrets/cluster-secret-store.yaml`
- `gitops/external-secrets/dagster-db-external-secret.yaml`
- `gitops/external-secrets/alertmanager-config-external-secret.yaml`
- `gitops/argocd/values/external-secrets-values.yaml`
- `gitops/argocd/values/kube-prometheus-stack-values.yaml`

Expected success:

- Git repository URLs point at the real `hydrosat-infra` repo
- RDS secret ARN, Alertmanager notifier secret ARN, AWS region, bucket, IRSA role ARN, and RDS host are all populated
- Grafana admin password placeholder is removed for the demo environment

Failure signs:

- Argo CD bootstrap points at the wrong repo
- External Secrets references stale or fake ARNs
- Dagster values still reference placeholder bucket, host, or role values

## 4. GitHub Environment Protection Validation

### 4.1 Component: Environment Inventory

Manual checks in GitHub:

- repository `Settings`
- `Environments`

Expected success:

- `dev`, `qa`, and `prod` environments exist
- environment names match the branch-to-environment mapping in `terraform-delivery.yml`

Failure signs:

- missing environments
- mismatched naming such as `production` instead of `prod`

### 4.2 Component: Protection Rules

Manual checks in GitHub:

- required reviewers for `qa` and `prod`
- optional reviewer gate for `dev`
- wait timer only if your team explicitly wants it

Expected success:

- `Terraform Apply` requires environment approval before execution
- reviewer expectations differ sensibly by environment criticality

Failure signs:

- `workflow_dispatch` can apply to `prod` without reviewer approval
- reviewers are configured on the wrong environment

### 4.3 Component: Environment Variables

Manual checks in GitHub:

- `AWS_TERRAFORM_ROLE_ARN`
- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`
- `AWS_REGION`

Expected success:

- the variables exist at repository or environment scope
- higher environments can override lower-environment values safely

Failure signs:

- `Terraform Plan Skipped` runs because delivery variables are absent
- apply targets the wrong region, bucket, or IAM role

## 5. Local Static Validation

### 5.1 Component: Repo Hygiene

Commands:

```bash
git status --short
find . -maxdepth 3 -type f | sort | head -50
```

Expected success:

- only intentional local files such as `terraform.tfvars`, `backend.hcl`, or local notes are untracked
- repo layout includes `terraform/`, `helm/`, `gitops/`, and `.github/workflows/`

Failure signs:

- unexpected deleted or modified tracked files
- missing core directories

### 5.2 Component: Terraform Formatting and Validation

Commands:

```bash
terraform fmt -check -recursive terraform terraform/bootstrap
terraform -chdir=terraform/bootstrap init -backend=false
terraform -chdir=terraform/bootstrap validate
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform validate
```

Expected success:

- `terraform fmt -check` exits `0`
- each `validate` command ends with `Success! The configuration is valid.`

Failure signs:

- formatting diffs printed by `terraform fmt -check`
- missing variables
- provider initialization errors
- syntax errors in module blocks or outputs

### 5.3 Component: Helm Packaging

Commands:

```bash
helm lint ./helm/dagster
helm template hydrosat-dagster ./helm/dagster > /tmp/hydrosat-dagster-rendered.yaml
```

Expected success:

- `helm lint` prints `1 chart(s) linted, 0 chart(s) failed`
- rendered file contains `Deployment`, `Service`, `Job`, `NetworkPolicy`, and `PodDisruptionBudget`

Failure signs:

- template rendering errors
- unresolved values
- invalid YAML in templates

Quick verification:

```bash
rg "kind: (Deployment|Job|NetworkPolicy|PodDisruptionBudget)" /tmp/hydrosat-dagster-rendered.yaml
```

### 5.4 Component: GitOps and Observability Chart Rendering

Commands:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm template hydrosat-monitoring prometheus-community/kube-prometheus-stack \
  --version 82.16.0 \
  -f gitops/argocd/values/kube-prometheus-stack-values.yaml \
  > /tmp/hydrosat-monitoring-rendered.yaml

helm template hydrosat-loki grafana/loki \
  --version 6.53.0 \
  -f gitops/argocd/values/loki-values.yaml \
  > /tmp/hydrosat-loki-rendered.yaml

helm template hydrosat-alloy grafana/alloy \
  --version 1.5.3 \
  -f gitops/argocd/values/alloy-values.yaml \
  > /tmp/hydrosat-alloy-rendered.yaml

helm template hydrosat-external-secrets external-secrets/external-secrets \
  --version 2.2.0 \
  -f gitops/argocd/values/external-secrets-values.yaml \
  > /tmp/hydrosat-external-secrets-rendered.yaml
```

Expected success:

- all four commands exit `0`
- rendered monitoring output contains Alertmanager, Prometheus, and Grafana objects
- rendered External Secrets output contains CRDs or controller resources from the chart

Failure signs:

- missing chart repo
- bad values structure
- version mismatch

## 6. Bootstrap Backend Validation

### 6.1 Component: Remote State Bootstrap Stack

Files:

- [terraform/bootstrap/main.tf](/home/branford-t-gbieor/Desktop/gbieor/applications/exercises/hydrosat/hydrosat-infra/terraform/bootstrap/main.tf)
- [terraform/backend.hcl.example](/home/branford-t-gbieor/Desktop/gbieor/applications/exercises/hydrosat/hydrosat-infra/terraform/backend.hcl.example)

Commands:

```bash
terraform -chdir=terraform/bootstrap plan
terraform -chdir=terraform/bootstrap apply
terraform -chdir=terraform/bootstrap output
```

Expected success:

- plan shows S3 bucket and DynamoDB table resources for Terraform state
- apply finishes with `Apply complete!`
- outputs include backend bucket and lock table names

Failure signs:

- bucket name collision
- insufficient AWS permissions
- invalid region or provider authentication failure

## 7. Platform Terraform Validation

### 7.1 Component: Main Platform Stack

Files:

- [terraform/main.tf](/home/branford-t-gbieor/Desktop/gbieor/applications/exercises/hydrosat/hydrosat-infra/terraform/main.tf)
- [terraform/variables.tf](/home/branford-t-gbieor/Desktop/gbieor/applications/exercises/hydrosat/hydrosat-infra/terraform/variables.tf)
- [terraform/outputs.tf](/home/branford-t-gbieor/Desktop/gbieor/applications/exercises/hydrosat/hydrosat-infra/terraform/outputs.tf)

Commands:

```bash
terraform -chdir=terraform init -backend-config=backend.hcl
terraform -chdir=terraform plan
```

Expected success:

- init completes successfully against the remote backend
- plan includes VPC, subnets, NAT, EKS, node group, IAM roles, RDS, and platform resources
- no undeclared variable warnings remain in your local `terraform.tfvars`

Failure signs:

- backend authentication failure
- module/provider download failure
- undeclared vars such as stale `enable_alerting` or `alert_email_endpoint`
- invalid CIDR or AZ configuration

### 7.2 Component: Apply the Main Stack

Commands:

```bash
terraform -chdir=terraform apply
terraform -chdir=terraform output
```

Expected success:

- apply completes without errors
- outputs include:
  - `cluster_name`
  - `aws_region`
  - `data_lake_bucket_name`
  - `dagster_service_account_role_arn`
  - `rds_address`
  - `rds_master_secret_arn`
  - `kubectl_config_command`

Failure signs:

- EKS node group creation failure
- RDS subnet/security-group issues
- IAM trust-policy or OIDC issues for External Secrets

## 8. Cluster Access Validation

### 8.1 Component: EKS Access

Sample command from Terraform output:

```bash
aws eks update-kubeconfig --region us-east-1 --name hydrosat-dev
kubectl config current-context
kubectl get nodes -o wide
```

Expected success:

- context switches to the new cluster
- `kubectl get nodes` shows Ready nodes

Failure signs:

- `You must be logged in to the server`
- public endpoint CIDR mismatch
- missing IAM auth mapping

### 8.2 Component: Core Namespaces

Commands:

```bash
kubectl get ns
kubectl get ns argocd dagster monitoring external-secrets
```

Expected success:

- namespaces exist after bootstrap and Argo CD sync

Failure signs:

- namespace not found
- Argo CD app not yet synced

## 9. Data Lake and IRSA Validation

### 9.1 Component: S3 Data Lake Bucket

Commands:

```bash
terraform -chdir=terraform output data_lake_bucket_name
terraform -chdir=terraform output data_lake_bucket_arn
aws s3api head-bucket --bucket "$(terraform -chdir=terraform output -raw data_lake_bucket_name)"
```

Expected success:

- Terraform outputs a bucket name and ARN
- `head-bucket` exits successfully

Failure signs:

- bucket missing
- access denied due to wrong AWS credentials or wrong account

### 9.2 Component: Dagster IRSA Role

Commands:

```bash
terraform -chdir=terraform output dagster_service_account_role_arn
kubectl get sa hydrosat-dagster -n dagster -o yaml
```

Expected success:

- Terraform outputs a valid IAM role ARN
- the Dagster service account annotation includes `eks.amazonaws.com/role-arn`

Failure signs:

- role output missing
- service account annotation absent or still placeholder-valued

## 10. GitOps and Argo CD Validation

### 10.1 Component: Argo CD Bootstrap

Commands:

```bash
kubectl apply -n argocd -f gitops/argocd/bootstrap/root-application.yaml
kubectl get applications -n argocd
kubectl describe application root-applications -n argocd
```

Expected success:

- root application exists in `argocd`
- child apps appear:
  - `hydrosat-dagster`
  - `monitoring-kube-prometheus-stack`
  - `monitoring-loki`
  - `monitoring-alloy`
  - `external-secrets-operator`
  - `external-secrets-resources`

Failure signs:

- invalid Git repo URL
- missing SSH credentials or repo access in Argo CD
- application stuck in `Unknown` or `OutOfSync`

### 10.2 Component: Argo CD Sync Health

Commands:

```bash
kubectl get applications -n argocd
argocd app list
argocd app get hydrosat-dagster
argocd app wait hydrosat-dagster --health --sync
```

Expected success:

- apps are `Synced` and `Healthy`
- no repeated reconciliation errors

Failure signs:

- `Missing` resources
- Helm render failure inside Argo CD
- unhealthy child apps due to invalid values or unavailable image

## 11. External Secrets Validation

### 11.1 Component: AWS Secrets Manager Inputs

Create or verify the alertmanager config secret value. Example payload:

```yaml
global:
  resolve_timeout: 5m
route:
  receiver: slack
receivers:
  - name: slack
    slack_configs:
      - api_url: https://hooks.slack.com/services/T000/B000/XXXX
        channel: "#hydrosat-alerts"
        send_resolved: true
```

Recommended command shape:

```bash
aws secretsmanager put-secret-value \
  --secret-id hydrosat/dev/alertmanager \
  --secret-string file://alertmanager-config.yaml
```

Expected success:

- AWS returns a new version id

Failure signs:

- secret does not exist
- malformed YAML string if manually escaped incorrectly

### 11.2 Component: ClusterSecretStore

Commands:

```bash
kubectl get clustersecretstore
kubectl describe clustersecretstore aws-secretsmanager
```

Expected success:

- store is present and reports valid provider configuration

Failure signs:

- auth errors against AWS
- service account IRSA annotation missing

### 11.3 Component: ExternalSecret Resources

Commands:

```bash
kubectl get externalsecret -A
kubectl describe externalsecret hydrosat-dagster-db -n dagster
kubectl describe externalsecret hydrosat-alertmanager-config -n monitoring
kubectl get secret hydrosat-dagster-db -n dagster -o yaml
kubectl get secret hydrosat-alertmanager-config -n monitoring -o yaml
```

Expected success:

- both ExternalSecrets show a recent successful refresh time
- `hydrosat-dagster-db` secret exists in `dagster`
- `hydrosat-alertmanager-config` secret exists in `monitoring`

Failure signs:

- `SecretSyncedError`
- `AccessDeniedException`
- target secret absent or empty

## 12. Dagster Runtime Validation

### 12.1 Component: Helm-Managed Dagster Workloads

Commands:

```bash
kubectl get deploy,po,svc,pdb,job -n dagster
kubectl rollout status deploy/hydrosat-dagster-webserver -n dagster
kubectl rollout status deploy/hydrosat-dagster-daemon -n dagster
kubectl rollout status deploy/hydrosat-dagster-user-code -n dagster
```

Expected success:

- webserver, daemon, and user-code deployments are `Available`
- migration job completes successfully
- services exist for webserver and user-code

Failure signs:

- `ImagePullBackOff`
- migration job crash loop
- `CreateContainerConfigError` due to missing DB secret or Alertmanager URL

### 12.2 Component: Dagster Web UI Reachability

Commands:

```bash
kubectl get svc hydrosat-dagster-webserver -n dagster
kubectl port-forward svc/hydrosat-dagster-webserver 3000:3000 -n dagster
```

Open:

```text
http://127.0.0.1:3000
```

Expected success:

- Dagster UI loads
- `hydrosat_demo_job` is visible
- no startup errors shown in daemon or webserver logs

Failure signs:

- connection refused
- webserver pods not Ready
- RDS connectivity errors in logs

### 12.3 Component: RDS Connectivity from Dagster

Commands:

```bash
kubectl logs deploy/hydrosat-dagster-webserver -n dagster --tail=100
kubectl logs deploy/hydrosat-dagster-daemon -n dagster --tail=100
kubectl logs job/hydrosat-dagster-migrate -n dagster --tail=100
```

Expected success:

- no repeated authentication or network failures
- migration logs show successful schema migration or no-op completion

Failure signs:

- `password authentication failed`
- `could not connect to server`
- `relation does not exist`

### 12.4 Component: Data Lake Environment Wiring

Commands:

```bash
kubectl get deploy hydrosat-dagster-user-code -n dagster -o yaml | rg "HYDROSAT_DATA_LAKE_(BUCKET|PREFIX)"
kubectl get sa hydrosat-dagster -n dagster -o yaml | rg "eks.amazonaws.com/role-arn"
```

Expected success:

- the user-code deployment includes `HYDROSAT_DATA_LAKE_BUCKET`
- the user-code deployment includes `HYDROSAT_DATA_LAKE_PREFIX`
- the Dagster service account includes the IRSA role annotation

Failure signs:

- missing lake env vars
- missing service account role annotation

## 13. Monitoring and Logging Validation

### 13.1 Component: Monitoring Stack Pods

Commands:

```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

Expected success:

- Prometheus, Alertmanager, Grafana, Loki gateway, and Alloy are running

Failure signs:

- pending pods due to storage or scheduling issues
- crash looping Grafana or Alertmanager pods

### 13.2 Component: Grafana Reachability

Commands:

```bash
kubectl port-forward svc/hydrosat-monitoring-grafana 3001:80 -n monitoring
```

Open:

```text
http://127.0.0.1:3001
```

Expected success:

- Grafana login page loads
- Loki appears as a configured data source

Failure signs:

- service not found
- Grafana pod not ready

### 13.3 Component: Prometheus Rule Presence

Commands:

```bash
kubectl get prometheusrule -n monitoring
kubectl get prometheusrule hydrosat-monitoring-hydrosat-dagster -n monitoring -o yaml
```

Expected success:

- rules include:
  - `DagsterWebserverUnavailable`
  - `DagsterUserCodeUnavailable`
  - `DagsterPodsRestartingFrequently`

Failure signs:

- rules absent because chart rendering or Argo CD sync failed

### 13.4 Component: Loki Log Availability

Commands:

```bash
kubectl logs -n monitoring deploy/hydrosat-alloy --tail=100
kubectl logs -n monitoring statefulset/hydrosat-loki-backend --tail=100
```

Expected success:

- Alloy shows successful shipping behavior
- Loki backend logs do not show repeated ingestion failures

Failure signs:

- remote write or push errors
- DNS or service-discovery failures

## 14. Alerting Validation

### 14.1 Component: Alertmanager API Reachability

Sample test payload:

```json
[
  {
    "labels": {
      "alertname": "ManualSmokeTest",
      "severity": "warning",
      "service": "runbook"
    },
    "annotations": {
      "summary": "Manual smoke alert",
      "description": "Verifies Alertmanager API reachability from the cluster"
    },
    "startsAt": "2026-04-03T10:00:00Z"
  }
]
```

Commands:

```bash
kubectl run am-curl --rm -it --restart=Never -n monitoring \
  --image=curlimages/curl:8.7.1 \
  --command -- sh
```

Inside the temporary shell:

```bash
cat <<'EOF' >/tmp/alert.json
[
  {
    "labels": {
      "alertname": "ManualSmokeTest",
      "severity": "warning",
      "service": "runbook"
    },
    "annotations": {
      "summary": "Manual smoke alert",
      "description": "Verifies Alertmanager API reachability from the cluster"
    },
    "startsAt": "2026-04-03T10:00:00Z"
  }
]
EOF

curl -i -X POST \
  -H 'Content-Type: application/json' \
  --data @/tmp/alert.json \
  http://hydrosat-monitoring-alertmanager.monitoring.svc.cluster.local:9093/api/v2/alerts
```

Expected success:

- HTTP response `200 OK`
- alert appears in Alertmanager UI shortly after
- downstream Slack or email receiver receives the notification if configured

Failure signs:

- `404` due to wrong path
- `503` due to Alertmanager not ready
- no downstream delivery because receiver config secret is invalid

### 14.2 Component: Prometheus-Driven Alert Path

Commands:

```bash
kubectl scale deploy/hydrosat-dagster-user-code -n dagster --replicas=0
kubectl get deploy hydrosat-dagster-user-code -n dagster -w
```

Expected success:

- after rule threshold is met, Alertmanager receives `DagsterUserCodeUnavailable`

Failure signs:

- alert never fires because Prometheus rule is missing
- alert fires but no receiver notification occurs

Rollback:

```bash
kubectl scale deploy/hydrosat-dagster-user-code -n dagster --replicas=1
kubectl rollout status deploy/hydrosat-dagster-user-code -n dagster
```

## 15. Negative-Path Validation

### 15.1 Component: Secret Sync Failure Detection

Induce a failure by referencing a nonexistent AWS secret in a temporary test ExternalSecret.

Sample manifest:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: invalid-secret-test
  namespace: dagster
spec:
  refreshInterval: 1m
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-secretsmanager
  target:
    name: invalid-secret-test
  data:
    - secretKey: password
      remoteRef:
        key: does/not/exist
```

Commands:

```bash
kubectl apply -f invalid-secret-test.yaml
kubectl describe externalsecret invalid-secret-test -n dagster
kubectl delete -f invalid-secret-test.yaml
```

Expected success:

- failure is visible and diagnosable
- operator reports sync error clearly

Failure signs:

- no status updates at all, suggesting controller issues

### 15.2 Component: Dagster Image Pull Failure Detection

Induce a failure by setting a bogus image tag in [helm/dagster/values-gitops.yaml](/home/branford-t-gbieor/Desktop/gbieor/applications/exercises/hydrosat/hydrosat-infra/helm/dagster/values-gitops.yaml), syncing Argo CD, and observing the resulting failure.

Sample bad value:

```yaml
image:
  repository: docker.io/<your-user>/hydrosat-dagster
  tag: does-not-exist
```

Commands:

```bash
argocd app sync hydrosat-dagster
kubectl get pods -n dagster
kubectl describe pod -n dagster <failing-pod-name>
```

Expected success:

- pods enter `ImagePullBackOff`
- error is visible in Argo CD and Kubernetes events

Failure signs:

- silent success despite invalid image tag, which would indicate cached or stale values

Rollback:

- restore the correct image tag
- sync Argo CD again

## 16. Destroy and Cleanup Validation

### 16.1 Component: Terraform Destroy

Commands:

```bash
terraform -chdir=terraform plan -destroy
terraform -chdir=terraform destroy
```

Expected success:

- EKS, node groups, NAT, RDS, and related resources are removed

Failure signs:

- dangling Kubernetes-managed AWS load balancers
- security groups in use
- lingering ENIs or finalizers

### 16.2 Component: Bootstrap Destroy

Only do this after the main platform stack is gone and state has been migrated or no longer needed.

Commands:

```bash
terraform -chdir=terraform/bootstrap plan -destroy
terraform -chdir=terraform/bootstrap destroy
```

Expected success:

- state bucket and lock table are removed

Failure signs:

- bucket not empty
- state backend still in use

## 17. Completion Criteria

You can treat infra validation as complete when all of the following are true:

- Terraform bootstrap and platform stacks both validate and apply cleanly
- EKS cluster is reachable
- the S3 data lake bucket exists and Dagster IRSA is configured
- Argo CD apps are `Synced` and `Healthy`
- External Secrets syncs both Dagster DB and Alertmanager config secrets
- Dagster deployments are healthy
- Dagster can connect to RDS
- Grafana, Prometheus, Alertmanager, Loki, and Alloy are running
- Alertmanager accepts manual test alerts
- at least one negative-path test produces a clear, diagnosable failure

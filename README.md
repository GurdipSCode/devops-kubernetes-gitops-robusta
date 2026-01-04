# Robusta K3s ArgoCD Repository

[![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=flat-square&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![K3s](https://img.shields.io/badge/k3s-FFC61C?style=flat-square&logo=k3s&logoColor=black)](https://k3s.io/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=flat-square&logo=argo&logoColor=white)](https://argoproj.github.io/cd/)
[![VictoriaMetrics](https://img.shields.io/badge/VictoriaMetrics-621773?style=flat-square&logo=prometheus&logoColor=white)](https://victoriametrics.com/)
[![Robusta](https://img.shields.io/badge/Robusta-4A90E2?style=flat-square&logo=robot&logoColor=white)](https://robusta.dev/)
[![Slack](https://img.shields.io/badge/Slack-4A154B?style=flat-square&logo=slack&logoColor=white)](https://slack.com/)
[![GitOps](https://img.shields.io/badge/GitOps-FC6D26?style=flat-square&logo=git&logoColor=white)](https://www.gitops.tech/)

Robusta deployment for K3s cluster alert enrichment and automation, managed via ArgoCD.

## Directory Structure

```
robusta-k3s/
├── base/
│   ├── application.yaml        # ArgoCD Application
│   ├── values.yaml             # Base Helm values
│   ├── kustomization.yaml
│   └── secrets.yaml.example    # Secret template (DO NOT COMMIT REAL SECRETS)
├── playbooks/
│   └── k3s-playbooks.yaml      # Custom playbooks for K3s alerts
├── sinks/
│   └── sinks.yaml              # Notification sinks (Slack, PagerDuty, etc.)
├── overlays/
│   ├── dev/
│   │   ├── values.yaml         # Dev-specific overrides
│   │   └── kustomization.yaml
│   └── prod/
│       ├── values.yaml         # Prod-specific overrides
│       └── kustomization.yaml
├── kustomization.yaml
└── README.md
```

## Prerequisites

1. **VictoriaMetrics stack deployed** with Alertmanager configured to send to Robusta:
   ```yaml
   # In Alertmanager config
   receivers:
     - name: robusta
       webhook_configs:
         - url: 'http://robusta-runner.robusta.svc.cluster.local/api/alerts'
   ```

2. **Slack Bot Token** (or other sink credentials):
   - Create a Slack App: https://api.slack.com/apps
   - Add Bot Token Scopes: `chat:write`, `files:write`
   - Install to workspace and copy Bot Token (`xoxb-...`)

## Quick Start

### 1. Create Secrets

```bash
# Create the robusta namespace
kubectl create namespace robusta

# Create secret with your Slack token
kubectl create secret generic robusta-secrets \
  --namespace robusta \
  --from-literal=SLACK_API_KEY=xoxb-your-token

# Or for multiple sinks
kubectl create secret generic robusta-secrets \
  --namespace robusta \
  --from-literal=SLACK_API_KEY=xoxb-xxx \
  --from-literal=PAGERDUTY_API_KEY=xxx \
  --from-literal=OPSGENIE_API_KEY=xxx
```

### 2. Deploy with ArgoCD

```bash
# Single environment
argocd app create robusta \
  --repo https://github.com/YOUR_ORG/robusta-k3s.git \
  --path base \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace robusta

# Or for specific environment
argocd app create robusta-prod \
  --repo https://github.com/YOUR_ORG/robusta-k3s.git \
  --path overlays/prod \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace robusta
```

### 3. Verify Deployment

```bash
# Check pods
kubectl -n robusta get pods

# Check logs
kubectl -n robusta logs -l app=robusta-runner -f

# Test alert enrichment
kubectl -n robusta exec -it deploy/robusta-runner -- robusta test
```

## Configuration

### Sinks (sinks/sinks.yaml)

Configure where enriched alerts are sent:

```yaml
sinksConfig:
  - slack_sink:
      name: main_slack
      slack_channel: "#k3s-alerts"
      api_key: "{{ env.SLACK_API_KEY }}"
      
  - pagerduty_sink:
      name: pagerduty
      api_key: "{{ env.PAGERDUTY_API_KEY }}"
      match:
        - severity: ["critical"]
```

### Playbooks (playbooks/k3s-playbooks.yaml)

Playbooks define what enrichment actions to take for each alert:

```yaml
customPlaybooks:
  - triggers:
      - on_prometheus_alert:
          alert_name: PodCrashLooping
    actions:
      - logs_enricher: {}
      - pod_events_enricher: {}
```

### Environment Overrides

Use overlays for environment-specific configuration:

| Setting | Dev | Prod |
|---------|-----|------|
| Log Level | DEBUG | INFO |
| Memory Limit | 1Gi | 2Gi |
| Sinks | Slack only | Slack + PagerDuty |
| Playbooks | Basic | Full |

## Alert Flow

```
VictoriaMetrics VMAlert
        │
        ▼
    Alertmanager
        │
        ▼
  Robusta Runner ──────────────────────┐
        │                              │
        ▼                              ▼
┌───────────────┐              ┌──────────────┐
│   Playbook    │              │   Playbook   │
│ (logs, events)│              │ (graphs, pod)│
└───────────────┘              └──────────────┘
        │                              │
        └──────────┬───────────────────┘
                   ▼
           Enriched Alert
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
     Slack              PagerDuty
  #k3s-alerts          (critical only)
```

## Playbook Reference

### Available Actions

| Action | Description |
|--------|-------------|
| `logs_enricher` | Fetch container logs |
| `pod_events_enricher` | Fetch pod events |
| `pod_graph_enricher` | CPU/Memory graphs |
| `node_graph_enricher` | Node resource graphs |
| `pod_issue_investigator` | Analyze pod issues |
| `deployment_events_enricher` | Deployment events |
| `node_running_pods_enricher` | List pods on node |
| `node_disk_analyzer` | Disk usage analysis |
| `oom_killer_enricher` | OOM details |
| `delete_pod` | Auto-remediation (use with caution!) |

### Trigger Filters

```yaml
triggers:
  - on_prometheus_alert:
      alert_name: "PodCrashLooping"    # Exact match
      alert_name: "*"                   # All alerts
      severity: critical                # By severity
      status: firing                    # firing or resolved
      namespace: "production"           # By namespace
```

## Secrets Management

### Option 1: Kubernetes Secrets (Simple)

```bash
kubectl create secret generic robusta-secrets \
  --namespace robusta \
  --from-literal=SLACK_API_KEY=xoxb-xxx
```

### Option 2: Sealed Secrets (GitOps Safe)

```bash
# Install sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Seal your secret
kubeseal --format yaml < secret.yaml > sealed-secret.yaml

# Commit sealed-secret.yaml to git
```

### Option 3: External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: robusta-secrets
  namespace: robusta
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: robusta-secrets
  data:
    - secretKey: SLACK_API_KEY
      remoteRef:
        key: secret/robusta
        property: slack_api_key
```

## Troubleshooting

### Robusta not receiving alerts

```bash
# Check Alertmanager is sending to Robusta
kubectl -n victoria-metrics logs -l app=alertmanager | grep robusta

# Check Robusta webhook endpoint
kubectl -n robusta port-forward svc/robusta-runner 5000:5000
curl -X POST localhost:5000/api/alerts -d '{"alerts":[{"status":"firing"}]}'
```

### Playbooks not running

```bash
# Check Robusta logs
kubectl -n robusta logs -l app=robusta-runner -f

# Verify playbooks are loaded
kubectl -n robusta exec deploy/robusta-runner -- cat /etc/robusta/config.yaml
```

### Slack messages not arriving

1. Verify bot token has correct scopes
2. Check bot is invited to channel
3. Verify channel name (with or without #)
4. Check Robusta logs for errors

## Upgrading

```bash
# Update chart version in base/application.yaml
# Then sync with ArgoCD
argocd app sync robusta

# Or force upgrade
argocd app sync robusta --force
```

## References

- [Robusta Documentation](https://docs.robusta.dev/)
- [Robusta Helm Chart](https://github.com/robusta-dev/robusta/tree/master/helm)
- [Playbook Reference](https://docs.robusta.dev/master/playbook-reference/index.html)
- [Sink Configuration](https://docs.robusta.dev/master/configuration/sinks/index.html)

# Robusta Playbooks

Alert enrichment playbooks for K3s cluster monitoring with VictoriaMetrics.

## Structure

Playbooks are split into separate files by category for easier maintenance:

### Pod Alerts
- **pod-crash-restarts.yaml** - Pod crash loops and container restarts
- **pod-oom-memory.yaml** - OOM kills and memory pressure
- **pod-cpu.yaml** - CPU usage and throttling
- **pod-scheduling.yaml** - Scheduling failures and image pull issues

### Node Alerts
- **node-cpu-memory.yaml** - Node CPU and memory alerts
- **node-disk-health.yaml** - Node disk usage and health

### Workload Alerts
- **deployment-workloads.yaml** - Deployments and StatefulSets
- **jobs-storage.yaml** - Jobs, CronJobs, and PVC alerts
- **k3s-components.yaml** - K3s control plane (API server, CoreDNS)

### Bash Enrichment
- **bash-node-enrichment.yaml** - Node diagnostics (disk, memory, CPU, health)
- **bash-pod-enrichment.yaml** - Pod diagnostics (resource usage, events)
- **bash-workload-enrichment.yaml** - Deployment, PVC, and network diagnostics

## Usage

### Option 1: Load All Playbooks (Recommended)

Reference the entire playbooks directory in your Robusta values:

```yaml
# In base/values.yaml or overlays
customPlaybooks:
  # Will load all playbook files
```

Then use Helm's file loading or reference via kustomization.

### Option 2: Selective Loading

Load only specific playbook categories in your environment overlays:

```yaml
# overlays/dev/values.yaml
customPlaybooks:
  # Include only basic playbooks for dev
```

### Option 3: Kustomize ConfigMap

Use the included `kustomization.yaml` to merge all playbooks into a ConfigMap:

```bash
kustomize build playbooks/
```

## Playbook Actions

### Built-in Actions
- `logs_enricher` - Fetch container logs
- `pod_events_enricher` - Get pod events
- `pod_graph_enricher` - Generate CPU/Memory graphs
- `node_graph_enricher` - Node resource graphs
- `pod_issue_investigator` - Analyze pod issues
- `deployment_events_enricher` - Deployment history
- `oom_killer_enricher` - OOM kill details

### Bash Enricher
Custom bash scripts for deep diagnostics:
- System-level analysis (ps, top, df, free)
- kubectl commands for cluster state
- Log analysis and event correlation
- Network diagnostics (ip, ss, nslookup)

## Environment Variables

Bash enrichers use these environment variables:
- `${POD_NAME}` - Alert pod name
- `${NAMESPACE}` - Alert namespace
- `${NODE_NAME}` - Alert node name
- `${DEPLOYMENT}` - Deployment name
- `${PVC_NAME}` - PVC name

## Customization

### Adding New Playbooks

1. Create a new YAML file in this directory
2. Follow the naming convention: `<category>-<subcategory>.yaml`
3. Add to `kustomization.yaml` if using kustomize
4. Structure:

```yaml
customPlaybooks:
  - triggers:
      - on_prometheus_alert:
          alert_name: YourAlert
    actions:
      - your_enricher: {}
```

### Modifying Bash Scripts

Edit the `bash_command` field in bash enrichment files:

```yaml
- bash_enricher:
    bash_command: |
      #!/bin/bash
      # Your custom diagnostic commands
      echo "Custom analysis"
```

## Testing

Test individual playbooks:

```bash
# Validate YAML syntax
yamllint pod-crash-restarts.yaml

# Test with Robusta
kubectl apply -f pod-crash-restarts.yaml
```

## References

- [Robusta Playbook Reference](https://docs.robusta.dev/master/playbook-reference/index.html)
- [Bash Enricher Docs](https://docs.robusta.dev/master/playbook-reference/actions/bash-enricher.html)
- [Alert Triggers](https://docs.robusta.dev/master/playbook-reference/triggers/index.html)

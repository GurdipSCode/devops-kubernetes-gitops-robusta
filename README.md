# devops-kubernetes-gitops-robusta

<p align="center">
  <img src="https://img.shields.io/badge/GitOps-ArgoCD-orange?logo=argo" />
  <img src="https://img.shields.io/badge/Observability-Robusta-blue" />
  <img src="https://img.shields.io/badge/Kubernetes-k3s-ffc61c?logo=kubernetes" />
  <img src="https://img.shields.io/badge/Networking-Cilium-blue?logo=cilium" />
  <img src="https://img.shields.io/badge/Policy-Kyverno-success?logo=kyverno" />
  <img src="https://img.shields.io/badge/Secrets-Vault-black?logo=vault" />
  <img src="https://img.shields.io/badge/Metrics-Prometheus-e6522c?logo=prometheus" />
  <img src="https://img.shields.io/badge/Dashboards-Grafana-f46800?logo=grafana" />
  <img src="https://img.shields.io/badge/Scaling-KEDA-5b2dd8" />
</p>

> **Production-grade GitOps deployment of Robusta using Argo CD**  
> Designed for platform, SRE, and DevOps teams running secure Kubernetes at scale.

---

## 📁 Repository Structure

```text
robusta-gitops/
├── README.md
├── argocd/
│   ├── projects/
│   │   └── observability.yaml
│   └── applications/
│       └── robusta.yaml
├── environments/
│   ├── dev/
│   │   └── robusta-values.yaml
│   ├── staging/
│   │   └── robusta-values.yaml
│   └── prod/
│       └── robusta-values.yaml
├── helm/
│   └── robusta/
│       └── values.yaml
└── policies/
    └── kyverno/
        └── robusta-hardening.yaml

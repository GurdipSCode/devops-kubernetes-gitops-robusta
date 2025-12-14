# devops-kubernetes-gitops-robusta - Robusta GitOps Observability Platform

<p align="center">
  <img src="https://img.shields.io/badge/GitOps-ArgoCD-orange?logo=argo&style=flat-square" />
  <img src="https://img.shields.io/badge/Kubernetes-k3s-ffc61c?logo=kubernetes&style=flat-square" />
  <img src="https://img.shields.io/badge/Observability-Robusta-blue?style=flat-square" />
  <img src="https://img.shields.io/badge/Networking-Cilium-blue?logo=cilium&style=flat-square" />
  <img src="https://img.shields.io/badge/Policy-Kyverno-success?logo=kyverno&style=flat-square" />
  <img src="https://img.shields.io/badge/Secrets-Vault-black?logo=vault&style=flat-square" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Metrics-Prometheus-e6522c?logo=prometheus&style=flat-square" />
  <img src="https://img.shields.io/badge/Dashboards-Grafana-f46800?logo=grafana&style=flat-square" />
  <img src="https://img.shields.io/badge/Autoscaling-KEDA-5b2dd8?style=flat-square" />
  <img src="https://img.shields.io/badge/Runtime--Security-Policy--Driven-informational?style=flat-square" />
</p>

---

## 🏦 Purpose

This repository defines a **production-grade, regulated-environment GitOps deployment**
for **Robusta** using **Argo CD**.

Designed for:

- Banks & financial institutions  
- Regulated enterprises  
- Platform & SRE teams  
- Security-first Kubernetes environments

Focus: **control, auditability, and blast-radius reduction**.

---

## 📁 Repository Structure

```text
robusta-gitops/
├── README.md
├── argocd/
│   ├── root-app.yaml
│   ├── projects/observability.yaml
│   └── applications/
│       ├── robusta.yaml
│       ├── robusta-secrets.yaml
│       └── robusta-policies.yaml
├── bootstrap/namespace.yaml
├── helm/robusta/
│   ├── values.yaml
│   └── values-prod.yaml
├── secrets/externalsecret.yaml
├── policies/kyverno/robusta-hardening.yaml
└── environments/prod/kustomization.yaml

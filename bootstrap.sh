#!/bin/bash
# =============================================================================
# k3s Monitoring Stack - ArgoCD Bootstrap Script
# =============================================================================
# This script bootstraps the monitoring stack in your k3s cluster using ArgoCD
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
ARGOCD_NAMESPACE="argocd"
MONITORING_NAMESPACE="robusta"

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Install ArgoCD if not present
install_argocd() {
    if kubectl get namespace ${ARGOCD_NAMESPACE} &> /dev/null; then
        log_info "ArgoCD namespace exists, checking installation..."
        if kubectl get deployment argocd-server -n ${ARGOCD_NAMESPACE} &> /dev/null; then
            log_success "ArgoCD is already installed"
            return
        fi
    fi
    
    log_info "Installing ArgoCD..."
    
    kubectl create namespace ${ARGOCD_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -n ${ARGOCD_NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    log_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available deployment/argocd-server -n ${ARGOCD_NAMESPACE} --timeout=300s
    
    log_success "ArgoCD installed"
    
    # Get initial admin password
    ARGOCD_PASSWORD=$(kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo ""
    log_info "ArgoCD admin password: ${ARGOCD_PASSWORD}"
    echo ""
}

# Install ArgoCD CLI if not present
install_argocd_cli() {
    if command -v argocd &> /dev/null; then
        log_success "ArgoCD CLI is already installed"
        return
    fi
    
    log_info "Installing ArgoCD CLI..."
    
    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        ARCH="arm64"
    fi
    
    VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    curl -sSL -o /tmp/argocd "https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-${OS}-${ARCH}"
    chmod +x /tmp/argocd
    sudo mv /tmp/argocd /usr/local/bin/argocd
    
    log_success "ArgoCD CLI installed"
}

# Configure repository
configure_repo() {
    log_info "Configuring Git repository..."
    
    echo ""
    read -p "Enter your Git repository URL: " REPO_URL
    
    if [ -z "$REPO_URL" ]; then
        log_error "Repository URL is required"
        exit 1
    fi
    
    # Update all YAML files with the repository URL
    find . -type f -name "*.yaml" -exec sed -i "s|https://github.com/YOUR_ORG/k3s-monitoring.git|${REPO_URL}|g" {} \;
    
    log_success "Repository URL updated"
}

# Configure VictoriaMetrics IP
configure_victoriametrics() {
    log_info "Configuring VictoriaMetrics..."
    
    echo ""
    read -p "Enter your Windows VictoriaMetrics IP address: " VM_IP
    
    if [ -z "$VM_IP" ]; then
        log_warn "No VictoriaMetrics IP provided, using placeholder"
        return
    fi
    
    # Update all YAML files with the VictoriaMetrics IP
    find . -type f -name "*.yaml" -exec sed -i "s|192.168.1.100|${VM_IP}|g" {} \;
    
    log_success "VictoriaMetrics IP updated"
}

# Create secrets
create_secrets() {
    log_info "Setting up secrets..."
    
    echo ""
    echo "Choose secret management approach:"
    echo "1) External Secrets Operator (recommended for production)"
    echo "2) Manual secrets (for development/testing)"
    echo "3) Skip (configure later)"
    read -p "Enter choice [1-3]: " SECRET_CHOICE
    
    case $SECRET_CHOICE in
        1)
            log_info "Please configure External Secrets in overlays/prod/secrets/external-secrets.yaml"
            log_info "Then run: kubectl apply -f overlays/prod/secrets/external-secrets.yaml"
            ;;
        2)
            log_info "Creating manual secrets..."
            
            kubectl create namespace ${MONITORING_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
            
            echo ""
            read -p "Robusta signing key: " SIGNING_KEY
            read -p "Robusta account ID: " ACCOUNT_ID
            read -p "Robusta token: " ROBUSTA_TOKEN
            read -p "Slack API key (or press Enter to skip): " SLACK_KEY
            read -p "Grafana admin password: " GRAFANA_PASS
            
            kubectl create secret generic robusta-credentials \
                -n ${MONITORING_NAMESPACE} \
                --from-literal=signing_key="${SIGNING_KEY}" \
                --from-literal=account_id="${ACCOUNT_ID}" \
                --from-literal=robusta_token="${ROBUSTA_TOKEN}" \
                --from-literal=slack_api_key="${SLACK_KEY:-placeholder}" \
                --from-literal=grafana_admin_password="${GRAFANA_PASS}" \
                --dry-run=client -o yaml | kubectl apply -f -
            
            log_success "Secrets created"
            ;;
        3)
            log_warn "Skipping secrets configuration"
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Deploy monitoring stack
deploy_monitoring() {
    log_info "Deploying monitoring stack via ArgoCD..."
    
    # Create ArgoCD project
    kubectl apply -f apps/project.yaml
    
    # Create root application
    kubectl apply -f apps/root-app.yaml
    
    log_info "Waiting for applications to sync..."
    sleep 10
    
    # Check sync status
    kubectl get applications -n ${ARGOCD_NAMESPACE}
    
    log_success "Monitoring stack deployment initiated"
}

# Print access information
print_access_info() {
    echo ""
    echo "=============================================="
    log_success "Bootstrap Complete!"
    echo "=============================================="
    echo ""
    echo "ArgoCD UI:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  Then open: https://localhost:8080"
    echo "  Username: admin"
    ARGOCD_PASSWORD=$(kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "Run: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d")
    echo "  Password: ${ARGOCD_PASSWORD}"
    echo ""
    echo "Grafana (after sync completes):"
    echo "  kubectl port-forward svc/robusta-grafana -n robusta 3000:80"
    echo "  Then open: http://localhost:3000"
    echo ""
    echo "Check application status:"
    echo "  argocd app list"
    echo "  kubectl get applications -n argocd"
    echo ""
    echo "Next steps:"
    echo "1. Verify ArgoCD applications are syncing"
    echo "2. Run windows-setup.ps1 on your Windows machine"
    echo "3. Test alert notifications"
    echo ""
}

# Main
main() {
    echo "=============================================="
    echo "k3s Monitoring Stack - ArgoCD Bootstrap"
    echo "=============================================="
    echo ""
    
    check_prerequisites
    install_argocd
    install_argocd_cli
    
    echo ""
    read -p "Configure repository and settings now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        configure_repo
        configure_victoriametrics
        create_secrets
    fi
    
    echo ""
    read -p "Deploy monitoring stack now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_monitoring
    fi
    
    print_access_info
}

# Run
main "$@"

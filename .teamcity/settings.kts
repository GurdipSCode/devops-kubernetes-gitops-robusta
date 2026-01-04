import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildSteps.script
import jetbrains.buildServer.configs.kotlin.triggers.vcs

version = "2024.03"

project {
    description = "Robusta K3s GitOps Pipeline"

    buildType(KubernetesValidation)
}

object KubernetesValidation : BuildType({
    name = "Kubernetes Manifest Validation"
    description = "Lint Kubernetes manifests, scan for secrets, and generate changelog"

    vcs {
        root(DslContext.settingsRoot)
        cleanCheckout = true
    }

    steps {
        // Step 1: Kubernetes manifest linting
        script {
            name = "Lint Kubernetes Manifests"
            scriptContent = """
                #!/bin/bash
                set -e

                echo "=== Installing tools ==="
                # Install kubeval if missing
                if ! command -v kubeval &> /dev/null; then
                    echo "Installing kubeval..."
                    wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz
                    tar xf kubeval-linux-amd64.tar.gz
                    sudo mv kubeval /usr/local/bin
                else
                    echo "kubeval already installed"
                fi

                # Install kubeconform if missing
                if ! command -v kubeconform &> /dev/null; then
                    echo "Installing kubeconform..."
                    wget https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz
                    tar xf kubeconform-linux-amd64.tar.gz
                    sudo mv kubeconform /usr/local/bin
                else
                    echo "kubeconform already installed"
                fi

                # Install kustomize if missing
                if ! command -v kustomize &> /dev/null; then
                    echo "Installing kustomize..."
                    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
                    sudo mv kustomize /usr/local/bin/
                else
                    echo "kustomize already installed"
                fi

                echo "=== Validating base manifests ==="
                find base -name "*.yaml" -o -name "*.yml" | while read file; do
                    echo "Validating: ${'$'}file"
                    kubeconform -strict -ignore-missing-schemas "${'$'}file"
                done

                echo "=== Validating overlay manifests ==="
                find overlays -name "*.yaml" -o -name "*.yml" | while read file; do
                    echo "Validating: ${'$'}file"
                    kubeconform -strict -ignore-missing-schemas "${'$'}file"
                done

                echo "=== Building kustomize overlays ==="
                for overlay in overlays/*/; do
                    echo "Building ${'$'}overlay"
                    kustomize build "${'$'}overlay" | kubeconform -strict -ignore-missing-schemas -
                done

                echo "✓ All manifests are valid"
            """.trimIndent()
        }

        // Step 2: YAML linting
        script {
            name = "YAML Lint"
            scriptContent = """
                #!/bin/bash
                set -e

                echo "=== Installing yamllint ==="
                if ! command -v yamllint &> /dev/null; then
                    echo "Installing yamllint..."
                    pip install yamllint
                else
                    echo "yamllint already installed"
                fi

                echo "=== Running yamllint ==="
                yamllint -d "{extends: default, rules: {line-length: {max: 120}, document-start: disable}}" .

                echo "✓ YAML files are properly formatted"
            """.trimIndent()
        }

        // Step 3: GitGuardian secret scanning
        script {
            name = "GitGuardian Secret Scan"
            scriptContent = """
                #!/bin/bash
                set -e

                echo "=== Installing GitGuardian CLI ==="
                if ! command -v ggshield &> /dev/null; then
                    echo "Installing ggshield..."
                    pip install ggshield
                else
                    echo "ggshield already installed"
                fi

                echo "=== Scanning for secrets ==="
                # Scan all files in the repository
                ggshield secret scan path . --recursive --exit-zero

                # Scan git history (only recent commits to avoid long scans)
                ggshield secret scan commit-range HEAD~10..HEAD --exit-zero

                echo "✓ GitGuardian scan complete"
            """.trimIndent()
        }

        // Step 4: Generate changelog with git-cliff
        script {
            name = "Generate Changelog"
            scriptContent = """
                #!/bin/bash
                set -e

                echo "=== Installing git-cliff ==="
                if ! command -v git-cliff &> /dev/null; then
                    echo "Installing git-cliff..."
                    wget https://github.com/orhun/git-cliff/releases/latest/download/git-cliff-0.15.0-x86_64-unknown-linux-gnu.tar.gz
                    tar -xzf git-cliff-0.15.0-x86_64-unknown-linux-gnu.tar.gz
                    sudo mv git-cliff-0.15.0/git-cliff /usr/local/bin/
                else
                    echo "git-cliff already installed"
                fi

                echo "=== Generating changelog ==="
                git-cliff --config cliff.toml --output CHANGELOG.md

                echo "=== Changelog preview ==="
                head -n 50 CHANGELOG.md

                echo "✓ Changelog generated"
            """.trimIndent()
        }

        // Step 5: ArgoCD validation (optional)
        script {
            name = "ArgoCD Manifest Validation"
            scriptContent = """
                #!/bin/bash
                set -e

                echo "=== Validating ArgoCD Applications ==="
                find apps -name "*.yaml" -o -name "*.yml" | while read file; do
                    echo "Validating ArgoCD app: ${'$'}file"
                    # Check for required fields
                    if ! grep -q "kind: Application" "${'$'}file"; then
                        echo "Warning: ${'$'}file might not be an ArgoCD Application"
                    fi
                done

                echo "✓ ArgoCD applications validated"
            """.trimIndent()
        }
    }

    triggers {
        vcs {
            branchFilter = """
                +:*
            """.trimIndent()
            triggerRules = "-:comment=^\\[ci skip\\].*"
        }
    }

    features {
        // Pull request decoration
        feature {
            type = "pullRequests"
            param("authenticationType", "token")
            param("filterAuthorRole", "EVERYBODY")
        }
    }

    requirements {
        exists("docker.server.version")
    }

    params {
        param("env.GITGUARDIAN_API_KEY", "%gitguardian.api.key%")
    }
})

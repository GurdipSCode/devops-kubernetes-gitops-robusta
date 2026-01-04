# TeamCity Pipeline Configuration

This directory contains TeamCity Kotlin DSL configuration for validating Kubernetes manifests, scanning for secrets, and generating changelogs.

## Pipeline Steps

### 1. Kubernetes Manifest Linting
- **Tools**: `kubeconform`, `kubeval`, `kustomize`
- **Actions**:
  - Validates all YAML manifests in `base/` and `overlays/`
  - Builds and validates kustomize overlays
  - Ensures manifests conform to Kubernetes schema

### 2. YAML Linting
- **Tool**: `yamllint`
- **Actions**:
  - Validates YAML syntax and formatting
  - Checks line length, indentation, and structure

### 3. GitGuardian Secret Scanning
- **Tool**: `ggshield`
- **Actions**:
  - Scans all files for hardcoded secrets
  - Checks recent git history for leaked credentials
  - Detects API keys, tokens, passwords, etc.

### 4. Changelog Generation
- **Tool**: `git-cliff`
- **Actions**:
  - Generates changelog from conventional commits
  - Uses configuration from `cliff.toml`
  - Creates/updates `CHANGELOG.md`

### 5. ArgoCD Application Validation
- **Actions**:
  - Validates ArgoCD Application manifests
  - Checks for required fields

## Setup

### Prerequisites

1. **TeamCity Server**: Version 2024.03+
2. **GitGuardian API Key**: Required for secret scanning

### Configuration

1. **Add GitGuardian API Key**:
   ```
   TeamCity → Project Settings → Parameters
   Name: gitguardian.api.key
   Type: Environment variable (password)
   Value: <your-gitguardian-api-key>
   ```

2. **VCS Root**:
   - Point to your Git repository
   - Ensure default branch is configured

3. **Agent Requirements**:
   - Docker must be available on build agents
   - Internet access for downloading tools

## Triggers

- **VCS Trigger**: Runs on all branch commits
- **Skip CI**: Add `[ci skip]` to commit message to skip pipeline

## Local Testing

You can test the pipeline steps locally:

```bash
# Test Kubernetes validation
kubeconform -strict base/*.yaml

# Test YAML linting
yamllint .

# Test GitGuardian (requires API key)
export GITGUARDIAN_API_KEY=your-key
ggshield secret scan path . --recursive

# Test changelog generation
git-cliff --config cliff.toml --output CHANGELOG.md
```

## Kotlin DSL

The pipeline is defined using TeamCity Kotlin DSL:
- `settings.kts`: Main pipeline configuration
- `pom.xml`: Maven dependencies for Kotlin DSL

### Updating Configuration

1. Edit `settings.kts`
2. Commit changes
3. TeamCity will automatically detect and apply changes

### Versioning

To version your DSL configuration:
```bash
cd .teamcity
mvn teamcity-configs:generate
```

## Pipeline Features

- ✅ Automatic trigger on all branches
- ✅ Pull request decoration
- ✅ Secret scanning with GitGuardian
- ✅ Kubernetes manifest validation
- ✅ YAML linting
- ✅ Automated changelog generation
- ✅ ArgoCD application validation

## Troubleshooting

### Tools not found
Ensure build agents have internet access to download:
- kubeconform from GitHub releases
- yamllint from PyPI
- ggshield from PyPI
- git-cliff from GitHub releases

### GitGuardian failures
- Verify API key is set correctly
- Check API rate limits
- Use `--exit-zero` flag for non-blocking scans

### Kustomize build failures
- Ensure overlays have valid `kustomization.yaml`
- Check that base resources exist
- Verify paths in kustomization files

## References

- [TeamCity Kotlin DSL](https://www.jetbrains.com/help/teamcity/kotlin-dsl.html)
- [Kubeconform](https://github.com/yannh/kubeconform)
- [GitGuardian CLI](https://docs.gitguardian.com/ggshield-docs/getting-started)
- [git-cliff](https://git-cliff.org/)

# Contributing to Couchbase Performance

Thank you for your interest in contributing to this project!

## Getting Started

1. Fork the repository
2. Clone your fork
3. Create a feature branch
4. Make your changes
5. Test your changes
6. Submit a pull request

## Development Workflow

### Prerequisites

- OpenShift 4.12+ cluster for testing
- `kubectl` CLI configured (or `oc` on OpenShift)
- ArgoCD installed
- Basic knowledge of Kubernetes/OpenShift

### Setting Up Development Environment

```bash
# Clone the repository
git clone https://github.com/your-org/couchbase-performance.git
cd couchbase-performance

# Create a feature branch
git checkout -b feature/my-feature

# Deploy to test environment
make deploy NAMESPACE=couchbase-dev
```

### Making Changes

#### ArgoCD Manifests

When modifying ArgoCD manifests:

1. Update the relevant YAML files in `argocd/manifests/`
2. Test deployment in a dev environment
3. Verify with `make verify`
4. Document changes in commit message

#### Couchbase Configuration

When changing Couchbase configuration:

1. Update `argocd/manifests/cluster/cluster.yaml` or related files
2. Consider backward compatibility
3. Update documentation in `CONFIGURATION.md`
4. Test with different cluster sizes

#### Monitoring Changes

When modifying monitoring:

1. Update ServiceMonitor or PodMonitor definitions
2. Test metrics collection
3. Update Prometheus queries in `PROMETHEUS_QUERIES.md`
4. Verify alerts trigger correctly

### Testing

#### Local Testing

```bash
# Deploy your changes
make deploy

# Verify deployment
make verify

# Check status
make status

# View logs
make logs-cluster
```

#### Integration Testing

```bash
# Test connection
make test-connection

# Run load test
make load-test

# Check metrics
make metrics
```

### Code Style

#### YAML Files

- Use 2 spaces for indentation
- Include comments for complex configurations
- Follow Kubernetes resource naming conventions
- Use labels consistently

Example:
```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
  namespace: couchbase
  labels:
    app.kubernetes.io/name: couchbase
    app.kubernetes.io/component: config
data:
  key: value
```

#### Shell Scripts

- Use `#!/bin/bash` shebang
- Include `set -e` for error handling
- Add comments for complex logic
- Use meaningful variable names
- Quote variables properly

Example:
```bash
#!/bin/bash
set -e

NAMESPACE=${1:-"couchbase"}

echo "Processing namespace: ${NAMESPACE}"
# Rest of script
```

#### Documentation

- Use Markdown format
- Include code examples
- Keep line length under 120 characters
- Use proper headings hierarchy

### Commit Messages

Follow conventional commits format:

```
type(scope): subject

body

footer
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test changes
- `chore`: Build/tooling changes

Examples:
```
feat(monitoring): add custom Grafana dashboard

Add a new Grafana dashboard for Couchbase performance metrics
including operations per second and memory usage visualizations.

Closes #123
```

```
fix(cluster): correct memory quota calculation

The memory quota was incorrectly calculated for clusters with
multiple service types. This fix ensures proper quota allocation.

Fixes #456
```

### Pull Request Process

1. **Update Documentation**: Ensure all changes are documented
2. **Test Thoroughly**: Test in a development environment
3. **Update CHANGELOG**: Add entry describing changes
4. **Create PR**: Use the PR template
5. **Address Reviews**: Respond to review comments
6. **Squash Commits**: Squash commits before merge if requested

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
Describe testing performed

## Checklist
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] Tested in dev environment
- [ ] CHANGELOG updated
```

## Project Structure

```
couchbase-performance/
├── argocd/              # ArgoCD manifests
│   ├── applications/    # ArgoCD Application definitions
│   ├── manifests/       # Kubernetes resources
│   │   ├── operator/    # Operator resources
│   │   ├── cluster/     # Cluster resources
│   │   └── monitoring/  # Monitoring resources
│   └── *.sh            # Utility scripts
├── performance/         # Performance testing tools
└── docs/               # Additional documentation
```

## Areas for Contribution

### High Priority

- [ ] Automated backup testing
- [ ] Performance benchmarking automation
- [ ] Multi-cluster XDCR configuration
- [ ] Helm chart conversion
- [ ] CI/CD pipeline examples

### Medium Priority

- [ ] Additional Grafana dashboards
- [ ] More Prometheus alert rules
- [ ] Disaster recovery procedures
- [ ] Capacity planning tools
- [ ] Cost optimization guides

### Low Priority

- [ ] Additional example applications
- [ ] Video tutorials
- [ ] Blog posts
- [ ] Community templates

## Getting Help

- Open an issue for questions
- Join discussions in the Issues section
- Contact maintainers: [email@example.com]

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Accept constructive criticism
- Focus on what's best for the community
- Show empathy towards others

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or insulting comments
- Publishing private information
- Other unprofessional conduct

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project documentation

Thank you for contributing! 🎉

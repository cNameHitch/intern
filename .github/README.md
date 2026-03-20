# GitHub Actions CI/CD

This directory contains the GitHub Actions workflows and documentation for Loop Commander's continuous integration and release pipeline.

## Quick Links

- **Active Workflows**: [.github/workflows/](./workflows/)
- **Full Documentation**: [WORKFLOWS.md](./WORKFLOWS.md)
- **Quick Reference**: [CI_QUICK_REFERENCE.md](./CI_QUICK_REFERENCE.md)

## Workflows at a Glance

### CI Pipeline ([ci.yml](./workflows/ci.yml))

Runs on every push to `main` and every pull request.

```
Test --┐
Lint --+--> CI Pass
Swift -┘
```

- Tests, linting, and Swift build run in parallel
- All must pass for CI to succeed
- Lead time: 3-5 minutes typical

**Trigger**: `push main` or `pull_request main`

### Release Pipeline ([release.yml](./workflows/release.yml))

Runs when a version tag is pushed (e.g., `git tag v0.1.0 && git push origin v0.1.0`).

```
Pre-Test --> Build --> Release --> Verify
```

- Tests before building (gate)
- Builds both Rust binaries and Swift app
- Generates checksums
- Creates GitHub Release
- Lead time: 8-12 minutes typical

**Trigger**: `push v*` (version tags)

## Key Features

- **Parallel CI**: Test, lint, and Swift build run simultaneously
- **Quality Gates**: Strict formatting, clippy warnings are errors
- **Multi-Artifact Release**: Both Rust binaries (tarball) and .app bundle (zip)
- **Checksums**: SHA256 verification provided
- **Smart Caching**: Cargo registry, index, build, and Swift artifacts cached
- **Apple Silicon**: Optimized for `aarch64-apple-darwin` (macos-14 runner)
- **Auto-Release Notes**: Changelog auto-generated from commits
- **Pre-Release Tests**: Full test suite runs before building release

## Getting Started

### For Developers

1. **Before pushing code**:
   ```bash
   cargo test --workspace
   cargo fmt --all -- --check
   cargo clippy --workspace --all-targets -- -D warnings
   cd macos-app && swift build && cd ..
   ```

2. **Create a PR**: Push to a branch and open a pull request to `main`
3. **CI runs automatically**: Watch progress in GitHub Actions tab
4. **Fix any failures**: Address test, lint, or build failures locally, then push

See [CI_QUICK_REFERENCE.md](./CI_QUICK_REFERENCE.md) for debugging tips.

### For Release Engineers

1. **Ensure tests pass**:
   ```bash
   git checkout main
   git pull origin main
   cargo test --workspace
   ```

2. **Create and push version tag**:
   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```

3. **Monitor GitHub Actions**: Watch release workflow run
4. **Verify GitHub Release**: Download artifacts and test locally
5. **Distribute**: Share release link with users

See [WORKFLOWS.md](./WORKFLOWS.md) for complete details.

## Artifact Locations

### After CI Runs
- **Build artifacts**: Cached in GitHub Actions (3-week retention)
- **No artifacts published**: CI is local to the workflow

### After Release Tag
- **Temporary**: Available in GitHub Actions Artifacts tab (7 days)
- **Permanent**: Published to GitHub Releases page
  - `loop-commander-{VERSION}-darwin-arm64.tar.gz` (Rust binaries)
  - `LoopCommander-{VERSION}.zip` (macOS app)
  - `CHECKSUMS.txt` (SHA256 verification)

## Documentation

### WORKFLOWS.md
Complete reference for both CI and release pipelines, including:
- Job descriptions and dependencies
- Caching strategies
- Version format requirements
- Installation methods
- Troubleshooting guide
- Future enhancement roadmap

### CI_QUICK_REFERENCE.md
Developer-focused quick reference:
- Pre-push checklist
- Release creation walkthrough
- Local debugging guide
- Common issues and fixes
- Performance optimization tips
- Release checklist

## Version Format

Tags must follow semantic versioning with `v` prefix:
- Valid: `v0.1.0`, `v1.0.0`, `v2.3.4`, `v1.0.0-alpha`
- Invalid: `v0.1`, `release-1`, `1.0.0` (missing 'v')

The release pipeline validates format and fails on invalid tags.

## Performance

### CI Pipeline
- With cache: 3-5 minutes
- First run: 8-12 minutes (downloading dependencies)
- Bottleneck: Typically Rust compilation

### Release Pipeline
- Pre-release tests: 2-3 minutes
- Build artifacts: 4-5 minutes
- Create release: 1-2 minutes
- Total: 8-12 minutes typical

## Quality Standards

All code must meet these standards before release:

- **Tests**: All must pass (`cargo test --workspace`)
- **Formatting**: No violations (`cargo fmt --check`)
- **Linting**: No warnings (`cargo clippy -- -D warnings`)
- **Swift**: Must compile (`swift build`)
- **Pre-release**: Full test suite re-runs before building

These gates are enforced by the CI and release workflows.

## Troubleshooting

### CI fails
1. Check the GitHub Actions tab for specific job failure
2. Click on failed job to see detailed logs
3. Reproduce failure locally
4. Fix issue and push new commit

### Release fails
1. Check pre-release tests first (most common failure point)
2. If build fails, verify local release build works
3. If release creation fails, artifacts are still available in GitHub Actions

See [CI_QUICK_REFERENCE.md](./CI_QUICK_REFERENCE.md#common-issues) for solutions to common problems.

## GitHub Actions Configuration

### Required Permissions
- **CI**: Default permissions sufficient
- **Release**: `contents: write` (create GitHub releases)

### Secrets
Currently, no secrets are required. When adding code signing:
- Add `APPLE_DEVELOPER_ID_APPLICATION` secret
- Uncomment code signing step in release workflow

## Next Steps

1. Push workflows to repository
2. Monitor CI pipeline on first push to `main`
3. Test release process with version tag
4. Add status badge to main README.md:
   ```markdown
   ![CI](https://github.com/username/loop-commander/actions/workflows/ci.yml/badge.svg)
   ```
5. Consider adding branch protection rules in GitHub settings

## Further Reading

- [GitHub Actions Documentation](https://docs.github.com/actions)
- [Rust Testing](https://doc.rust-lang.org/book/ch11-00-testing.html)
- [Swift Building](https://www.swift.org/getting-started/)
- [Loop Commander Architecture](../CLAUDE.md)

## Support

For questions about the CI/CD pipelines:
1. Check [WORKFLOWS.md](./WORKFLOWS.md) for comprehensive documentation
2. Check [CI_QUICK_REFERENCE.md](./CI_QUICK_REFERENCE.md) for quick answers
3. Review GitHub Actions logs in the Actions tab
4. Consult GitHub Actions documentation

---

Last updated: 2026-03-19

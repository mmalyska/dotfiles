# T04a – CI evidence

Workflow: `.github/workflows/ai-tests.yml` (Linux only in PR-1; Windows/macOS arrive in PR-4).

- chezmoi v2.73.1 installed from the release tarball, sha256 verified.
- `actions/checkout` pinned to `3d3c42e5aac5ba805825da76410c181273ba90b1` (v7.0.1); enforced by `tests/ai/test_workflow_pins.sh`.
- `permissions: contents: read`.
- Renovate: no `renovate.json5` exists in this repo, and none was added here; the `# renovate:` annotation on `CHEZMOI_VERSION` and the `# vX` comments are ready for it. Enabling Renovate is a separate repository decision (open item for the PR description).

Negative run (local): `tests/ai/test_workflow_pins.sh` fails when an action is changed to `@v4` – verified (output: `unpinned: … actions/checkout@v4`, then `FAIL test_workflow_pins`); restored afterwards.

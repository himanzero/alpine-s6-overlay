# Maintenance Guide

This document explains how the automated build system for `alpine-s6-overlay` is configured and how to maintain it.

## 1. Secrets Configuration

To enable the automated builds and Docker Hub updates, the following secrets must be set in the GitHub repository (**Settings > Secrets and variables > Actions**):

- `DOCKERHUB_USERNAME`: Your Docker Hub username.
- `DOCKERHUB_TOKEN`: A Personal Access Token (PAT) from Docker Hub with read/write access.

## 2. Automation Workflows

### `check-updates.yml`
- **Schedule**: Every day at 00:00 UTC.
- **Logic**:
  - Checks the latest stable tag from Docker Hub for Alpine.
  - Checks the latest release from GitHub for s6-overlay.
  - If a new version is found, it updates `versions.json` and pushes the change.

### `build-docker.yml`
- **Trigger**: Pushes to `versions.json` or `Dockerfile`.
- **Logic**: Builds a multi-architecture image (AMD64, ARM64) and pushes it to Docker Hub with multiple tags.

### `update-dockerhub-desc.yml`
- **Trigger**: Pushes to `README.md`.
- **Logic**: Automatically updates the repository overview page on Docker Hub using the content of `README.md`.

## 3. Version Tracking

The `versions.json` file tracks the last successfully built versions. 
```json
{
  "alpine": "3.23.4",
  "s6_overlay": "3.2.2.0"
}
```
If you want to force a rebuild of a specific version, you can manually edit this file and push it.

## 4. Troubleshooting

- **Node.js Deprecation Warnings**: I have opted into Node.js 24 using `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true`. If warnings persist, check for newer versions of the actions (e.g., `checkout@v7`).
- **Build Failures**: Check the logs in the Actions tab. Most failures are due to network issues while pulling upstream files or missing secrets.

#!/usr/bin/env bash

set -euo pipefail

# GitHub environment variables (in GitHub Actions)
CICD_TOKEN="${CICD_TOKEN:-}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
RELEASE="${RELEASE:-}"

# Pass any string or export DEBUG to enable debug mode
# Debug mode disables git related functions
DEBUG="${1:-${DEBUG:-}}"

# Composite variables 
REPO_URL="https://github.com/$GITHUB_REPOSITORY.git"
GIT_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"
GIT_NAME="github-actions[bot]"
GIT_TAG="v$RELEASE"

# Source helper functions
source "$(dirname $0)/functions/git.sh"

WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"
# Configure git
git config --global user.email "$GIT_EMAIL"
git config --global user.name "$GIT_NAME"

# Clone
git clone "https://${CICD_TOKEN}@${REPO_URL#https://}" repo
cd repo
git_tag "$GIT_TAG"

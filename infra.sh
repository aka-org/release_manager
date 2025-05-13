#!/usr/bin/env bash

set -euo pipefail

# GitHub environment variables (in GitHub Actions)
CICD_TOKEN="${CICD_TOKEN:-}"
ENVIRONMENT="${ENVIRONMENT:-testing}"
RELEASE="${RELEASE:-0.0.1-testing}"
RELEASE_MANIFEST="${RELEASE_MANIFEST:-releases/release-manifest.testing.json}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
GITHUB_REF_NAME="${GITHUB_REF_NAME:-main}"
TAG_REF="${TAG_REF:-}"
ACTION="${ACTION:-PREPARE}"

# Pass any string or export DEBUG to enable debug mode
# Debug mode disables git related functions
DEBUG="${1:-${DEBUG:-}}"

# Composite variables 
REPO_URL="https://github.com/$GITHUB_REPOSITORY.git"
GIT_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"
GIT_NAME="github-actions[bot]"

# Source helper functions
source "$(dirname $0)/functions/git.sh"
source "$(dirname $0)/functions/release.sh"
source "$(dirname $0)/functions/tfvars.sh"

# Main Prep per case of ACTION
if [ -z $DEBUG ]; then
  WORK_DIR=$(mktemp -d)
  cd "$WORK_DIR"
  # Configure git
  git config --global user.email "$GIT_EMAIL"
  git config --global user.name "$GIT_NAME"

  # Clone
  git clone "https://${CICD_TOKEN}@${REPO_URL#https://}" repo
  cd repo

  case $ACTION in
    PREPARE)
      BRANCH_NAME="releases/prepare_release_$RELEASE" 
      GIT_TAG="v$RELEASE-pre"
      git checkout -b "$BRANCH_NAME" "origin/$GITHUB_REF_NAME"
      ;;
    ROLLOUT)
      BRANCH_NAME="releases/rollout_release_$RELEASE" 
      GIT_TAG="v$RELEASE"
      git checkout -b "$BRANCH_NAME" "origin/$GITHUB_REF_NAME"
      ;;
    ROLLBACK)
      echo "Not implemented"
      ;;
    *)
      echo "Unknown action $ACTION specified"	    
      exit 1
      ;;
  esac
else
  BRANCH_NAME="debug_branch" 
  WORK_DIR=$(pwd)
  GIT_TAG="debug_tag"
fi

# If action is PREPARE update the release manifest
if [ $ACTION == "PREPARE" ]; then
  update_release_manifest_version
  git_commit "releases: Update $ENVIRONMENT release manifest version" 
  update_release_manifest_images
  git_commit "releases: Update $ENVIRONMENT release manifest images" 
fi

# Read the suffic of tfvars files we need to read through
TFVARS_FILE=$(jq -r '.terraform.tfvars_file' "$RELEASE_MANIFEST")
# Loop through all directories matching ENV name under the root
find "$WORK_DIR" -type d -name "$ENVIRONMENT" | while read -r vars_dir; do
  echo "Updating directory: $vars_dir"

  # For every *.json file under each directory 
  find "$vars_dir" -type f -name "$TFVARS_FILE" | while read -r tfvars_json; do
    parent_dir=$(dirname "$tfvars_json")
    component=$(basename "$(dirname "$parent_dir")")
    variant=$(basename "$tfvars_json" | cut -d\. -f1)
    echo "Updating file: $tfvars_json"
    case $ACTION in
      PREPARE)
        # Update image versions of components and deployments
        update_variant_os_images
        git_commit "tf:$component:$ENVIRONMENT:$variant: Update os images"
        # Update image versions of components and deployments
        update_variant_release_version 
        git_commit "tf:$component:$ENVIRONMENT:$variant: Update release version"
        # Provision infra for new release
        provision_variant
        git_commit "tf:$component:$ENVIRONMENT:$variant: Enable provisioning"
        ;;
      ROLLOUT)
        # Promote component with matching release version to current active
        promote_variant
        git_commit "tf:$component:$ENVIRONMENT:$variant: Promote to current active"
        # Deprovisioning component with old release version
        deprovision_variant
        git_commit "tf:$component:$ENVIRONMENT:$variant: Disable provisioning"
        ;;
      ROLLBACK)
        echo "Not implemented"
        ;;
    esac
  done
done

if [ "$ACTION" != "ROLLBACK" ]; then
  # Update checksum in release manifest
  update_release_manifest_checksum
  git_commit "releases: Update $ENVIRONMENT release manifest checksum" 
  git_push $BRANCH_NAME
  git_open_pr "Release $GIT_TAG" "$BRANCH_NAME" 
  git_tag "$GIT_TAG"
fi

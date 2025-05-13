# Requires env GITHUB_REPOSITORY CICD_TOKEN
trigger_workflow() {
  local workflow="$1"
  local ref="${2:-main}"
  local cicd_token="$CICD_TOKEN"
  local github_repository="$GITHUB_REPOSITORY"

  if [ -z $DEBUG ]; then
    # Trigger the workflow
    curl -s -L --fail --output /dev/null \
    -X POST \
    "https://api.github.com/repos/$github_repository/actions/workflows/$workflow/dispatches" \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $cicd_token" \
      -d '{"ref":"$ref"}' # Specify the branch to trigger
  fi
  echo "✅ Trigger workflow $workflow in $github_repository with ref $ref"
}

git_open_pr() {
  local title="$1"
  local head="$2"
  local base="${3:-main}"
  local cicd_token="$CICD_TOKEN"
  local github_repository="$GITHUB_REPOSITORY"

  if [ -z $DEBUG ]; then
    # Create the PR
    curl -s -L --fail --output /dev/null \
    -X POST \
    "https://api.github.com/repos/$github_repository/pulls" \
      -H "Authorization: Bearer $cicd_token" \
      -H "Accept: application/vnd.github+json" \
      -d @- <<EOF | jq .
{
  "title": "$title",
  "head": "$head",
  "base": "$base"
}
EOF
  fi
  echo "✅ Opened PR "$title" from $head to $base"
}

git_tag() {
  local tag="$1"
  if [ -z $DEBUG ]; then
    git tag -a "$tag" -m "Release $tag"
    git push origin "$tag"
  fi
  echo "✅ Tagged release $tag"
}

git_commit() {
  local commit_message="$1"

  if [ -z $DEBUG ]; then
    if [[ -n $(git status --porcelain) ]]; then
      # Commit changes
      git add .
      git commit -m "$commit_message"
    fi
  else
    echo "✅ Added commit $commit_message"
  fi
}

git_push() {
  local branch="$1"
  if [ -z $DEBUG ]; then
    # Push commits
    if [[ $(git rev-list --count origin/HEAD..HEAD) -gt 0 ]]; then
      git push origin "$branch"
    fi
  fi
  echo "✅ Pushed changes to remote $branch."
}

# Requires global variables RELEASE_MANIFEST RELEASE
# and gcloud with auth configured

update_release_manifest_checksum() {
  local manifest="$RELEASE_MANIFEST"
  # Update release manifest
  jq --arg checksum "$(tar -cf - terraform/ | sha256sum | awk '{print $1}')" \
     --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
     '
       .checksum = $checksum |
       .timestamp = $timestamp
     ' "$manifest" > tmp.json && mv tmp.json "$manifest"
}

update_release_manifest_version() {
  local manifest="$RELEASE_MANIFEST"
  local release="$RELEASE"
  # Update release manifest version
  jq --arg version "$release" '
    .version = $version
  ' "$manifest" > tmp.json && mv tmp.json "$manifest"
}

update_release_manifest_images() {
  local manifest="$RELEASE_MANIFEST"
  local release="$RELEASE"
  local project="$(jq -r '.terraform.project' "$manifest")"
  # Load latest os images key-value pairs from gcloud
  mapfile -t images < <(
    gcloud compute images list \
      --project=$project \
      --filter="labels.created_by=packer" \
      --format="json" |
    jq -r '
      group_by(.family)
      | map(max_by(.creationTimestamp))
      | map({key: .family, value: .labels.version})
      | from_entries
      | to_entries[]
      | "\(.key)=\(.value)"'
  )

  # Update release manifest image versions
  jq -r '.terraform.components | to_entries[] | "\(.key)"' "$manifest" | while read -r component; do
    for kv in "${images[@]}"; do
      image_family="${kv%%=*}"
      image_version="${kv#*=}"
      # Update the value in the tfvars JSON file
      jq --arg key "$image_family" \
         --arg val "$image_version" \
         --arg component "$component" '
	if has("terraform.components[$component].images[$key]") then
          .terraform.components[$component].images[$key] = $val
	else
          .
	end
      ' "$manifest" > tmp.json && mv tmp.json "$manifest"
    done
  done
}

promote_variant() {
  local tfvars_json="$tfvars_json"
  local manifest="$RELEASE_MANIFEST"
  # Read the release version from the release manifest
  local version=$(jq -r '.version' "$manifest")
  # Ensure that component is active and provisioned 
  jq --arg release "$version" '
    if has("release") and (.release == $release) then
      (if has("is_active") then .is_active = true else . end)
      | (if has("provisioned") then .provisioned = true else . end)
    else
      .
    end
  ' "$tfvars_json" > tmp.json && mv tmp.json "$tfvars_json"
}

provision_variant() {
  local tfvars_json="$tfvars_json"
  local manifest="$RELEASE_MANIFEST"
  # Read the release version from the release manifest
  local version=$(jq -r '.version' "$manifest")
  # Update the value in the tfvars JSON file
  jq --arg release "$version" '
    if has("release") and (.release == $release) then
      (if has("provisioned") then .provisioned = true else . end)
    else
      .
    end
  ' "$tfvars_json" > tmp.json && mv tmp.json "$tfvars_json"
}

deprovision_variant() {
  local tfvars_json="$tfvars_json"
  local manifest="$RELEASE_MANIFEST"
  # Read the release version from the release manifest
  local version=$(jq -r '.version' "$manifest")
  # Update the value in the tfvars JSON file
  jq --arg release "$version" '
    if has("release") and (.release != $release) then
      (if has("is_active") then .is_active = false else . end)
      | (if has("provisioned") then .provisioned = false else . end)
    else
      .
    end
  ' "$tfvars_json" > tmp.json && mv tmp.json "$tfvars_json"
}

update_variant_os_images() {
  local tfvars_json="$tfvars_json"
  local component="$component"
  local manifest="$RELEASE_MANIFEST"
  # Read the images from the updated release manifest
  mapfile -t images < <(
    jq -r --arg c "$component" '
      if has("terraform.components[$c].images") then
        .terraform.components[$c].images | to_entries[] | "\(.key)=\(.value)"
      else
	.
      end ' $manifest
  )

  for kv in "${images[@]}"; do
    image_family="${kv%%=*}"
    image_version="${kv#*=}"
    # Update the value in the tfvars JSON file
    jq --arg key "$image_family" --arg val "$image_version" '
      if has("is_active") and .is_active == true then
        .
      else
        (if has("images") and (.images | has($key))
         then .images[$key] = $val else . end)
      end
    ' "$tfvars_json" > tmp.json && mv tmp.json "$tfvars_json"
  done
}

update_variant_release_version() {
  local tfvars_json="$tfvars_json"
  local manifest="$RELEASE_MANIFEST"
  # Read the release version from the release manifest
  local version=$(jq -r '.version' "$manifest")
  # Update the value in the tfvars JSON file
  jq --arg release "$version" '
    if has("is_active") and .is_active == true then
      .
    else
      .release = $release
    end
  ' "$tfvars_json" > tmp.json && mv tmp.json "$tfvars_json"
}

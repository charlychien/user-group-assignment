#!/bin/bash
set -euo pipefail

OUT_FILE="enterprise-applications-all-user-group-assignments.csv"
TMP_OUT_FILE="${OUT_FILE%.csv}.tmp.$$.$RANDOM.csv"

cleanup_tmp() {
  [ -f "$TMP_OUT_FILE" ] && rm -f "$TMP_OUT_FILE"
}

trap cleanup_tmp EXIT

echo "servicePrincipalId,enterpriseAppDisplayName,appId,assignmentId,principalType,principalId,principalDisplayName,appRoleId" > "$TMP_OUT_FILE"

csv_escape() {
  local s="$1"
  s="${s//$'\r'/}"
  s="${s//$'\n'/ }"
  s="${s//\"/\"\"}"
  printf '"%s"' "$s"
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

require_command az

script_start_ts=$(date +%s)

# Filter only Enterprise Applications shown in Entra Enterprise Applications blade.
# This excludes many background service principals and dramatically reduces runtime.
APP_TYPE_FILTER="servicePrincipalType eq 'Application' and tags/any(t:t eq 'WindowsAzureActiveDirectoryIntegratedApp')"
APP_LIST_QUERY="[].[id,displayName,appId]"

# List all enterprise applications in tenant.
mapfile -t app_rows < <(az ad sp list --all --filter "$APP_TYPE_FILTER" --query "$APP_LIST_QUERY" -o tsv | tr -d '\r')
total_apps="${#app_rows[@]}"
processed_apps=0

echo "Found $total_apps enterprise application(s) to process..." >&2

for i in "${!app_rows[@]}"; do
  IFS=$'\t' read -r sp_id sp_name app_id <<< "${app_rows[$i]}"
  sp_id="${sp_id//$'\r'/}"
  sp_name="${sp_name//$'\r'/}"
  app_id="${app_id//$'\r'/}"

  [ -z "$sp_id" ] && continue

  processed_apps=$((processed_apps + 1))
  remaining_before=$((total_apps - processed_apps + 1))

  app_start_ts=$(date +%s)
  echo "[$processed_apps/$total_apps] Processing: $sp_name | remaining(including current): $remaining_before" >&2

  # Pull all pages of user/group assignments for this enterprise app.
  next_url="https://graph.microsoft.com/v1.0/servicePrincipals/$sp_id/appRoleAssignedTo?\$top=999"
  found_any=0

  while [ -n "$next_url" ] && [ "$next_url" != "null" ]; do
    mapfile -t assignment_rows < <(az rest \
      --method GET \
      --url "$next_url" \
      --headers ConsistencyLevel=eventual \
      --query "value[?principalType=='User' || principalType=='Group'].[id,principalType,principalId,principalDisplayName,appRoleId]" \
      -o tsv 2>/dev/null || true)

    for row in "${assignment_rows[@]}"; do
      row="${row//$'\r'/}"
      [ -z "$row" ] && continue

      IFS=$'\t' read -r assignment_id principal_type principal_id principal_name app_role_id <<< "$row"
      assignment_id="${assignment_id:-}"
      principal_type="${principal_type:-}"
      principal_id="${principal_id:-}"
      principal_name="${principal_name:-}"
      app_role_id="${app_role_id:-}"

      printf "%s,%s,%s,%s,%s,%s,%s,%s\n" \
        "$(csv_escape "$sp_id")" \
        "$(csv_escape "$sp_name")" \
        "$(csv_escape "$app_id")" \
        "$(csv_escape "$assignment_id")" \
        "$(csv_escape "$principal_type")" \
        "$(csv_escape "$principal_id")" \
        "$(csv_escape "$principal_name")" \
        "$(csv_escape "$app_role_id")" \
        >> "$TMP_OUT_FILE"

      found_any=1
    done

    next_url=$(az rest \
      --method GET \
      --url "$next_url" \
      --headers ConsistencyLevel=eventual \
      --query '"@odata.nextLink"' \
      -o tsv 2>/dev/null || echo "")
    next_url="${next_url//$'\r'/}"
    [ "$next_url" = "None" ] && next_url=""
  done

  # Include enterprise applications with no user/group assignment as empty-assignment rows.
  if [ "$found_any" -eq 0 ]; then
    printf "%s,%s,%s,%s,%s,%s,%s,%s\n" \
      "$(csv_escape "$sp_id")" \
      "$(csv_escape "$sp_name")" \
      "$(csv_escape "$app_id")" \
      "" "" "" "" "" \
      >> "$TMP_OUT_FILE"
  fi

  app_end_ts=$(date +%s)
  app_elapsed=$((app_end_ts - app_start_ts))
  remaining_after=$((total_apps - processed_apps))
  echo "[$processed_apps/$total_apps] Completed: $sp_name in ${app_elapsed}s | remaining: $remaining_after" >&2
done

FINAL_OUT_FILE="$OUT_FILE"
if ! mv -f "$TMP_OUT_FILE" "$OUT_FILE" 2>/dev/null; then
  FALLBACK_FILE="${OUT_FILE%.csv}-$(date +%Y%m%d-%H%M%S).csv"
  cp "$TMP_OUT_FILE" "$FALLBACK_FILE"
  rm -f "$TMP_OUT_FILE"
  FINAL_OUT_FILE="$FALLBACK_FILE"
  echo "Output file is busy. Wrote result to: $FALLBACK_FILE" >&2
else
  trap - EXIT
fi

script_end_ts=$(date +%s)
script_elapsed=$((script_end_ts - script_start_ts))
echo "Processed $processed_apps of $total_apps enterprise application(s)." >&2
echo "Total elapsed: ${script_elapsed}s" >&2
echo "Done. Output: $FINAL_OUT_FILE"

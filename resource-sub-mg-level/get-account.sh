#!/bin/bash

set -euo pipefail

# Optional filter: set to User/Group/ServicePrincipal/etc. or leave empty for all.
PRINCIPAL_TYPE_FILTER=""
OUTPUT_FILE="role-assignments-all-subscriptions.csv"

csv_escape() {
	local value="$1"
	value="${value//\"/\"\"}"
	printf '"%s"' "$value"
}

if ! command -v az >/dev/null 2>&1; then
	echo "ERROR: Azure CLI (az) is not installed or not in PATH." >&2
	exit 1
fi

echo "Checking Azure login..."
if ! az account show >/dev/null 2>&1; then
	echo "ERROR: Not logged in. Run: az login" >&2
	exit 1
fi

echo "Discovering subscriptions..."
mapfile -t SUBSCRIPTIONS < <(az account list --all --query "[].{id:id,name:name}" -o tsv)

if [ "${#SUBSCRIPTIONS[@]}" -eq 0 ]; then
	echo "ERROR: No subscriptions found for this account." >&2
	exit 1
fi

echo "Writing CSV: ${OUTPUT_FILE}"
echo 'SubscriptionName,SubscriptionId,PrincipalName,PrincipalType,RoleDefinitionName,Scope' > "$OUTPUT_FILE"

for sub in "${SUBSCRIPTIONS[@]}"; do
	sub_id="${sub%%$'\t'*}"
	sub_name="${sub#*$'\t'}"

	echo "Processing subscription: ${sub_name} (${sub_id})"

	if [ -n "$PRINCIPAL_TYPE_FILTER" ]; then
		query="[?principalType=='${PRINCIPAL_TYPE_FILTER}'].[principalName, principalType, roleDefinitionName, scope]"
	else
		query="[].[principalName, principalType, roleDefinitionName, scope]"
	fi

	while IFS=$'\t' read -r principal_name principal_type role_name scope; do
		[ -z "${principal_name}${principal_type}${role_name}${scope}" ] && continue

		printf '%s,%s,%s,%s,%s,%s\n' \
			"$(csv_escape "$sub_name")" \
			"$(csv_escape "$sub_id")" \
			"$(csv_escape "$principal_name")" \
			"$(csv_escape "$principal_type")" \
			"$(csv_escape "$role_name")" \
			"$(csv_escape "$scope")" \
			>> "$OUTPUT_FILE"
	done < <(
		az role assignment list \
			--subscription "$sub_id" \
			--all \
			--query "$query" \
			-o tsv
	)
done

echo "Done. Exported role assignments to: ${OUTPUT_FILE}"

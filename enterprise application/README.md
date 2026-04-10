# Enterprise Application Assignment Export

This script exports enterprise applications and their assigned users/groups to a CSV file.

## Script

- `enterprise-application.sh`

## What It Exports

- All enterprise applications that match the configured filter.
- One CSV row per assignment (user/group).
- If an enterprise application has no user/group assignment, one row is still written with empty assignment columns.

Example:
- 5 users + 2 groups assigned to one enterprise app => 7 CSV rows for that app.

## Output File

Default output:
- `enterprise-applications-all-user-group-assignments.csv`

Columns:
- `servicePrincipalId`
- `enterpriseAppDisplayName`
- `appId`
- `assignmentId`
- `principalType`
- `principalId`
- `principalDisplayName`
- `appRoleId`

## Prerequisites

- Azure CLI installed.
- Logged in to the correct tenant:
  - `az login`
  - `az account show`
- Permission to read Microsoft Entra service principals and app role assignments.

## Configuration

Edit these variables near the top of `enterprise-application.sh`:

- `OUT_FILE`
- `APP_TYPE_FILTER`

Current filter targets Enterprise Applications shown in Entra Enterprise Applications view:

- `servicePrincipalType eq 'Application' and tags/any(t:t eq 'WindowsAzureActiveDirectoryIntegratedApp')`

## Usage

From this folder:

```bash
chmod +x enterprise-application.sh
./enterprise-application.sh
```

## Runtime Logging

The script prints:

- How many enterprise applications were found.
- Per-app progress and remaining count.
- Per-app elapsed seconds.
- Total elapsed seconds.

## Reliability Notes

- Uses a temporary CSV file during generation.
- Replaces the final CSV at the end.
- If the final output file is busy/locked, writes to a timestamped fallback CSV.

## Troubleshooting

### 1. CSV has empty user/group fields

- Confirm your account has sufficient Entra directory read permissions.
- Test a direct Graph call:

```bash
sp_id="<service-principal-id>"
az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals/$sp_id/appRoleAssignedTo?$top=20" -o json
```

### 2. Script is slow

- Check filter scope (`APP_TYPE_FILTER`) is not too broad.
- Large tenants and Graph throttling can increase runtime.

### 3. Output file busy/locked

- Close the CSV in Excel or another app.
- Rerun the script; fallback output name will be shown if lock persists.

## Exit Behavior

- Exits on command errors (`set -euo pipefail`).
- Prints final output path when completed.

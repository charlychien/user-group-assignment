# get-account.sh

Exports Azure role assignments from all subscriptions visible to your signed-in account into a single CSV file.

## Script

- get-account.sh

## What It Does

- Verifies Azure CLI is installed.
- Verifies you are logged in (`az login`).
- Discovers all subscriptions from `az account list --all`.
- Iterates each subscription and runs `az role assignment list --all`.
- Writes all assignments into one CSV file.

## Output

Default output file:

- role-assignments-all-subscriptions.csv

CSV columns:

- `SubscriptionName`
- `SubscriptionId`
- `PrincipalName`
- `PrincipalType`
- `RoleDefinitionName`
- `Scope`

## Prerequisites

- Azure CLI installed and available in `PATH`.
- Logged in to Azure CLI:

```bash
az login
```

- Sufficient permissions to read role assignments in target subscriptions.

## Configuration

Edit these variables at the top of get-account.sh:

- `PRINCIPAL_TYPE_FILTER`
- `OUTPUT_FILE`

### Principal Type Filter

Use this to export only one principal type.

Examples:

```bash
PRINCIPAL_TYPE_FILTER="User"
PRINCIPAL_TYPE_FILTER="Group"
PRINCIPAL_TYPE_FILTER="ServicePrincipal"
```

Leave empty to export all principal types:

```bash
PRINCIPAL_TYPE_FILTER=""
```

## Usage

Run from this folder:

```bash
chmod +x get-account.sh
./get-account.sh
```

## Example

Only export group assignments to a custom file:

```bash
PRINCIPAL_TYPE_FILTER="Group"
OUTPUT_FILE="group-role-assignments.csv"
./get-account.sh
```

## Notes

- Runtime depends on number of subscriptions and assignments.
- The script uses CSV escaping for quoted fields.
- If no subscriptions are found, script exits with an error.

## Troubleshooting

### Not logged in

If you see login errors:

```bash
az login
az account show
```

### No subscriptions found

Verify tenant/account context:

```bash
az account list --all -o table
```

### Permission errors on assignments

Your identity needs read access for role assignments in the affected subscriptions.

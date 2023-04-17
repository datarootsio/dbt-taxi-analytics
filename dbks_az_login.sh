#!/usr/bin/env zsh

workspace_name="dbks-lakehousedemo"
warehouse_name="lakehousedemo"

if ! az account show >/dev/null 2>&1; then
    echo "Logging in to Azure CLI"
    az login
fi

echo "Hello, `az account show | jq -r '.user.name'`"
echo "Searching Databricks workspace"
dbks_resource_id=`az databricks workspace list --query "[].id" -o tsv | grep $workspace_name`

dbks_info=`az databricks workspace show --ids $dbks_resource_id`
dbks_name=`jq '.name' -r <<< "$dbks_info"`
echo "Found workspace $dbks_name, fetching host name"
export DBSQLCLI_HOST_NAME=`jq '.workspaceUrl' -r <<< "$dbks_info"`

echo "Fetching Azure AD token for Databricks"
export DATABRICKS_AAD_TOKEN=`az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --query "accessToken" -o tsv`
export DBSQLCLI_ACCESS_TOKEN=$DATABRICKS_AAD_TOKEN

echo "Configuring Databricks workspace access"
databricks configure --aad-token --host "https://$DBSQLCLI_HOST_NAME"

echo "Looking for SQL Warehouse and extracting the path"
export DBSQLCLI_HTTP_PATH=`curl -s -H "Authorization: Bearer $DATABRICKS_AAD_TOKEN" "https://$DBSQLCLI_HOST_NAME/api/2.0/sql/warehouses" | jq -r ".warehouses[] | select(.name == \"$warehouse_name\") | .odbc_params.path"`

echo "Databricks hostname: $DBSQLCLI_HOST_NAME"
echo "Databricks HTTP path: $DBSQLCLI_HTTP_PATH"

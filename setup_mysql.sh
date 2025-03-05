#!/bin/bash
set -e

# az configure --defaults location=centralus
#########################################################
# This script create the Azure Database for MySQL.
# After completed success, you can see like following result
# on your screen.
# After you executed the script, you can execute the client command.
# 
# Please execute the following command.
# ./setup_mysql.sh [flexible]
# 
#[INFO] -------------------------------------------------------
#[INFO] Azure Database for MySQL Setup Completed SUCCESS
#[INFO] -------------------------------------------------------
#[INFO] 1. Please copy the following value into your temporal file
#[INFO]
#[INFO] RESOURCE GROUP is MySQL-RG-20201126014905
#[INFO] MySQL HOSTNAME is mysqlserver-dTvtrnTHlQ.mysql.database.azure.com
#[INFO] MySQL USERNAME is azureuser@mysqlserver-dTvtrnTHlQ
#[INFO] MySQL PASSWORD is !XlXveYjn29202
#[INFO]
#[INFO]
#[INFO] 2. Please execute the following command.
#[INFO]
#[INFO] mysql -u azureuser@mysqlserver-dTvtrnTHlQ \
#[INFO]       -h mysqlserver-dTvtrnTHlQ.mysql.database.azure.com \
#[INFO]       -p [Enter Key]
#[INFO] -------------------------------------------------------
#########################################################

#########################################################
# NOTE: If you encounter the following error message when executing the command, it means that the resource provider is not registered in your environment. 
#
# Code: MissingSubscriptionRegistration
# Message: The subscription is not registered to use namespace 'Microsoft.DBforMySQL'. See https://aka.ms/rps-not-found for how to register subscriptions.
#
# In that case, please run the following command to register the MySQL resource provider.
# 
# > az provider register --namespace 'Microsoft.DBforMySQL'
# 
#########################################################

#########################################################
# Argument Check
#########################################################

MYSQL_INSTANCE_SELECT=""
if [ -z "${1:-}" ]; then
    echo "Usage: ${0##*/} [flexible]" >&2
    exit 1
fi
ARGUMENT=$1
echo "ARGUMENT:"$ARGUMENT;

if [ "$ARGUMENT" = "flexible" ]; then
  MYSQL_INSTANCE_SELECT="flexible"
else
  echo "Invalid Argument" 1>&2
  echo "$0 [flexible]" 1>&2
  exit 1
fi

#########################################################
# You can change the following parameters due to the Rule
#
# RES_GRP_NAME= Azure Resource Group Name 
# MYSQL_SERVER_NAME= MySQL Server Name
# MYSQL_USER= MySQL Login Account Name
# MYSQL_PASSWORD= MySQL Login Password
#########################################################

RESOURCE_GRP_NAME_DATE=$(date '+%Y%m%d%T' |tr -d :)

### Following is the correct version. It create the severname with lower case
### https://askubuntu.com/questions/192203/how-to-use-dev-urandom
RANDOM_SERVER_NAME=$(head -c 12 /dev/urandom | base64 | tr -dc '[:alpha:]'|tr '[:upper:]' '[:lower:]' | fold -w 10 | head -n 1)

export RES_GRP_NAME='JBoss-MySQL-RG-'$RESOURCE_GRP_NAME_DATE
export MYSQL_SERVER_NAME='mysqlserver-'$RANDOM_SERVER_NAME
export MYSQL_USER='azureuser'
MYSQL_PASSWORD='!'$(head -c 12 /dev/urandom | base64 | tr -dc '[:alpha:]'| fold -w 8 | head -n 1)$RANDOM
export PUBLIC_IP=$(curl ifconfig.io -4)

export AZ_USER_IDENTITY_NAME=user-identity-for-app

#########################################################
# For DEBUG
#########################################################
# echo "---------- DEBUG ----------"
# echo 'RES_GRP_NAME='$RES_GRP_NAME
# echo 'MYSQL_SERVER_NAME='$MYSQL_SERVER_NAME
# echo 'MYSQL_USER='$MYSQL_USER
# echo 'MYSQL_PASSWORD='$MYSQL_PASSWORD
# echo 'PUBLIC_IP='$PUBLIC_IP
# echo "---------- DEBUG ----------"

#########################################################
# When error happened following function will be executed  
#########################################################

function error_handler() {
  az group delete --no-wait --yes --name $RES_GRP_NAME
  echo "ERROR $1 occure :line no = $2" >&2
  exit 1
}
trap 'error_handler $? $LINENO' ERR

#########################################################
# Function Create Flexible Server MySQL Instance
#########################################################

function CreateFlexibleMySQLInstance() {
  az provider register --namespace 'Microsoft.DBforMySQL'
  echo "Creating MySQL Server"
  az mysql flexible-server create \
      --resource-group $RES_GRP_NAME \
      --name $MYSQL_SERVER_NAME \
      --admin-user $MYSQL_USER \
      --admin-password $MYSQL_PASSWORD \
      --sku-name Standard_B1ms \
      --tier Burstable \
      --public-access $PUBLIC_IP  \
      --storage-size 32 \
      --storage-auto-grow Enabled \
      --iops 500 \
      --version 8.0.21
  echo "Created MySQL Server as " $MYSQL_SERVER_NAME
  echo "Adding Firewall Rule for Azure Address"
  az mysql flexible-server firewall-rule create \
      -g $RES_GRP_NAME \
      -n $MYSQL_SERVER_NAME \
      -r AllowAllAzureIPs \
      --start-ip-address 0.0.0.0 \
      --end-ip-address 255.255.255.255
  echo "Added Firewall Rule for Azure Address"
}


#########################################################
# Function Create User Managed Identity for MySQL 
#########################################################

function CreateUserManagedIdentity() {
  echo "Creating User Managed Identity"
  export AZ_IDENTITY_RESOURCE_ID=$(az identity create \
    --name $AZ_USER_IDENTITY_NAME \
    --resource-group $RES_GRP_NAME \
    --query id \
    --output tsv)

  export AZ_IDENTITY_PRINCIPAL_ID=$(az identity show \
    --name $AZ_USER_IDENTITY_NAME \
    --resource-group $RES_GRP_NAME \
    --query principalId \
    --output tsv)
  echo AZ_IDENTITY_RESOURCE_ID = $AZ_IDENTITY_RESOURCE_ID
  echo AZ_IDENTITY_PRINCIPAL_ID = $AZ_IDENTITY_PRINCIPAL_ID
  echo "Created User Managed Identity"

  # Only a user with at least the Privileged Role Administrator role can grant these permissions.
  echo "Granting the User.Read.All, GroupMember.Read.All, and Application.Read.All permissions to the user managed identity"
  uri=https://graph.microsoft.com/v1.0/servicePrincipals/$AZ_IDENTITY_PRINCIPAL_ID/appRoleAssignments
  sleep 10
  graphResourceId=$(az ad sp list --display-name "Microsoft Graph" \
                     --query "[0].id" --out tsv)
  userReadAll=$(az ad sp list --display-name "Microsoft Graph" \
             --query "[0].appRoles[?value=='User.Read.All' && contains(allowedMemberTypes, 'Application')].id" \
             --output tsv)
  groupReadAll=$(az ad sp list --display-name "Microsoft Graph" \
             --query "[0].appRoles[?value=='GroupMember.Read.All' && contains(allowedMemberTypes, 'Application')].id" \
             --output tsv)
  appReadAll=$(az ad sp list --display-name "Microsoft Graph" \
             --query "[0].appRoles[?value=='Application.Read.All' && contains(allowedMemberTypes, 'Application')].id" \
             --output tsv)

  body1="{'principalId':'$AZ_IDENTITY_PRINCIPAL_ID','resourceId':'$graphResourceId','appRoleId':'$userReadAll'}"
  body2="{'principalId':'$AZ_IDENTITY_PRINCIPAL_ID','resourceId':'$graphResourceId','appRoleId':'$groupReadAll'}"
  body3="{'principalId':'$AZ_IDENTITY_PRINCIPAL_ID','resourceId':'$graphResourceId','appRoleId':'$appReadAll'}"

  az rest --method post --uri $uri --body $body1 --headers "Content-Type=application/json"
  az rest --method post --uri $uri --body $body2 --headers "Content-Type=application/json"
  az rest --method post --uri $uri --body $body3 --headers "Content-Type=application/json"
  echo "Granted permissions to the user managed identity"

  echo "Assign user-assigned managed identity to MySQL"
  az mysql flexible-server identity assign \
    --resource-group $RES_GRP_NAME \
    --server-name $MYSQL_SERVER_NAME \
    --identity $AZ_USER_IDENTITY_NAME
  echo "Assigned user-assigned managed identity to MySQL"


  echo "Create Admin User for MySQL with Azure AD User"
  export CURRENT_USERNAME=$(az ad signed-in-user show --query userPrincipalName --output tsv)
  export CURRENT_USER_OBJECTID=$(az ad signed-in-user show --query id --output tsv)
  echo CURRENT_USERNAME = $CURRENT_USERNAME
  az mysql flexible-server ad-admin create \
    --resource-group $RES_GRP_NAME \
    --server-name  $MYSQL_SERVER_NAME \
    --display-name $CURRENT_USERNAME \
    --object-id $CURRENT_USER_OBJECTID \
    --identity $AZ_USER_IDENTITY_NAME
  echo "Created Admin User for MySQL"

  echo "Added User Managed Identity"
}

#########################################################
# Create Azure Resource Group
#########################################################

echo "Creating Resource Group"
az group create --name $RES_GRP_NAME 
echo "Created Resource Group as " $RES_GRP_NAME

#########################################################
# Create MySQL on Azure Resource Group
#########################################################

if [ "$MYSQL_INSTANCE_SELECT" = "flexible" ]; then 
  CreateFlexibleMySQLInstance;
  CreateUserManagedIdentity;
fi

#########################################################
# After setup completed, Following message will be showed
#########################################################
function yellowEcho() {
    echo -e "\033[33m$*\033[m"
}

yellowEcho "[INFO] -------------------------------------------------------"
yellowEcho "[INFO] Azure Database for MySQL Setup Completed SUCCESS"
yellowEcho "[INFO] -------------------------------------------------------"
yellowEcho  "[INFO] 1. Please copy the following value into your temporal file"
yellowEcho  "[INFO]"
yellowEcho  "[INFO] RESOURCE GROUP is $RES_GRP_NAME"
yellowEcho  "[INFO] MySQL HOSTNAME is" $MYSQL_SERVER_NAME'.mysql.database.azure.com'
yellowEcho  "[INFO] MySQL ADMIN_USERNAME is" $CURRENT_USERNAME
yellowEcho  "[INFO]"
yellowEcho  "[INFO]"
yellowEcho  "[INFO] 2. Please execute the following command to create and connect to the Server."
yellowEcho  "[INFO]"
yellowEcho  "[INFO] mysql -h $MYSQL_SERVER_NAME.mysql.database.azure.com --user $CURRENT_USERNAME --enable-cleartext-plugin --password="'$(az account get-access-token --resource-type oss-rdbms --output tsv --query accessToken)'
yellowEcho  "[INFO]"
yellowEcho  "[INFO] Or you can use the following Azure CLI command"
yellowEcho  "[INFO]"
yellowEcho  "[INFO] az mysql flexible-server connect -n $MYSQL_SERVER_NAME -u $MYSQL_USER --interactive"
yellowEcho  "[INFO] Password: [$MYSQL_PASSWORD]"
yellowEcho  "[INFO] "
yellowEcho  "[INFO] "
yellowEcho  "[INFO] 3. Clean up Resource (Delete MySQL DB)"
yellowEcho  "[INFO] az group delete -n $RES_GRP_NAME"
yellowEcho  "[INFO] -------------------------------------------------------"


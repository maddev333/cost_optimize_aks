#!/bin/bash

# Set your Azure subscription ID and resource group name
subscription_id="8e09ea39-a872-4c44-91e8-b80ddcafcd7c"
resource_group="my-calico-rg"
aks_cluster="myAKSCluster"
storage_account="myAKSCluster"
backup_container="backup"

# Function to initiate Velero backup
# Function to initiate Velero backup
perform_backup() {
    current_datetime=$(date +"%Y%m%d%H%M%S")
    backup_name="akssnapshot-$current_datetime"
    
    echo "[$current_datetime] Initiating Velero backup with name: $backup_name..."

    
    velero backup create $backup_name --wait --ttl 72h0m0s

    # Check if the backup was successful
    if [ $? -eq 0 ]; then
        echo "[$current_datetime] Backup successful!"
    else
        echo "[$current_datetime] Backup failed. Exiting..."
        exit 1
    fi
}


# Function to verify AKS cluster status
verify_cluster_status() {
    cluster_status=$(az aks show --resource-group $resource_group --name $aks_cluster --query 'provisioningState' -o tsv)

    if [ "$cluster_status" == "Succeeded" ]; then
        echo "AKS cluster is running."
    else
        echo "AKS cluster is not in a running state. Exiting..."
        exit 1
    fi
}

get_cluster_details() {
    kubectl get nodes -o wide
    kubectl get pods -A -o wide
}

# Function to turn off AKS cluster
turn_off_cluster() {
    echo "Turning off AKS cluster..."
    az aks stop --resource-group $resource_group --name $aks_cluster
}

# Function to turn on AKS cluster
turn_on_cluster() {
    echo "Turning on AKS cluster..."
    az aks start --resource-group $resource_group --name $aks_cluster
}

# Function to perform cleanup (delete backups older than a certain period)
cleanup_backups() {
    echo "Performing cleanup..."
    velero backup delete --confirm --older-than 7d
}

# Main script logic
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [on|off]"
    exit 1
fi

operation=$1

case "$operation" in
    "on")
        turn_on_cluster
        verify_cluster_status
        get_cluster_details
        ;;
    "off")
        perform_backup
        turn_off_cluster
        ;;
    *)
        echo "Invalid operation. Use 'on' or 'off'."
        exit 1
        ;;
esac

# Perform cleanup after turning on the cluster
#cleanup_backups

echo "Cost optimization script completed successfully!"

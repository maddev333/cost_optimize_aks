#!/bin/bash

# Run at 7 AM and 7 PM every day except Saturday and Sunday
#0 7,19 * * 1-5 /path/to/your/script.sh
# Set your Azure subscription ID and resource group name
subscription_id="8e09ea39-a872-4c44-91e8-b80ddcafcd7c"
resource_group="my-calico-rg"
aks_cluster="myAKSCluster"
storage_account="myAKSCluster"
backup_container="backup"
alert_names=(
    "CPU Usage Percentage - myAKSCluster"
    "Memory Working Set Percentage - myAKSCluster"
)

# Get the current time in Eastern Standard Time
currentTime=$(TZ="America/New_York" date +"%H:%M:%S")

# Define start and stop times in 24-hour format (Eastern Standard Time)
startTime="07:00:00"
stopTime="19:00:00"

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
    cluster_status=$(az aks show --resource-group $resource_group --name $aks_cluster --query 'powerState.code' -o tsv)
    if [ "$cluster_status" == "Running" ]; then
        echo "AKS cluster is running."
    else
        echo "AKS cluster is not in a running state."
    fi
}

get_cluster_details() {
    kubectl get nodes -o wide
    kubectl get pods -A -o wide
}
# Function to turn off AKS cluster
turn_off_cluster() {
    verify_cluster_status
    if [ "$cluster_status" == "Running" ]; then
       echo "Disabling alerts..."
       for alert in "${alert_names[@]}"; do
           az monitor metrics alert update -g $resource_group -n "$alert" --enable false
       done
       echo "Turning off AKS cluster..."
       az aks stop --resource-group $resource_group --name $aks_cluster
    fi
}
# Function to turn on AKS cluster
turn_on_cluster() {
    verify_cluster_status
    if [ "$cluster_status" == "Stopped" ]; then
       echo "Turning on AKS cluster..."
       az aks start --resource-group $resource_group --name $aks_cluster
       echo "Enabling alerts..."
       for alert in "${alert_names[@]}"; do
           az monitor metrics alert update -g $resource_group  -n "$alert" --enable true
       done
    fi
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
        ;;
    "off")
        #perform_backup
        turn_off_cluster
        ;;
    *)
        echo "Invalid operation. Use 'on' or 'off'."
        exit 1
        ;;
esac
# Perform cleanup after turning on the cluster

# Main script logic
#verify_cluster_status

# Check if the AKS cluster is running
#if [ "$cluster_status" == "Running" ]; then
    # Check if the current time is after the stop time
#    if [[ "$currentTime" > "$stopTime" ]]; then
#        turn_off_cluster
#        verify_cluster_status
#    fi
#else
    # Check if the current time is after the start time
#    if [[ "$currentTime" > "$startTime" ]]; then
#        turn_on_cluster
#        verify_cluster_status
#    fi
#fi
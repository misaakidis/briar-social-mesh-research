#!/bin/bash

# Tested with Debian 11
# Variables for SSH connection
remote_host=
# Superuser rights needed for increasing priority of simulations with renice
remote_user=root
remote_directory=briar/one-simulations/

# Check if simulations directory exists on remote server
if ssh "$remote_user@$remote_host" "[ -d $remote_directory ]"; then
    echo "Warning: The directory '$remote_directory' already exists on the remote server."
    echo "Make sure to copy previous simulation results before deployment."

    read -p "Do you want to copy remote results? (y/n): " response
    if [[ $response == "y" || $response == "Y" ]]; then
        # Copy results from remote server
        results_data=$(date +"results-%Y-%m-%d-%H%M")

        if [ -d "$results_data" ]; then
            echo "Directory already exists. Aborting."
        exit 1
        fi

        mkdir -p $results_data
        scp -r $remote_user@$remote_host:$remote_directory/scenarios "$results_data"/scenarios
        scp -r $remote_user@$remote_host:$remote_directory/reports "$results_data"/reports
    fi

    echo "Exiting..."
    exit 1
else
    ssh "$remote_user@$remote_host" "
        apt-get update && apt-get install rsync curl htop default-jdk python3-networkx -y
        mkdir -p $remote_directory
    "
    echo "Installed dependencies and created directory '$remote_directory' on the remote server."
fi

# Copy simulations directory to remote server (including datasets)
rsync -avz --exclude={.git,data,doc,ee,example_settings,reports,scenarios,target,wdm_settings} ./* $remote_user@$remote_host:$remote_directory

# Connect to the remote server via SSH and execute commands
ssh "$remote_user@$remote_host" "
    cd $remote_directory
    nohup ./run_simulations.sh &
"
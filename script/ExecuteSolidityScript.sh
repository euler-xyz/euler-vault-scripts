#!/bin/bash

set -euo pipefail  # Exit on error, undefined vars, and pipeline failures

UTILS_DIR="script/utils"

# Function definitions
setup_utils() {
    mkdir -p "$UTILS_DIR"
    cp lib/evk-periphery/script/utils/{determineArgs.sh,checkEnvironment.sh,executeForgeScript.sh,getFileNameCounter.sh} "$UTILS_DIR/"
}

cleanup() {
    rm -rf "$UTILS_DIR"
}

handle_deployment_files() {
    local deployment_dir="$1"
    local broadcast_dir="$2"
    local jsonName="$3"

    mkdir -p "$deployment_dir/broadcast" "$deployment_dir/output"

    # Handle broadcast file
    if [ -e "$broadcast_dir/run-latest.json" ]; then
        counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/broadcast/${jsonName}.json")
        cp "$broadcast_dir/run-latest.json" "$deployment_dir/broadcast/${jsonName}_${counter}.json"
    fi

    # Handle JSON files
    for json_file in script/*.json; do
        [ -e "$json_file" ] || continue  # Skip if no JSON files exist
        jsonFileName=$(basename "$json_file")
        counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/output/$jsonFileName")
        mv "$json_file" "$deployment_dir/output/${jsonFileName%.json}_$counter.json"
    done

    # Handle CSV files
    for csv_file in script/*.csv; do
        [ -e "$csv_file" ] || continue  # Skip if no CSV files exist
        csvFileName=$(basename "$csv_file")
        counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/output/$csvFileName")
        mv "$csv_file" "$deployment_dir/output/${csvFileName%.csv}_$counter.csv"
    done
}

cleanup_json_files() {
    for json_file in script/*.json; do
        [ -e "$json_file" ] || continue  # Skip if no JSON files exist
        rm "$json_file"
    done
}

# Main script execution
if [ -z "$1" ]; then
    echo "Usage: $0 <solidity_script_path>"
    exit 1
fi

# Register cleanup function
trap cleanup EXIT

# Process script path
scriptPath="${1#./}"
scriptPath="${scriptPath#script/}"
scriptName=$(basename "$1")
shift

# Setup environment
setup_utils
source .env
eval "$(./script/utils/determineArgs.sh "$@")"
eval 'set -- $SCRIPT_ARGS'

# Check environment
if ! script/utils/checkEnvironment.sh "$@"; then
    echo "Environment check failed. Exiting."
    exit 1
fi

# Execute forge script
if script/utils/executeForgeScript.sh "$scriptPath" "$@"; then
    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
    deployment_dir="deployments/$scriptName/$chainId"
    broadcast_dir="broadcast/${scriptName}/$chainId"
    jsonName="${scriptName%.s.*}"

    if [[ "$@" == *"--dry-run"* ]]; then
        deployment_dir="$deployment_dir/dry-run"
        broadcast_dir="$broadcast_dir/dry-run"
    fi

    handle_deployment_files "$deployment_dir" "$broadcast_dir" "$jsonName"
else
    cleanup_json_files
fi

#!/bin/bash

# This script bridges tokens from L1 to L2 and vice versa.

# Function to display usage information.
usage() {
  echo "Usage: $0 --l2-rpc-url <URL>"
  echo "  --l2-rpc-url: The L2 RPC URL to query."
  exit 1
}

# Initialize variables.
l2_rpc_url=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
  --l2-rpc-url)
    l2_rpc_url="$2"
    shift 2
    ;;
  *)
    usage
    ;;
  esac
done

# Check if the required argument is provided.
if [ -z "$l2_rpc_url" ]; then
  echo "Error: L2 RPC URL is required."
  usage
fi

# Set universal parameters.
address="$(yq --raw-output .args.zkevm_l2_admin_address params.yml)"
pk="$(yq --raw-output .args.zkevm_l2_admin_private_key params.yml)"

zkevm_bridge_address="$(kurtosis service exec cdk-v1 contracts-001 "cat /opt/zkevm/combined.json" | tail -n +2 | jq --raw-output .polygonZkEVMBridgeAddress)"
zkevm_bridge_service_url="$(kurtosis port print cdk-v1 zkevm-bridge-service-001 rpc)"

l1_rpc_url="$(kurtosis port print cdk-v1 el-1-geth-lighthouse rpc)"
l1_chain_id="$(yq --raw-output .args.l1_chain_id params.yml)"
l2_chain_id="$(yq --raw-output .args.zkevm_rollup_chain_id params.yml)"

echo "Running script with values:"
echo "- Address: $address"
echo "- Private Key: ${pk#0x}"
echo "- zkEVM Bridge Address: $zkevm_bridge_address"
echo "- zkEVM Bridge Service URL: $zkevm_bridge_service_url"
echo "- L1 RPC URL: $l1_rpc_url"
echo "- L1 Chain ID: $l1_chain_id"
echo "- L2 RPC URL: $l2_rpc_url"
echo "- L2 Chain ID: $l2_chain_id"
echo

# Show balances.
l1_balance="$(cast balance --ether --rpc-url "$l1_rpc_url" "$address")"
l2_balance="$(cast balance --ether --rpc-url "$l2_rpc_url" "$address")"
echo "Balances before bridging:"
echo "- L1: $l1_balance ETH"
echo "- L2: $l2_balance ETH"
echo

# Bridge from L1 to L2.
echo "Bridging from L1 to L2..."
polycli ulxly deposit-new \
  --private-key "${pk#0x}" \
  --rpc-url "$l1_rpc_url" \
  --chain-id "$l1_chain_id" \
  --bridge-address "$zkevm_bridge_address" \
  --destination-network 1 \
  --destination-address "$address" \
  --amount 1000 \
  --verbosity 700
echo

# Loop until at least one claimable transaction is found.
echo "Waiting for the bridge service to detect the bridge event..."
while true; do
  # Query the bridge service and filter for claimable transactions on L2.
  claimable_count=$(curl -s "$zkevm_bridge_service_url/bridges/$address" |
    jq '[.deposits[] | select(.ready_for_claim == true and .claim_tx_hash == "" and .dest_net == 1)] | length')
  if [ "$claimable_count" -gt 0 ]; then
    echo "Claimable transaction found!"
    break
  else
    echo "No claimable transactions found. Retrying in 10 seconds..."
  fi
  sleep 10
done
echo

# Claim on L2.
echo "Claiming on L2..."
polycli ulxly deposit-claim \
  --private-key "${pk#0x}" \
  --rpc-url "$l2_rpc_url" \
  --chain-id "$l2_chain_id" \
  --bridge-address "$zkevm_bridge_address" \
  --bridge-service-url "$zkevm_bridge_service_url" \
  --origin-network 0 \
  --destination-network 1 \
  --claim-address "$address" \
  --claim-index 0
echo

# Show balances.
l1_balance="$(cast balance --ether --rpc-url "$l1_rpc_url" "$address")"
l2_balance="$(cast balance --ether --rpc-url "$l2_rpc_url" "$address")"
echo "Balances before bridging:"
echo "- L1: $l1_balance ETH"
echo "- L2: $l2_balance ETH"
echo

# TODO: Bridge from L2 to L1
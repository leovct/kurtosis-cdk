#!/bin/bash

# jq '
#   .genesis | reduce .[] as $item (
#     {"additional_preloaded_contracts": {}, "prefunded_accounts": {}};
#     if $item.contractName then
#       .additional_preloaded_contracts[$item.address] = ($item | del(.address, .contractName))
#     elif $item.accountName then
#       .prefunded_accounts[$item.address] = ($item | del(.address, .accountName))
#     else
#       .
#     end
#   )
# ' static_files/pre-deployed-zkevm-contracts/genesis.json

# Get the contracts from genesis.
jq --compact-output '
  .genesis 
  | map(
    select(.contractName)
      | {key: .address, value: (. | .balance += "ETH" | .code = .bytecode | del(.address) | del(.bytecode))})
  | from_entries
' templates/contract-deploy/genesis.json

# Get the accounts from genesis.
jq --compact-output '
  .genesis
  | map(
      select(.accountName)
      | {key: .address, value: (. | .balance += "ETH" | del(.address))}
    )
  | from_entries
' templates/contract-deploy/genesis.json


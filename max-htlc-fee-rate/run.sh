#!/bin/bash

if [ -z "${LND_DEPLOYMENT}" ]; then
    echo "LND_DEPLOYMENT environment variable is not set. Please set it before running this script."
    exit 1
fi

if [ -z "${MAX_FEE_RATE}" ]; then
    echo "MAX_FEE_RATE environment variable is not set. Please set it before running this script."
    exit 1
fi

if [ -z "${MAX_HTLC_SIZE_MSAT}" ]; then
    echo "MAX_HTLC_SIZE_MSAT environment variable is not set. Please set it before running this script."
    exit 1
fi

# Continue with the existing script logic
echo "Using MAX_HTLC_SIZE_MSAT: $MAX_HTLC_SIZE_MSAT"

# Get the LND Pod
lnd2Pod=$(kubectl get pods -n mainnet | grep $LND_DEPLOYMENT | awk '{print $1}' | grep -v backup)
echo "Using LND Pod: $lnd2Pod"

# Get our node's public key
ourNodePub=$(kubectl exec $lnd2Pod -n mainnet -c $LND_DEPLOYMENT -- lncli getinfo | jq -r '.identity_pubkey')
echo "Our Node Public Key: $ourNodePub"

# Get a list of all channels with channel_point and chan_id
channels=$(kubectl exec $lnd2Pod -n mainnet -c $LND_DEPLOYMENT -- lncli listchannels | jq -r '.channels[] | "\(.channel_point) \(.chan_id) \(.capacity) \(.remote_balance) \(.local_constraints.max_pending_amt_msat) \(.peer_alias)"')

while IFS= read -r line; do
    read -r channel_point chan_id capacity remote_balance max_pending_amt_msat peer_alias <<<$(echo $line | awk '{print $1, $2, $3, $4, $5, $6}')
    # Since peer_alias can contain spaces, it might be split across multiple fields. Reconstruct it if necessary.
    peer_alias=$(echo $line | cut -d' ' -f6-)

    # Fetch channel info using chan_id
    chanInfo=$(kubectl exec $lnd2Pod -n mainnet -c $LND_DEPLOYMENT -- lncli getchaninfo --chan_id $chan_id)

    # Determine which node we are (node1 or node2), extract policy details
    node1_pub=$(echo "$chanInfo" | jq -r '.node1_pub')
    policyPath=".node1_policy"
    if [[ "$ourNodePub" != "$node1_pub" ]]; then
        policyPath=".node2_policy"
    fi

    fee_base_msat=$(echo "$chanInfo" | jq -r "$policyPath.fee_base_msat")
    existing_fee_rate_milli_msat=$(echo "$chanInfo" | jq -r "$policyPath.fee_rate_milli_msat")
    time_lock_delta=$(echo "$chanInfo" | jq -r "$policyPath.time_lock_delta")

    # Adjusting MAX_HTLC_SIZE_MSAT based on max_pending_amt_msat using bc
    adjusted_max_htlc_size_msat=$(echo "if ($MAX_HTLC_SIZE_MSAT > $max_pending_amt_msat) $max_pending_amt_msat else $MAX_HTLC_SIZE_MSAT" | bc)

    # Calculate fee_rate_ppm based on local_balance/capacity ratio
    remote_balance_ratio=$((remote_balance *100/ capacity))
    # Adjust fee_rate_ppm calculation as needed based on your desired logic
    # Here we set a basic example that scales linearly with the local_balance_ratio
    if [ "$existing_fee_rate_milli_msat" -eq 0 ]; then
        fee_rate_ppm=0
    else
        fee_rate_ppm=$((remote_balance_ratio * $MAX_FEE_RATE / 100 + 10))
    fi

    echo "Updating channel with peer $peer_alias (remote balance ratio of ${remote_balance_ratio}%), setting fee rate -> $fee_rate_ppm ppm , max HTLC -> $adjusted_max_htlc_size_msat"
    kubectl exec $lnd2Pod -n mainnet -c $LND_DEPLOYMENT -- lncli updatechanpolicy --chan_point $channel_point --max_htlc_msat $adjusted_max_htlc_size_msat --base_fee_msat $fee_base_msat --fee_rate_ppm $fee_rate_ppm --time_lock_delta $time_lock_delta

done <<< "$channels"

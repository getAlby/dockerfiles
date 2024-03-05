# max-htlc-fee-rate
Script for setting max_htlc & fee_rate on each channel in a LND node

## Basic usage

```sh
$ docker run -e LND_DEPLOYMENT=alby-mainnet-lnd-2 -e MAX_FEE_RATE=2000 -e MAX_HTLC_SIZE_MSAT=15000000000 ghcr.io/getalby/max-htlc-fee-rate
```

## Environment variables

* `LND_DEPLOYMENT` - name of the deployment of LND, e.g. 'alby-mainnet-lnd-2'
* `MAX_FEE_RATE` - max fee rate to apply for each channel, this max will be for channels with full remote liquidity
* `MAX_HTLC_SIZE_MSAT` - max_htlc in msats to be set on each channel

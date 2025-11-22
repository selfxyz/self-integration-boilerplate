#!/bin/bash

# Fund the sender contract for automatic bridging

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "Error: .env file not found"
    exit 1
fi

source .env

SENDER_ADDRESS=${SENDER_ADDRESS:-"0x210ceb7f310197a3d4e83554086cced570314ee4"}
FUNDING_AMOUNT=${FUNDING_AMOUNT:-"0.01"}
RPC_URL="https://forno.celo-sepolia.celo-testnet.org"

print_info "Funding sender contract: $SENDER_ADDRESS"
print_info "Amount: $FUNDING_AMOUNT CELO"

# Send funds
cast send $SENDER_ADDRESS \
  --value ${FUNDING_AMOUNT}ether \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

print_success "Contract funded!"

# Check new balance
BALANCE=$(cast balance $SENDER_ADDRESS --rpc-url $RPC_URL)
echo ""
print_info "Contract Balance:"
echo "  $(cast --to-unit $BALANCE ether) CELO"
echo "  Enough for ~$(cast --to-unit $BALANCE ether | awk '{printf "%.0f", $1 / 0.001}') automatic bridges"

print_success "Automatic bridging is now enabled!"

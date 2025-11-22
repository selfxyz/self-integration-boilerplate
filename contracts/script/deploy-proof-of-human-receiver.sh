#!/bin/bash

# Deploy Proof of Human Receiver Contract Script
# Deploys the receiver contract on Base Sepolia

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_error ".env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

# Source environment variables
source .env

# Required environment variables
REQUIRED_VARS=(
    "PRIVATE_KEY"
)

# Check required variables
print_info "Checking required environment variables..."
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        print_error "Required environment variable $var is not set"
        exit 1
    fi
done

# Network configuration for Base Sepolia
NETWORK="base-sepolia"
RPC_URL="https://sepolia.base.org"
CHAIN_ID="84532"
BLOCK_EXPLORER_URL="https://sepolia.basescan.org"

print_success "Network configured: $NETWORK"
print_info "RPC URL: $RPC_URL"

# Build contracts
print_info "Building Solidity contracts..."
forge build
if [ $? -ne 0 ]; then
    print_error "Contract compilation failed"
    exit 1
fi
print_success "Contract compilation successful!"

# Deploy contract
print_info "Deploying ProofOfHumanReceiver contract on Base Sepolia"

DEPLOY_CMD="forge script script/DeployProofOfHumanReceiver.s.sol:DeployProofOfHumanReceiver --rpc-url $RPC_URL --broadcast --legacy"

echo "🚀 Executing deployment..."
eval $DEPLOY_CMD

# Check if deployment succeeded
echo
print_info "Checking deployment status..."
if [[ ! -f "broadcast/DeployProofOfHumanReceiver.s.sol/$CHAIN_ID/run-latest.json" ]]; then
    print_error "Contract deployment failed"
    exit 1
fi
print_success "Deployment transaction confirmed!"
echo

# Extract deployed contract address
BROADCAST_DIR="broadcast/DeployProofOfHumanReceiver.s.sol/$CHAIN_ID"
if [[ -f "$BROADCAST_DIR/run-latest.json" ]]; then
    CONTRACT_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "ProofOfHumanReceiver") | .contractAddress' "$BROADCAST_DIR/run-latest.json" | head -1 | tr '[:upper:]' '[:lower:]')
    
    if [[ -n "$CONTRACT_ADDRESS" && "$CONTRACT_ADDRESS" != "null" ]]; then
        print_success "Contract deployed at: $CONTRACT_ADDRESS"
        print_info "View on explorer: $BLOCK_EXPLORER_URL/address/$CONTRACT_ADDRESS"
    else
        print_error "Could not extract contract address from deployment"
        exit 1
    fi
else
    print_error "Could not find deployment artifacts"
    exit 1
fi

# Display deployment summary
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "🎉 Receiver Deployment Completed Successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Quick Links:"
echo "- Contract Address: $CONTRACT_ADDRESS"
echo "- View on Explorer: $BLOCK_EXPLORER_URL/address/$CONTRACT_ADDRESS"
echo
echo "Deployment Details:"
echo "| Parameter | Value |"
echo "|-----------|-------|"
echo "| Network | $NETWORK |"
echo "| Chain ID | $CHAIN_ID |"
echo "| Contract Address | $CONTRACT_ADDRESS |"
echo "| Hyperlane Mailbox | 0x6966b0E55883d49BFB24539356a2f8A673E02039 |"
echo "| Source Domain (Celo Sepolia) | 11142220 |"
echo
print_warning "IMPORTANT: Next Steps"
echo
echo "1. Add this to your contracts .env file:"
echo "   RECEIVER_ADDRESS=$CONTRACT_ADDRESS"
echo
echo "2. Update your frontend .env file (app/.env):"
echo "   NEXT_PUBLIC_RECEIVER_ADDRESS=$CONTRACT_ADDRESS"
echo
echo "   You can run this command to update it automatically:"
echo "   echo 'NEXT_PUBLIC_RECEIVER_ADDRESS=$CONTRACT_ADDRESS' >> ../app/.env"
echo
echo "3. Deploy ProofOfHumanSender on Celo Sepolia:"
echo "   ./script/deploy-proof-of-human-sender.sh"


#!/bin/bash

# Deploy Proof of Human Sender Contract Script
# Deploys the sender contract on Celo Sepolia

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
    "RECEIVER_ADDRESS"
)

# Check required variables
print_info "Checking required environment variables..."
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        print_error "Required environment variable $var is not set"
        if [ "$var" = "RECEIVER_ADDRESS" ]; then
            print_error "Please deploy ProofOfHumanReceiver first using: ./script/deploy-proof-of-human-receiver.sh"
        fi
        exit 1
    fi
done

# Set defaults for optional variables
SCOPE_SEED=${SCOPE_SEED:-"proof-of-human-hyperlane"}

# Network configuration for Celo Sepolia
IDENTITY_VERIFICATION_HUB_ADDRESS="0x16ECBA51e18a4a7e61fdC417f0d47AFEeDfbed74"
NETWORK="celo-sepolia"
RPC_URL="https://forno.celo-sepolia.celo-testnet.org"
CHAIN_ID="11142220"
BLOCK_EXPLORER_URL="https://celo-sepolia.blockscout.com"

print_success "Network configured: $NETWORK"
print_info "Hub Address: $IDENTITY_VERIFICATION_HUB_ADDRESS"
print_info "RPC URL: $RPC_URL"
print_info "Receiver Address: $RECEIVER_ADDRESS"

# Validate addresses
validate_address() {
    if [[ ! $1 =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        print_error "Invalid Ethereum address: $1"
        exit 1
    fi
}

print_info "Validating input parameters..."
validate_address "$IDENTITY_VERIFICATION_HUB_ADDRESS"
validate_address "$RECEIVER_ADDRESS"
print_success "All inputs validated successfully"

# Build contracts
print_info "Building Solidity contracts..."
forge build
if [ $? -ne 0 ]; then
    print_error "Contract compilation failed"
    exit 1
fi
print_success "Contract compilation successful!"

# Export environment variables for Solidity script
export RECEIVER_ADDRESS

# Deploy contract
print_info "Deploying ProofOfHumanSender contract with scope seed: $SCOPE_SEED"

DEPLOY_CMD="forge script script/DeployProofOfHumanSender.s.sol:DeployProofOfHumanSender --rpc-url $RPC_URL --broadcast --legacy"

echo "🚀 Executing deployment..."
eval $DEPLOY_CMD

# Check if deployment succeeded
echo
print_info "Checking deployment status..."
if [[ ! -f "broadcast/DeployProofOfHumanSender.s.sol/$CHAIN_ID/run-latest.json" ]]; then
    print_error "Contract deployment failed"
    exit 1
fi
print_success "Deployment transaction confirmed!"
echo

# Extract deployed contract address
BROADCAST_DIR="broadcast/DeployProofOfHumanSender.s.sol/$CHAIN_ID"
if [[ -f "$BROADCAST_DIR/run-latest.json" ]]; then
    CONTRACT_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "ProofOfHumanSender") | .contractAddress' "$BROADCAST_DIR/run-latest.json" | head -1 | tr '[:upper:]' '[:lower:]')
    
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
print_success "🎉 Sender Deployment Completed Successfully!"
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
echo "| Hub Address | $IDENTITY_VERIFICATION_HUB_ADDRESS |"
echo "| Hyperlane Mailbox | 0xD0680F80F4f947968206806C2598Cbc5b6FE5b03 |"
echo "| Destination Domain (Base Sepolia) | 84532 |"
echo "| Receiver Address | $RECEIVER_ADDRESS |"
echo "| Scope Seed | $SCOPE_SEED |"
echo
print_success "Deployment Complete!"
echo "1. ✅ Sender contract deployed on Celo Sepolia"
echo "2. ✅ Receiver contract deployed on Base Sepolia"
echo

# Fund the sender contract for automatic bridging
print_info "Funding sender contract for automatic bridging..."
FUNDING_AMOUNT="0.01" # 0.01 CELO (~10 automatic bridges)

# Send ETH to the contract
if cast send $CONTRACT_ADDRESS --value ${FUNDING_AMOUNT}ether --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy > /dev/null 2>&1; then
    print_success "Sent $FUNDING_AMOUNT CELO to sender contract for gas"
    echo "   Contract can now automatically bridge ~10 verifications"
    echo "3. ✅ Automatic cross-chain bridging enabled & funded"
else
    print_warning "Failed to fund contract. You may need to manually bridge verifications."
    echo "   To manually bridge: forge script script/SendVerificationCrossChain.s.sol --broadcast"
    echo "3. ⚠️  Automatic bridging enabled but not funded"
fi
echo
print_warning "IMPORTANT: Frontend Configuration"
echo
echo "Update your frontend .env file (app/.env) with these values:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "NEXT_PUBLIC_SELF_ENDPOINT=$CONTRACT_ADDRESS"
echo "NEXT_PUBLIC_RECEIVER_ADDRESS=$RECEIVER_ADDRESS"
echo "NEXT_PUBLIC_SELF_APP_NAME=\"Self + Hyperlane Workshop\""
echo "NEXT_PUBLIC_SELF_SCOPE_SEED=\"$SCOPE_SEED\""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "You can copy the entire section above and paste it into ../app/.env"
echo
echo "Or run these commands to update automatically:"
echo "  cd ../app"
echo "  echo 'NEXT_PUBLIC_SELF_ENDPOINT=$CONTRACT_ADDRESS' > .env"
echo "  echo 'NEXT_PUBLIC_RECEIVER_ADDRESS=$RECEIVER_ADDRESS' >> .env"
echo "  echo 'NEXT_PUBLIC_SELF_APP_NAME=\"Self + Hyperlane Workshop\"' >> .env"
echo "  echo 'NEXT_PUBLIC_SELF_SCOPE_SEED=\"$SCOPE_SEED\"' >> .env"
echo "  cd ../contracts"
echo
print_info "How It Works:"
echo "1. Users verify on Celo Sepolia through your frontend"
echo "2. When verification succeeds, data AUTOMATICALLY bridges to Base"
echo "3. Contract uses its balance to pay for Hyperlane gas"
echo "4. Check bridging status at https://explorer.hyperlane.xyz"
echo "5. Verify data arrived on Base at https://sepolia.basescan.org/address/$RECEIVER_ADDRESS"
echo
print_info "Contract Balance:"
BALANCE=$(cast balance $CONTRACT_ADDRESS --rpc-url $RPC_URL)
echo "  $CONTRACT_ADDRESS"
echo "  Balance: $(cast --to-unit $BALANCE ether) CELO"
echo "  Enough for ~$(cast --to-unit $BALANCE ether | awk '{printf "%.0f", $1 / 0.001}') automatic bridges"
echo
print_info "Start the frontend:"
echo "  cd ../app && npm run dev"
echo "  Open http://localhost:3000"


#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Starting deployment process..."

# Check if mops is installed
if ! command -v mops &> /dev/null; then
    echo -e "${YELLOW}Installing mops...${NC}"
    npm install -g ic-mops
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install mops${NC}"
        exit 1
    fi
fi

# Initialize mops if mops.toml doesn't exist
if [ ! -f "mops.toml" ]; then
    echo -e "${YELLOW}Initializing mops...${NC}"
    mops init
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to initialize mops${NC}"
        exit 1
    fi

    # Add necessary dependencies
    echo -e "${YELLOW}Adding dependencies...${NC}"
    mops add base
    mops add array
    mops add hash
    mops add map
fi

# Check if network parameter is provided
NETWORK=${1:-local}
echo "Deploying to network: $NETWORK"

# Function to deploy a canister
deploy_canister() {
    local canister=$1
    echo "Deploying $canister..."
    dfx deploy --network $NETWORK $canister
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $canister deployed successfully${NC}"
    else
        echo -e "${RED}✗ Failed to deploy $canister${NC}"
        exit 1
    fi
}

# Deploy each canister
deploy_canister "transactions"
deploy_canister "users"
deploy_canister "blockchains"
deploy_canister "tokens"
deploy_canister "last_processed_blocks"
deploy_canister "nfts"

echo -e "${GREEN}Deployment completed successfully!${NC}"

# Display canister IDs
echo "Canister IDs:"
dfx canister --network $NETWORK id transactions
dfx canister --network $NETWORK id users
dfx canister --network $NETWORK id blockchains
dfx canister --network $NETWORK id tokens
dfx canister --network $NETWORK id last_processed_blocks
dfx canister --network $NETWORK id nfts
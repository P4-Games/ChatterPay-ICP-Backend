#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "Starting deployment process..."

# Check for required tools
check_requirements() {
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Installing jq...${NC}"
        apt-get update && apt-get install -y jq
    fi
    if ! command -v mops &> /dev/null; then
        echo -e "${YELLOW}Installing mops...${NC}"
        npm install -g ic-mops
    fi
}

# Initialize mops
init_mops() {
    if [ ! -f "mops.toml" ]; then
        echo -e "${YELLOW}Initializing mops...${NC}"
        mops init
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to initialize mops${NC}"
            exit 1
        fi

        echo -e "${YELLOW}Adding dependencies...${NC}"
        mops add base
        mops add array
        mops add hash
        mops add map
    fi
}

# Check if dfx.json exists
if [ ! -f "dfx.json" ]; then
    echo -e "${RED}Error: dfx.json not found${NC}"
    exit 1
fi

# Install requirements
check_requirements

# Initialize mops
init_mops

# Check if network parameter is provided
NETWORK=${1:-local}
echo -e "${BLUE}Deploying to network: $NETWORK${NC}"

# Function to deploy a canister
deploy_canister() {
    local canister=$1
    echo -e "\n${YELLOW}Deploying: $canister${NC}"
    dfx deploy --network $NETWORK "$canister"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $canister deployed successfully${NC}"
        # Store canister ID
        local canister_id=$(dfx canister --network $NETWORK id "$canister")
        echo "$canister: $canister_id" >> deployed_canisters.txt
    else
        echo -e "${RED}✗ Failed to deploy $canister${NC}"
        exit 1
    fi
}

# Clear previous deployment results
rm -f deployed_canisters.txt

# Get list of Motoko canisters from dfx.json
echo -e "\n${BLUE}Detecting canisters from dfx.json...${NC}"
CANISTERS=$(jq -r '.canisters | with_entries(select(.value.type == "motoko")) | keys[]' dfx.json)

if [ -z "$CANISTERS" ]; then
    echo -e "${RED}No Motoko canisters found in dfx.json${NC}"
    exit 1
fi

# Display detected canisters
echo -e "${YELLOW}Detected canisters:${NC}"
echo "$CANISTERS" | while read -r canister; do
    echo "- $canister"
done

# Deploy each canister
echo -e "\n${BLUE}Starting deployment...${NC}"
echo "$CANISTERS" | while read -r canister; do
    deploy_canister "$canister"
done

echo -e "\n${GREEN}Deployment completed successfully!${NC}"

# Display deployment summary
echo -e "\n${YELLOW}Deployment Summary:${NC}"
if [ -f deployed_canisters.txt ]; then
    echo -e "Canister IDs:"
    while IFS=: read -r canister id; do
        echo -e "${GREEN}$canister${NC}: $id"
    done < deployed_canisters.txt
    
    # Save to canister_ids.json if it doesn't exist
    if [ ! -f canister_ids.json ]; then
        echo "{" > canister_ids.json
        first=true
        while IFS=: read -r canister id; do
            id=$(echo "$id" | tr -d ' ')
            if [ "$first" = true ]; then
                first=false
            else
                echo "," >> canister_ids.json
            fi
            echo "  \"$canister\": {" >> canister_ids.json
            echo "    \"$NETWORK\": \"$id\"" >> canister_ids.json
            echo "  }" >> canister_ids.json
        done < deployed_canisters.txt
        echo "}" >> canister_ids.json
        echo -e "\n${BLUE}Canister IDs saved to canister_ids.json${NC}"
    fi
else
    echo -e "${RED}No canisters were deployed successfully${NC}"
fi

# Cleanup
rm -f deployed_canisters.txt
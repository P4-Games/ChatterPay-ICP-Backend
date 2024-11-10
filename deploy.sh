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
    if ! command -v node &> /dev/null; then
        echo -e "${YELLOW}Installing nodejs and npm...${NC}"
        apt-get update && apt-get install -y nodejs npm
    fi
}

# Initialize project
init_project() {
    # Install node dependencies
    if [ ! -f "package.json" ]; then
        echo -e "${YELLOW}Initializing npm project...${NC}"
        npm init -y
    fi
    
    echo -e "${YELLOW}Installing dependencies...${NC}"
    npm install --save-dev dotenv

    # Initialize mops if needed
    if [ ! -f "mops.toml" ]; then
        echo -e "${YELLOW}Initializing mops...${NC}"
        mops init
        mops add base
        mops add array
        mops add hash
        mops add map
    fi

    # Create .env if it doesn't exist
    if [ ! -f ".env" ]; then
        cp .env.example .env
    fi
}

# Function to update .env file
update_env() {
    local canister=$1
    local id=$2
    local network=${3:-local}
    local env_var="${canister}_${network^^}"
    
    # Update .env file
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|^${env_var}=.*|${env_var}=\"${id}\"|" .env
    else
        # Linux
        sed -i "s|^${env_var}=.*|${env_var}=\"${id}\"|" .env
    fi
}

# Check if dfx.json exists
if [ ! -f "dfx.json" ]; then
    echo -e "${RED}Error: dfx.json not found${NC}"
    exit 1
fi

# Install requirements and initialize project
check_requirements
init_project

# Load environment variables
source .env

# Check if network parameter is provided
NETWORK=${1:-$NETWORK}
echo -e "${BLUE}Deploying to network: $NETWORK${NC}"

# Function to deploy a canister
deploy_canister() {
    local canister=$1
    echo -e "\n${YELLOW}Deploying: $canister${NC}"
    dfx deploy --network $NETWORK "$canister"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $canister deployed successfully${NC}"
        # Get and store canister ID
        local canister_id=$(dfx canister --network $NETWORK id "$canister")
        echo "$canister: $canister_id" >> deployed_canisters.txt
        # Update .env
        update_env "$canister" "$canister_id" "$NETWORK"
    else
        echo -e "${RED}✗ Failed to deploy $canister${NC}"
        exit 1
    fi
}

# Clear previous deployment results
rm -f deployed_canisters.txt

# Get list of canisters from dfx.json
echo -e "\n${BLUE}Detecting canisters from dfx.json...${NC}"
CANISTERS=$(jq -r '.canisters | keys[]' dfx.json)

if [ -z "$CANISTERS" ]; then
    echo -e "${RED}No canisters found in dfx.json${NC}"
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
    
    # Create or update canister_ids.json
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

# Function to update the ENV module
update_env_module() {
    local network=$1
    local constants_file="src/env/constants.mo"
    local constants_template="src/env/constants.mo.template"
    
    # Create canister IDs string
    local canister_ids=""
    while IFS=: read -r canister id; do
        id=$(echo "$id" | tr -d ' ')
        if [ ! -z "$canister_ids" ]; then
            canister_ids="${canister_ids};"
        fi
        canister_ids="${canister_ids}${canister}=${id}"
    done < deployed_canisters.txt

    # Update constants file
    cp $constants_template $constants_file
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|%%${network^^}_CANISTER_IDS%%|${canister_ids}|g" $constants_file
        sed -i '' "s|%%CURRENT_NETWORK%%|${network}|g" $constants_file
    else
        # Linux
        sed -i "s|%%${network^^}_CANISTER_IDS%%|${canister_ids}|g" $constants_file
        sed -i "s|%%CURRENT_NETWORK%%|${network}|g" $constants_file
    fi
}

# Update ENV module after deploying canisters
update_env_module $NETWORK

# Redeploy canisters that depend on ENV
echo -e "\n${BLUE}Updating canisters with new ENV...${NC}"
dfx deploy --network $NETWORK transactions
dfx deploy --network $NETWORK users

# Cleanup
rm -f deployed_canisters.txt

echo -e "\n${GREEN}All configurations have been updated!${NC}"
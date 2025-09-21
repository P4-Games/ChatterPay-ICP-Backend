# 🚀 ChatterPay Deployment Guide

This guide provides comprehensive instructions for deploying ChatterPay canisters to both local development and Internet Computer (IC) mainnet environments.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Deployment Process](#deployment-process)
- [Troubleshooting](#troubleshooting)
- [Network Configurations](#network-configurations)
- [Post-Deployment Verification](#post-deployment-verification)

## 🔧 Prerequisites

### Required Environment
- **Linux or WSL (Windows Subsystem for Linux)** - Required for proper script execution
- **Node.js** >= 16.0.0
- **npm** >= 7.0.0
- **Internet connection** for downloading dependencies

### Automatic Installations
The deployment script will automatically install the following if not present:
- **dfx SDK** (Internet Computer SDK)
- **mops** (Motoko package manager) - Compatible version 0.45.1
- **jq** (JSON processor)
- **azle** (TypeScript/JavaScript canister framework)

## 🖥️ Environment Setup

### Windows Users (WSL Required)

1. **Install WSL** (if not already installed):
   ```powershell
   wsl --install
   ```

2. **Open WSL terminal** and navigate to your project:
   ```bash
   cd /mnt/c/path/to/ChatterPay-ICP-Backend
   ```

3. **Fix line endings** (important for Windows users):
   ```bash
   # Convert deploy.sh to Unix line endings
   dos2unix deploy.sh
   
   # Or using sed if dos2unix is not available
   sed -i 's/\r$//' deploy.sh
   
   # Make script executable
   chmod +x deploy.sh
   ```

### Linux Users

1. **Make script executable**:
   ```bash
   chmod +x deploy.sh
   ```

## 🚀 Deployment Process

### Local Development Deployment

Deploy to local dfx replica for development and testing:

```bash
bash deploy.sh local
```

**What happens during local deployment:**
1. ✅ Installs missing dependencies automatically
2. ✅ Fixes mops compatibility issues
3. ✅ Stops any existing dfx processes
4. ✅ Starts fresh dfx replica with clean state
5. ✅ Deploys all canisters in dependency order
6. ✅ Updates `canister_ids.json` with deployed IDs
7. ✅ Updates environment constants dynamically
8. ✅ Redeploys dependent canisters with updated configuration

### Internet Computer (IC) Mainnet Deployment

Deploy to IC mainnet (production):

```bash
bash deploy.sh ic
```

**Prerequisites for IC deployment:**
- Sufficient ICP tokens for deployment costs
- Configured dfx identity with appropriate permissions

## 📦 Canister Deployment Order

The script deploys canisters in the following dependency order:

1. **blockchains** - Blockchain configuration management
2. **evm_service** - EVM interaction service (TypeScript/Azle)
3. **last_processed_blocks** - Block processing tracker
4. **nfts** - NFT management
5. **tokens** - Token management
6. **transactions** - Transaction processing (depends on evm_service)
7. **users** - User management

## 🔧 Configuration Management

### Dynamic Environment Configuration

The deployment system uses a template-based approach for environment configuration:

1. **Template File**: `src/env/constants.mo.template`
   - Contains placeholders for network-specific values
   - Used as source for generating actual constants

2. **Generated File**: `src/env/constants.mo`
   - Automatically generated during deployment
   - Contains actual canister IDs and network configuration

3. **Canister Registry**: `canister_ids.json`
   - Stores deployed canister IDs by network
   - Updated automatically after successful deployments

### Environment Variables

Create `.env` file from template (automatically done by script):
```bash
cp env.example .env
```

Key environment variables:
```bash
# Network Configuration
NETWORK=local  # or 'ic' for mainnet

# EVM Service Configuration
ARBITRUM_SEPOLIA_RPC=https://sepolia-rollup.arbitrum.io/rpc
POLYGON_RPC=https://polygon-rpc.com
BSC_RPC=https://bsc-dataseed.binance.org
# ... other RPC endpoints
```

## 🐛 Troubleshooting

### Common Issues and Solutions

#### 1. Line Endings Error (`$'\r': command not found`)
**Problem**: Windows line endings in shell script
**Solution**:
```bash
dos2unix deploy.sh
# or
sed -i 's/\r$//' deploy.sh
```

#### 2. Port Already in Use (dfx replica)
**Problem**: `Failed to bind socket to 127.0.0.1:4943`
**Solution**: The script automatically handles this by stopping existing processes

#### 3. Mops Compatibility Issues
**Problem**: `Named export 'PocketIc' not found` from pic-js-mops
**Solution**: The script automatically fixes this by:
- Removing problematic pic-js-mops
- Installing compatible mops version (0.45.1)
- Clearing mops cache

#### 4. Node.js Version Warnings
**Problem**: `Unsupported engine` warnings for Node.js version
**Solution**: These are warnings and don't prevent deployment. Consider upgrading Node.js to version 20+ for optimal compatibility.

#### 5. Azle Build Errors
**Problem**: `Invalid command found when running azle`
**Solution**: The script automatically installs azle and uses correct build command

### Manual Troubleshooting Steps

If automatic fixes don't work:

1. **Clean deployment state**:
   ```bash
   dfx stop
   rm -rf .dfx
   rm -f canister_ids.json
   ```

2. **Reinstall dependencies**:
   ```bash
   npm uninstall -g ic-mops
   npm install -g ic-mops@0.45.1
   npm install azle
   ```

3. **Verify dfx installation**:
   ```bash
   dfx --version
   ```

## 🌐 Network Configurations

### Local Development Network
- **URL**: `http://127.0.0.1:4943`
- **Candid UI**: Available for all deployed canisters
- **State**: Ephemeral (resets on `dfx start --clean`)

### Internet Computer Mainnet
- **Network ID**: `ic`
- **Costs**: Requires ICP tokens for cycles
- **State**: Persistent production environment

## ✅ Post-Deployment Verification

### Local Development

1. **Check canister status**:
   ```bash
   dfx canister --network local status --all
   ```

2. **Access Candid UI**:
   - Navigate to URLs shown in deployment output
   - Test canister functions interactively

3. **Verify configuration**:
   ```bash
   cat canister_ids.json
   cat src/env/constants.mo
   ```

### Production (IC)

1. **Verify deployment on IC dashboard**:
   - Visit Internet Computer dashboard
   - Search for your canister IDs

2. **Test canister functionality**:
   ```bash
   dfx canister --network ic call <canister_name> <function_name>
   ```

## 📁 File Structure After Deployment

```
ChatterPay-ICP-Backend/
├── .dfx/                          # dfx build artifacts
├── .docs/
│   └── deployment/
│       └── README.md              # This file
├── src/
│   └── env/
│       ├── constants.mo           # Generated (dynamic)
│       └── constants.mo.template  # Template source
├── canister_ids.json             # Generated canister IDs
├── deploy.sh                     # Main deployment script
├── env.example                   # Environment template
└── .env                          # Generated environment file
```

## 🔒 Security Considerations

### Local Development
- Uses default dfx identity (not secure for production)
- Suitable only for development and testing

### Production Deployment
- Use secure dfx identity with password protection:
  ```bash
  dfx identity new <secure-identity-name>
  dfx identity use <secure-identity-name>
  ```
- Store private keys securely
- Regularly backup canister controllers

## 📞 Support

If you encounter issues not covered in this guide:

1. Check the [testing documentation](../testing/testing-instructions.md)
2. Review dfx logs: `dfx start` (without --background)
3. Consult the [Internet Computer documentation](https://internetcomputer.org/docs)
4. Check project issues and discussions
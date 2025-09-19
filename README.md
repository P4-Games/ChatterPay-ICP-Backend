# ChatterPay ICP Backend

![](https://img.shields.io/badge/Motoko-informational?style=flat&logo=dfinity&logoColor=white&color=6aa6f8)
![](https://img.shields.io/badge/Internet_Computer-informational?style=flat&logo=dfinity&logoColor=white&color=6aa6f8)
![](https://img.shields.io/badge/DFX-informational?style=flat&logo=dfinity&logoColor=white&color=6aa6f8)
![](https://img.shields.io/badge/Candid-informational?style=flat&logo=dfinity&logoColor=white&color=6aa6f8)

ChatterPay is a Wallet that allows anyone to send and receive crypto with WhatsApp messages. Enabling crypto for +2B WhatsApp users.

This repository contains the Internet Computer backend implementation using Motoko.

**Components**:

- Landing Page ([product](https://chatterpay.net), [source code](https://github.com/P4-Games/ChatterPay))
- User Dashboard Website ([product](https://chatterpay.net/dashboard), [source code](https://github.com/P4-Games/ChatterPay))
- Backend API (this Repo)
- Smart Contracts ([source code](https://github.com/P4-Games/ChatterPay-SmartContracts))
- Data Indexing (Subgraph) ([source code](https://github.com/P4-Games/ChatterPay-Subgraph))
- Bot AI Admin Dashboard Website ([product](https://app.chatizalo.com/))
- Bot AI (Chatizalo) ([product](https://chatizalo.com/))

# About this Repo

This repository contains the Internet Computer backend implementation using Motoko, providing a decentralized backend infrastructure for ChatterPay.

**Built With**:

- Platform: [Internet Computer](https://internetcomputer.org/)
- Language: [Motoko](https://internetcomputer.org/docs/current/motoko/main/motoko)
- Development Framework: [DFX](https://internetcomputer.org/docs/current/developer-docs/build/install-upgrade-remove)
- Interface Description: [Candid](https://internetcomputer.org/docs/current/developer-docs/build/candid/candid-intro)

# Getting Started

**1. Install Requirements**:

- [DFX](https://internetcomputer.org/docs/current/developer-docs/build/install-upgrade-remove)
- [Node.js](https://nodejs.org/) (for development tools)
- [Git](https://git-scm.com/)

**2. Clone repository**:

```bash
git clone https://github.com/P4-Games/ChatterPay-ICP-Backend
cd ChatterPay-ICP-Backend
```

**3. Install DFX**:

```bash
sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh)"
```

**4. Start Local Network**:

```bash
dfx start --background
```

**5. Deploy Canisters**:

```bash
dfx deploy
```

The backend will be available at the provided canister URLs.

# Project Structure

- `src/`:
  - `types.mo`: Shared type definitions
  - `transactions/`: Transaction management canister with analytics
  - `users/`: User management canister with security features
  - `blockchains/`: Blockchain configuration canister
  - `tokens/`: Token management canister
  - `nfts/`: NFT management canister with batch operations
  - `last_processed_blocks/`: Block processing tracking canister
  - `evm_service/`: EVM integration service with multi-chain support
  - `env/`: Environment configuration and constants
- `dfx.json`: Project configuration file
- `.gitignore`: Git ignore configuration
- `README.md`: This file

# Architecture

![ICP Architecture](.docs/icp_architecture.jpeg)

The ChatterPay ICP Backend follows a microservices architecture using Internet Computer canisters, providing scalable and secure blockchain infrastructure for the WhatsApp wallet application.

# Example ideal flows:
These would be the account creation and transfer flows we want to achieve in ICP, which allow us to minimize trust without leaving the WhatsApp interface.

## Onboarding:
![ICP Onboarding flow](.docs/onboarding_flow.jpg)

## Transfer Flow:
![ICP Transfer flow](.docs/transfer_flow.jpg)

# Canisters Overview

The backend is composed of several specialized canisters:

1. **TransactionManager**:
   - Manages transaction records with multi-chain support
   - Tracks transaction status and history
   - Provides advanced analytics and querying capabilities
   - **New Features**: Transaction analytics, volume tracking, gas estimation
   - Supports Arbitrum, Polygon, BSC, and Ethereum networks

2. **UserStorage**:
   - Handles user profiles and authentication
   - Manages wallet associations and phone number mapping
   - **Security Features**: Rate limiting (10 req/min), audit logging, security metrics
   - **New Features**: Enhanced validation, duplicate prevention, audit trails

3. **NFTStorage**:
   - Handles NFT minting and management with batch operations
   - Stores and validates NFT metadata
   - Manages NFT ownership and transfers
   - **New Features**: Batch creation/updates, metadata validation, enhanced querying

4. **EVMService**:
   - EVM blockchain integration service
   - Multi-chain transaction execution
   - **New Features**: Multi-chain support, gas estimation, chain management
   - Supports multiple networks with automatic provider management

5. **BlockchainStorage**:
   - Stores blockchain configurations
   - Manages smart contract addresses
   - Handles network-specific settings

6. **TokenStorage**:
   - Manages token information
   - Tracks token metadata
   - Chain-specific token configurations

7. **LastProcessedBlockStorage**:
   - Tracks blockchain synchronization
   - Manages processing checkpoints
   - Network-specific block tracking

# API Documentation

Each canister exposes its API through Candid interfaces. Here are the main endpoints for each canister:

## Transactions
- `makeTransfer`: Execute multi-chain transfers with gas estimation
- `getTransaction`: Retrieve transaction by ID
- `getTransactionsByAddress`: Get transactions for a specific address
- `getAllTransactions`: List all transactions
- `getPendingTransactions`: Get pending transactions
- **Analytics APIs**:
  - `getTransactionCountByStatus`: Count transactions by status
  - `getTotalTransactionVolume`: Get total confirmed transaction volume
  - `getTransactionCountByAddress`: Count transactions for address
  - `estimateTransferGas`: Estimate gas costs for transfers

## Users
- `createUser`: Register a new user with validation
- `getUser`: Retrieve user information
- `getWalletByPhoneNumber`: Get wallet address by phone number
- `updateUser`: Update user information
- `deleteUser`: Remove user account
- **Security APIs**:
  - `getAuditLogs`: Get system audit logs
  - `getAuditLogsByCaller`: Get logs for specific caller
  - `getRateLimitStatus`: Check rate limit status
  - `getSecurityMetrics`: Get security metrics

## NFTs
- `createNFT`: Mint a new NFT with metadata validation
- `getNFT`: Retrieve NFT information
- `getNFTsByWallet`: Get NFTs owned by a wallet
- `updateNFTMetadata`: Update NFT metadata
- **Batch Operations**:
  - `batchCreateNFTs`: Create multiple NFTs in one operation
  - `batchUpdateMetadata`: Update multiple NFT metadata
  - `validateMetadata`: Validate NFT metadata
  - `getNFTCountByWallet`: Get NFT count for wallet

## EVM Service
- `transfer`: Execute cross-chain transfers
- `getTransactionStatus`: Check transaction status
- `validateAddress`: Validate Ethereum addresses
- **Multi-chain APIs**:
  - `estimateGas`: Estimate gas costs for transactions
  - `getSupportedChains`: Get list of supported blockchains
  - `getChainInfo`: Get information about specific chain

For complete API documentation, deploy the canisters and visit the Candid interface.

# Development

To start development:

1. Start local network:
```bash
dfx start --background
```

2. Deploy canisters:
```bash
dfx deploy
```

3. Test the API:
```bash
dfx canister call <canister_name> <method_name> '(<arguments>)'
```

# Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

# License

This project is licensed under the MIT License - see the LICENSE file for details.
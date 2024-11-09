# ChatterPay ICP Backend

![](https://img.shields.io/badge/Motoko-informational?style=flat&logo=dfinity&logoColor=white&color=6aa6f8)
![](https://img.shields.io/badge/Internet_Computer-informational?style=flat&logo=dfinity&logoColor=white&color=6aa6f8)
![](https://img.shields.io/badge/DFX-informational?style=flat&logo=dfinity&logoColor=white&color=6aa6f8)
![](https://img.shields.io/badge/Candid-informational?style=flat&logo=dfinity&logoColor=white&color=6aa6f8)

ChatterPay is a Wallet for WhatsApp that integrates AI and Account Abstraction, enabling any user to use blockchain easily and securely without technical knowledge. This repository contains the Internet Computer backend implementation using Motoko.

## Sponsored by:
![ICP Argentina](https://github.com/user-attachments/assets/65fe11f9-da59-4b4e-8f2e-4b50555a412a)

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
  - `transactions/`: Transaction management canister
  - `users/`: User management canister
  - `blockchains/`: Blockchain configuration canister
  - `tokens/`: Token management canister
  - `nfts/`: NFT management canister
  - `last_processed_blocks/`: Block processing tracking canister
- `dfx.json`: Project configuration file
- `.gitignore`: Git ignore configuration
- `README.md`: This file

# Canisters Overview

The backend is composed of several specialized canisters:

1. **TransactionStorage**:
   - Manages transaction records
   - Tracks transaction status and history
   - Provides transaction querying capabilities

2. **UserStorage**:
   - Handles user profiles and authentication
   - Manages wallet associations
   - Phone number to wallet mapping

3. **BlockchainStorage**:
   - Stores blockchain configurations
   - Manages smart contract addresses
   - Handles network-specific settings

4. **TokenStorage**:
   - Manages token information
   - Tracks token metadata
   - Chain-specific token configurations

5. **NFTStorage**:
   - Handles NFT minting and management
   - Stores NFT metadata
   - Manages NFT ownership and transfers

6. **LastProcessedBlockStorage**:
   - Tracks blockchain synchronization
   - Manages processing checkpoints
   - Network-specific block tracking

# API Documentation

Each canister exposes its API through Candid interfaces. Here are the main endpoints for each canister:

## Transactions
- `addTransaction`: Create a new transaction record
- `getTransaction`: Retrieve transaction by ID
- `getTransactionsByWallet`: Get transactions for a specific wallet
- `getAllTransactions`: List all transactions

## Users
- `createUser`: Register a new user
- `getUser`: Retrieve user information
- `getWalletByPhoneNumber`: Get wallet address by phone number
- `updateUser`: Update user information

## NFTs
- `createNFT`: Mint a new NFT
- `getNFT`: Retrieve NFT information
- `getNFTsByWallet`: Get NFTs owned by a wallet
- `updateNFTMetadata`: Update NFT metadata

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
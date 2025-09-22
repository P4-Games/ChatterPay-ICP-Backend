/**
 * @fileoverview ChatterPay NFT Service - TypeScript/Azle Implementation
 * @author ChatterPay Team
 * @version 1.0.0
 */

import { 
    Canister, 
    query, 
    update, 
    Record, 
    text, 
    nat64, 
    bool,
    Variant,
    ic,
    Vec,
    CandidType
} from 'azle/experimental';

/**
 * Candid type definitions for NFT Service
 */

/** NFT Attribute structure */
const Attribute = Record({
    trait_type: text,
    value: text
});

/** NFT Metadata structure */
const NFTMetadata = Record({
    name: text,
    description: text,
    image: text,
    attributes: Vec(Attribute)
});

/** NFT structure */
const NFT = Record({
    id: text,
    tokenId: text,
    contractAddress: text,
    owner: text,
    metadata: NFTMetadata,
    createdAt: nat64,
    lastTransfer: nat64
});

/** Authentication context */
const AuthContext = Record({
    userId: text,
    sessionId: text,
    isValid: bool
});

/** Statistics response */
const StatsResponse = Record({
    totalNFTs: nat64,
    totalWallets: nat64,
    totalContracts: nat64,
    timestamp: nat64
});

/** Health check response */
const HealthResponse = Record({
    status: text,
    totalNFTs: nat64,
    timestamp: nat64
});

/** Generic Result type for operations that can succeed or fail */
const Result = <T extends CandidType>(type: T) => Variant({
    Ok: type,
    Err: text
});

/**
 * State Management
 */

/** NFT storage by ID */
let nfts = new Map<string, any>();

/** NFTs by wallet address */
let walletNFTs = new Map<string, string[]>();

/** NFTs by contract address */
let contractNFTs = new Map<string, string[]>();

/** Owner principal - will be set on first deployment */
let OWNER: string | null = null;

/**
 * Helper functions
 */

/**
 * Validate JWT token and return auth context
 * @param jwtToken - JWT token to validate
 * @returns AuthContext or null if invalid
 */
function validateAuth(jwtToken: string): any | null {
    // Mock validation - in real implementation, verify JWT signature
    if (jwtToken.startsWith("jwt_")) {
        return {
            userId: "1",
            sessionId: "mock_session",
            isValid: true
        };
    }
    return null;
}

/**
 * Validate wallet ownership
 * @param walletId - Wallet ID to validate
 * @param userId - User ID from auth context
 * @returns Boolean indicating ownership
 */
function validateWalletOwnership(walletId: string, userId: string): boolean {
    // TODO: Implement proper wallet ownership validation with user_service
    return walletId === userId;
}

/**
 * ChatterPay NFT Service Canister
 * 
 * Provides comprehensive NFT management capabilities including creation,
 * transfer, metadata management, and search functionality.
 */
export default Canister({
    /**
     * Initialize the canister owner
     * Can only be called once when OWNER is null
     * @returns The owner principal ID or error message
     */
    initializeOwner: update([], Result(text), () => {
        if (OWNER !== null) {
            return { Err: "Owner already initialized" };
        }
        OWNER = ic.caller().toString();
        return { Ok: OWNER };
    }),

    /**
     * Get the current owner principal ID
     * @returns The owner principal ID or empty string if not set
     */
    getOwner: query([], text, () => OWNER || ""),

    /**
     * Get NFT by ID
     * Equivalent to: GET /api/v1/nft/[id]
     * @param nftId - The NFT ID to retrieve
     * @returns NFT data or error message
     */
    getNFT: query([text], Result(NFT), (nftId: string) => {
        const nft = nfts.get(nftId);
        if (!nft) {
            return { Err: "NFT_NOT_FOUND" };
        }
        return { Ok: nft };
    }),

    /**
     * Get NFTs owned by a wallet
     * Equivalent to: GET /api/v1/wallet/[id]/nfts
     * @param walletId - Wallet address
     * @param jwtToken - JWT authentication token
     * @returns Array of NFTs or error message
     */
    getWalletNFTs: update([text, text], Result(Vec(NFT)), async (walletId: string, jwtToken: string) => {
        // Validate authentication
        const authContext = validateAuth(jwtToken);
        if (!authContext || !authContext.isValid) {
            return { Err: "UNAUTHORIZED" };
        }

        if (!validateWalletOwnership(walletId, authContext.userId)) {
            return { Err: "FORBIDDEN" };
        }

        // Get NFTs for wallet
        const nftIds = walletNFTs.get(walletId) || [];
        const walletNFTList = nftIds
            .map(nftId => nfts.get(nftId))
            .filter(nft => nft !== undefined);

        return { Ok: walletNFTList };
    }),

    /**
     * Get specific NFT from wallet
     * Equivalent to: GET /api/v1/wallet/[id]/nfts/[nft_id]
     * @param walletId - Wallet address
     * @param nftId - NFT ID
     * @param jwtToken - JWT authentication token
     * @returns NFT data or error message
     */
    getWalletNFT: update([text, text, text], Result(NFT), async (walletId: string, nftId: string, jwtToken: string) => {
        // Validate authentication
        const authContext = validateAuth(jwtToken);
        if (!authContext || !authContext.isValid) {
            return { Err: "UNAUTHORIZED" };
        }

        if (!validateWalletOwnership(walletId, authContext.userId)) {
            return { Err: "FORBIDDEN" };
        }

        // Get specific NFT
        const nft = nfts.get(nftId);
        if (!nft) {
            return { Err: "NFT_NOT_FOUND" };
        }

        // Verify NFT is owned by the wallet
        if (nft.owner !== walletId) {
            return { Err: "NFT_NOT_OWNED_BY_WALLET" };
        }

        return { Ok: nft };
    }),

    /**
     * Create/Register a new NFT
     * @param nftData - NFT data to create
     * @returns Created NFT or error message
     */
    createNFT: update([NFT], Result(NFT), async (nftData: any) => {
        if (nfts.has(nftData.id)) {
            return { Err: "NFT_ALREADY_EXISTS" };
        }

        // Store NFT
        nfts.set(nftData.id, nftData);

        // Add to wallet NFTs
        const existingWalletNFTs = walletNFTs.get(nftData.owner) || [];
        walletNFTs.set(nftData.owner, [...existingWalletNFTs, nftData.id]);

        // Add to contract NFTs
        const existingContractNFTs = contractNFTs.get(nftData.contractAddress) || [];
        contractNFTs.set(nftData.contractAddress, [...existingContractNFTs, nftData.id]);

        return { Ok: nftData };
    }),

    /**
     * Transfer NFT ownership
     * @param nftId - NFT ID to transfer
     * @param newOwner - New owner address
     * @param currentOwner - Current owner address
     * @returns Success boolean or error message
     */
    transferNFT: update([text, text, text], Result(bool), async (nftId: string, newOwner: string, currentOwner: string) => {
        const nft = nfts.get(nftId);
        if (!nft) {
            return { Err: "NFT_NOT_FOUND" };
        }

        if (nft.owner !== currentOwner) {
            return { Err: "NOT_OWNER" };
        }

        // Update NFT owner
        const updatedNFT = {
            ...nft,
            owner: newOwner,
            lastTransfer: BigInt(Date.now())
        };

        nfts.set(nftId, updatedNFT);

        // Update wallet NFT mappings
        // Remove from old owner
        const oldOwnerNFTs = walletNFTs.get(currentOwner) || [];
        const filteredOldOwnerNFTs = oldOwnerNFTs.filter(id => id !== nftId);
        if (filteredOldOwnerNFTs.length > 0) {
            walletNFTs.set(currentOwner, filteredOldOwnerNFTs);
        } else {
            walletNFTs.delete(currentOwner);
        }

        // Add to new owner
        const newOwnerNFTs = walletNFTs.get(newOwner) || [];
        walletNFTs.set(newOwner, [...newOwnerNFTs, nftId]);

        return { Ok: true };
    }),

    /**
     * Update NFT metadata
     * @param nftId - NFT ID to update
     * @param newMetadata - New metadata
     * @returns Success boolean or error message
     */
    updateNFTMetadata: update([text, NFTMetadata], Result(bool), async (nftId: string, newMetadata: any) => {
        const nft = nfts.get(nftId);
        if (!nft) {
            return { Err: "NFT_NOT_FOUND" };
        }

        const updatedNFT = {
            ...nft,
            metadata: newMetadata
        };

        nfts.set(nftId, updatedNFT);
        return { Ok: true };
    }),

    /**
     * Search NFTs by metadata
     * @param query - Search query string
     * @returns Array of matching NFTs
     */
    searchNFTs: query([text], Vec(NFT), (queryStr: string) => {
        const results = [];
        for (const [nftId, nft] of nfts.entries()) {
            if (nft.metadata.name.toLowerCase().includes(queryStr.toLowerCase()) ||
                nft.metadata.description.toLowerCase().includes(queryStr.toLowerCase())) {
                results.push(nft);
            }
        }
        return results;
    }),

    /**
     * Get NFTs by contract address
     * @param contractAddress - Contract address to search
     * @returns Array of NFTs from the contract
     */
    getNFTsByContract: query([text], Vec(NFT), (contractAddress: string) => {
        const nftIds = contractNFTs.get(contractAddress) || [];
        return nftIds
            .map(nftId => nfts.get(nftId))
            .filter(nft => nft !== undefined);
    }),

    /**
     * Get NFTs by owner
     * @param owner - Owner address to search
     * @returns Array of NFTs owned by the address
     */
    getNFTsByOwner: query([text], Vec(NFT), (owner: string) => {
        const nftIds = walletNFTs.get(owner) || [];
        return nftIds
            .map(nftId => nfts.get(nftId))
            .filter(nft => nft !== undefined);
    }),

    /**
     * Get service statistics
     * @returns Statistics about the NFT service
     */
    getStats: query([], StatsResponse, () => {
        return {
            totalNFTs: BigInt(nfts.size),
            totalWallets: BigInt(walletNFTs.size),
            totalContracts: BigInt(contractNFTs.size),
            timestamp: BigInt(Date.now())
        };
    }),

    /**
     * Service health check
     * @returns Health status of the service
     */
    health: query([], HealthResponse, () => {
        return {
            status: "ok",
            totalNFTs: BigInt(nfts.size),
            timestamp: BigInt(Date.now())
        };
    }),

    /**
     * Batch create multiple NFTs
     * @param nftDataList - Array of NFT data to create
     * @returns Number of successfully created NFTs or error
     */
    batchCreateNFTs: update([Vec(NFT)], Result(nat64), async (nftDataList: any[]) => {
        let created = 0;
        
        for (const nftData of nftDataList) {
            if (!nfts.has(nftData.id)) {
                // Store NFT
                nfts.set(nftData.id, nftData);

                // Add to wallet NFTs
                const existingWalletNFTs = walletNFTs.get(nftData.owner) || [];
                walletNFTs.set(nftData.owner, [...existingWalletNFTs, nftData.id]);

                // Add to contract NFTs
                const existingContractNFTs = contractNFTs.get(nftData.contractAddress) || [];
                contractNFTs.set(nftData.contractAddress, [...existingContractNFTs, nftData.id]);

                created++;
            }
        }

        return { Ok: BigInt(created) };
    }),

    /**
     * Get NFT count by contract
     * @param contractAddress - Contract address
     * @returns Number of NFTs in the contract
     */
    getNFTCountByContract: query([text], nat64, (contractAddress: string) => {
        const nftIds = contractNFTs.get(contractAddress) || [];
        return BigInt(nftIds.length);
    }),

    /**
     * Get NFT count by owner
     * @param owner - Owner address
     * @returns Number of NFTs owned
     */
    getNFTCountByOwner: query([text], nat64, (owner: string) => {
        const nftIds = walletNFTs.get(owner) || [];
        return BigInt(nftIds.length);
    }),

    /**
     * Clear all NFT data (admin only)
     * @returns Success boolean or error
     */
    clearAllData: update([], Result(bool), () => {
        if (OWNER === null) {
            return { Err: "Owner not initialized" };
        }
        if (ic.caller().toString() !== OWNER) {
            return { Err: "Only owner can clear data" };
        }

        nfts.clear();
        walletNFTs.clear();
        contractNFTs.clear();

        return { Ok: true };
    })
});
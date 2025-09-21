/**
 * @fileoverview ChatterPay NFT Storage - NFT management and metadata handling
 * @author ChatterPay Team
 */

import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Types "../types";

/**
 * NFTStorage Canister
 * 
 * Manages NFT (Non-Fungible Token) creation, metadata, and ownership tracking
 * for the ChatterPay ecosystem. Supports original NFTs and copy management.
 */
persistent actor NFTStorage {
    /** NFT type definition from Types module */
    type NFT = Types.NFT;
    /** NFTMetadata type definition from Types module */
    type NFTMetadata = Types.NFTMetadata;
    /** ImageUrl type definition from Types module */
    type ImageUrl = Types.ImageUrl;
    /** Geolocation type definition from Types module */
    type Geolocation = Types.Geolocation;

    /** HashMap storing NFTs by their ID */
    private transient var nfts = HashMap.HashMap<Text, NFT>(0, Text.equal, Text.hash);
    /** HashMap mapping wallet addresses to their NFT IDs for fast lookup */
    private transient var walletToNFTs = HashMap.HashMap<Text, [Text]>(0, Text.equal, Text.hash);
    /** Counter for generating unique NFT IDs */
    private transient var lastId: Nat = 0;

    /**
     * Create a new NFT with metadata and ownership tracking
     * @param channel_user_id - ID of the user creating the NFT
     * @param wallet - Wallet address of the NFT owner
     * @param trxId - Transaction ID associated with NFT creation
     * @param original - Whether this is an original NFT or a copy
     * @param total_of_this - Total number of copies for this NFT series
     * @param copy_of - ID of the original NFT if this is a copy (optional)
     * @param copy_order - Order number of this copy in the series
     * @param copy_of_original - ID of the original NFT for copy tracking (optional)
     * @param copy_order_original - Order number in the original series
     * @param metadata - NFT metadata including name, description, and media
     * @returns The ID of the created NFT
     */
    public shared func createNFT(
        channel_user_id: Text,
        wallet: Text,
        trxId: Text,
        original: Bool,
        total_of_this: Nat,
        copy_of: ?Text,
        copy_order: Nat,
        copy_of_original: ?Text,
        copy_order_original: Nat,
        metadata: NFTMetadata
    ) : async Text {
        lastId += 1;
        let id = Nat.toText(lastId);
        
        let nft: NFT = {
            id = id;
            channel_user_id = channel_user_id;
            wallet = wallet;
            trxId = trxId;
            timestamp = Time.now();
            original = original;
            total_of_this = total_of_this;
            copy_of = copy_of;
            copy_order = copy_order;
            copy_of_original = copy_of_original;
            copy_order_original = copy_order_original;
            metadata = metadata;
        };

        nfts.put(id, nft);
        
        // Update wallet to NFTs mapping
        switch (walletToNFTs.get(wallet)) {
            case (null) {
                walletToNFTs.put(wallet, [id]);
            };
            case (?existing) {
                walletToNFTs.put(wallet, Array.append(existing, [id]));
            };
        };

        id
    };

    /**
     * Get NFT details by ID
     * @param id - NFT ID to retrieve
     * @returns NFT details or null if not found
     */
    public query func getNFT(id: Text) : async ?NFT {
        nfts.get(id)
    };

    /**
     * Get all NFTs owned by a specific wallet
     * @param wallet - Wallet address to get NFTs for
     * @returns Array of NFTs owned by the wallet
     */
    public query func getNFTsByWallet(wallet: Text) : async [NFT] {
        switch (walletToNFTs.get(wallet)) {
            case (null) { [] };
            case (?nftIds) {
                var walletNFTs: [NFT] = [];
                for (id in nftIds.vals()) {
                    switch (nfts.get(id)) {
                        case (?nft) {
                            walletNFTs := Array.append(walletNFTs, [nft]);
                        };
                        case (null) {};
                    };
                };
                walletNFTs
            };
        }
    };

    /**
     * Get the last assigned NFT ID
     * @returns The last assigned NFT ID
     */
    public query func getLastId() : async Nat {
        lastId
    };

    /**
     * Update NFT metadata
     * @param id - NFT ID to update
     * @param metadata - New metadata for the NFT
     * @returns True if update successful, false if NFT not found
     */
    public shared func updateNFTMetadata(
        id: Text,
        metadata: NFTMetadata
    ) : async Bool {
        switch (nfts.get(id)) {
            case (null) { false };
            case (?existingNFT) {
                let updatedNFT: NFT = {
                    id = existingNFT.id;
                    channel_user_id = existingNFT.channel_user_id;
                    wallet = existingNFT.wallet;
                    trxId = existingNFT.trxId;
                    timestamp = existingNFT.timestamp;
                    original = existingNFT.original;
                    total_of_this = existingNFT.total_of_this;
                    copy_of = existingNFT.copy_of;
                    copy_order = existingNFT.copy_order;
                    copy_of_original = existingNFT.copy_of_original;
                    copy_order_original = existingNFT.copy_order_original;
                    metadata = metadata;
                };
                nfts.put(id, updatedNFT);
                true
            };
        }
    };

    /**
     * Get all NFTs in the system
     * @returns Array of all NFTs
     */
    public query func getAllNFTs() : async [NFT] {
        var nftArray: [NFT] = [];
        for ((id, nft) in nfts.entries()) {
            nftArray := Array.append(nftArray, [nft]);
        };
        nftArray
    };

    /**
     * Get all NFTs created by a specific channel user
     * @param channelUserId - Channel user ID to get NFTs for
     * @returns Array of NFTs created by the user
     */
    public query func getNFTsByChannelUserId(channelUserId: Text) : async [NFT] {
        var userNFTs: [NFT] = [];
        for ((id, nft) in nfts.entries()) {
            if (nft.channel_user_id == channelUserId) {
                userNFTs := Array.append(userNFTs, [nft]);
            };
        };
        userNFTs
    };

    /**
     * Get all original NFTs (excluding copies)
     * @returns Array of original NFTs
     */
    public query func getOriginalNFTs() : async [NFT] {
        var originalNFTs: [NFT] = [];
        for ((id, nft) in nfts.entries()) {
            if (nft.original) {
                originalNFTs := Array.append(originalNFTs, [nft]);
            };
        };
        originalNFTs
    };

    /**
     * Get all copies of a specific original NFT
     * @param originalId - ID of the original NFT
     * @returns Array of NFT copies
     */
    public query func getNFTCopies(originalId: Text) : async [NFT] {
        var copies: [NFT] = [];
        for ((id, nft) in nfts.entries()) {
            switch (nft.copy_of_original) {
                case (?copyOf) {
                    if (copyOf == originalId) {
                        copies := Array.append(copies, [nft]);
                    };
                };
                case (null) {};
            };
        };
        copies
    };

    /**
     * Validate NFT metadata for completeness and correctness
     * @param metadata - NFT metadata to validate
     * @returns Success result or error message if validation fails
     */
    public func validateMetadata(metadata: NFTMetadata) : async Result.Result<Bool, Text> {
        // Check if description is not empty
        if (Text.size(metadata.description) == 0) {
            return #err("Description cannot be empty");
        };
        
        // Check if description is not too long (max 500 characters)
        if (Text.size(metadata.description) > 500) {
            return #err("Description cannot exceed 500 characters");
        };
        
        // Check if at least one image URL is provided
        let hasImage = switch (metadata.image_url.gcp, metadata.image_url.icp, metadata.image_url.ipfs) {
            case (null, null, null) { false };
            case (_, _, _) { true };
        };
        
        if (not hasImage) {
            return #err("At least one image URL must be provided");
        };
        
        #ok(true)
    };

    /**
     * Create multiple NFTs in a single batch operation
     * @param nftData - Array of NFT data tuples for batch creation
     * @returns Array of created NFT IDs or error message if batch fails
     */
    public shared func batchCreateNFTs(
        nftData: [(Text, Text, Text, Bool, Nat, ?Text, Nat, ?Text, Nat, NFTMetadata)]
    ) : async Result.Result<[Text], Text> {
        let results = Buffer.Buffer<Text>(nftData.size());
        
        for (data in nftData.vals()) {
            let (channel_user_id, wallet, trxId, original, total_of_this, copy_of, copy_order, copy_of_original, copy_order_original, metadata) = data;
            
            // Validate metadata
            switch (await validateMetadata(metadata)) {
                case (#err(e)) { return #err("Validation failed for NFT: " # e) };
                case (#ok(_)) { };
            };
            
            lastId += 1;
            let id = Nat.toText(lastId);
            
            let nft: NFT = {
                id = id;
                channel_user_id = channel_user_id;
                wallet = wallet;
                trxId = trxId;
                timestamp = Time.now();
                original = original;
                total_of_this = total_of_this;
                copy_of = copy_of;
                copy_order = copy_order;
                copy_of_original = copy_of_original;
                copy_order_original = copy_order_original;
                metadata = metadata;
            };

            nfts.put(id, nft);
            
            // Update wallet to NFTs mapping
            switch (walletToNFTs.get(wallet)) {
                case (null) {
                    walletToNFTs.put(wallet, [id]);
                };
                case (?existing) {
                    walletToNFTs.put(wallet, Array.append(existing, [id]));
                };
            };
            
            results.add(id);
        };
        
        #ok(Buffer.toArray(results))
    };

    /**
     * Update metadata for multiple NFTs in a single batch operation
     * @param updates - Array of NFT ID and metadata pairs for batch update
     * @returns Array of boolean results indicating success for each update
     */
    public shared func batchUpdateMetadata(
        updates: [(Text, NFTMetadata)]
    ) : async Result.Result<[Bool], Text> {
        let results = Buffer.Buffer<Bool>(updates.size());
        
        for ((id, metadata) in updates.vals()) {
            // Validate metadata
            switch (await validateMetadata(metadata)) {
                case (#err(e)) { return #err("Validation failed for NFT " # id # ": " # e) };
                case (#ok(_)) { };
            };
            
            switch (nfts.get(id)) {
                case (null) { results.add(false) };
                case (?existingNFT) {
                    let updatedNFT: NFT = {
                        id = existingNFT.id;
                        channel_user_id = existingNFT.channel_user_id;
                        wallet = existingNFT.wallet;
                        trxId = existingNFT.trxId;
                        timestamp = existingNFT.timestamp;
                        original = existingNFT.original;
                        total_of_this = existingNFT.total_of_this;
                        copy_of = existingNFT.copy_of;
                        copy_order = existingNFT.copy_order;
                        copy_of_original = existingNFT.copy_of_original;
                        copy_order_original = existingNFT.copy_order_original;
                        metadata = metadata;
                    };
                    nfts.put(id, updatedNFT);
                    results.add(true);
                };
            };
        };
        
        #ok(Buffer.toArray(results))
    };

    /**
     * Get the number of NFTs owned by a wallet
     * @param wallet - Wallet address to count NFTs for
     * @returns Number of NFTs owned by the wallet
     */
    public query func getNFTCountByWallet(wallet: Text) : async Nat {
        switch (walletToNFTs.get(wallet)) {
            case (null) { 0 };
            case (?nftIds) { nftIds.size() };
        }
    };
}
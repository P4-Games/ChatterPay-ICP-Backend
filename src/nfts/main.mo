import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Types "../types";

actor NFTStorage {
    type NFT = Types.NFT;
    type NFTMetadata = Types.NFTMetadata;
    type ImageUrl = Types.ImageUrl;
    type Geolocation = Types.Geolocation;

    private var nfts = HashMap.HashMap<Text, NFT>(0, Text.equal, Text.hash);
    private var walletToNFTs = HashMap.HashMap<Text, [Text]>(0, Text.equal, Text.hash);
    private var lastId: Nat = 0;

    // Create a new NFT
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

    // Get NFT by ID
    public query func getNFT(id: Text) : async ?NFT {
        nfts.get(id)
    };

    // Get NFTs by wallet
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

    // Get last ID
    public query func getLastId() : async Nat {
        lastId
    };

    // Update NFT metadata
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

    // Get all NFTs
    public query func getAllNFTs() : async [NFT] {
        var nftArray: [NFT] = [];
        for ((id, nft) in nfts.entries()) {
            nftArray := Array.append(nftArray, [nft]);
        };
        nftArray
    };

    // Get NFTs by channel user ID
    public query func getNFTsByChannelUserId(channelUserId: Text) : async [NFT] {
        var userNFTs: [NFT] = [];
        for ((id, nft) in nfts.entries()) {
            if (nft.channel_user_id == channelUserId) {
                userNFTs := Array.append(userNFTs, [nft]);
            };
        };
        userNFTs
    };

    // Get original NFTs (no copies)
    public query func getOriginalNFTs() : async [NFT] {
        var originalNFTs: [NFT] = [];
        for ((id, nft) in nfts.entries()) {
            if (nft.original) {
                originalNFTs := Array.append(originalNFTs, [nft]);
            };
        };
        originalNFTs
    };

    // Get copies of a specific NFT
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

    // Validate NFT metadata
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

    // Batch create NFTs
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

    // Batch update NFT metadata
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

    // Get NFT count by wallet
    public query func getNFTCountByWallet(wallet: Text) : async Nat {
        switch (walletToNFTs.get(wallet)) {
            case (null) { 0 };
            case (?nftIds) { nftIds.size() };
        }
    };
}
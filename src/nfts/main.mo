import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
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
}
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Types "../types";

persistent actor LastProcessedBlockStorage {
    type LastProcessedBlock = Types.LastProcessedBlock;
    
    private transient var nextId: Nat = 0;
    private transient var blocks = HashMap.HashMap<Nat, LastProcessedBlock>(0, Nat.equal, func(n: Nat) : Nat32 { Nat32.fromNat(n % 2**32) });
    private transient var networkToId = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);

    // Create or update last processed block
    public shared func updateLastProcessedBlock(
        networkName: Text,
        blockNumber: Nat
    ) : async Nat {
        switch (networkToId.get(networkName)) {
            case (?existingId) {
                // Update existing record
                let existingBlock = blocks.get(existingId);
                switch (existingBlock) {
                    case (?block) {
                        let updatedBlock: LastProcessedBlock = {
                            id = block.id;
                            networkName = networkName;
                            blockNumber = blockNumber;
                            updatedAt = Time.now();
                        };
                        blocks.put(existingId, updatedBlock);
                        existingId
                    };
                    case (null) { assert false; 0 };  // Should never happen
                };
            };
            case (null) {
                // Create new record
                let block: LastProcessedBlock = {
                    id = nextId;
                    networkName = networkName;
                    blockNumber = blockNumber;
                    updatedAt = Time.now();
                };
                blocks.put(nextId, block);
                networkToId.put(networkName, nextId);
                nextId += 1;
                nextId - 1
            };
        }
    };

    // Get last processed block by network name
    public query func getLastProcessedBlock(networkName: Text) : async ?LastProcessedBlock {
        switch (networkToId.get(networkName)) {
            case (null) { null };
            case (?id) { blocks.get(id) };
        }
    };

    // Get all last processed blocks
    public query func getAllLastProcessedBlocks() : async [LastProcessedBlock] {
        var blockArray: [LastProcessedBlock] = [];
        for ((id, block) in blocks.entries()) {
            blockArray := Array.append(blockArray, [block]);
        };
        blockArray
    };

    // Delete last processed block
    public shared func deleteLastProcessedBlock(networkName: Text) : async Bool {
        switch (networkToId.get(networkName)) {
            case (null) { false };
            case (?id) {
                blocks.delete(id);
                networkToId.delete(networkName);
                true
            };
        }
    };
}
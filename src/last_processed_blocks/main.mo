/**
 * @fileoverview ChatterPay Last Processed Block Storage - Blockchain synchronization tracking
 * @author ChatterPay Team
 */

import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Types "../types";

/**
 * LastProcessedBlockStorage Canister
 * 
 * Tracks the last processed block numbers for different blockchain networks.
 * Essential for maintaining synchronization state during blockchain event processing.
 */
persistent actor LastProcessedBlockStorage {
    /** LastProcessedBlock type definition from Types module */
    type LastProcessedBlock = Types.LastProcessedBlock;
    
    /** Counter for generating unique block record IDs */
    private transient var nextId: Nat = 0;
    /** HashMap storing last processed block records by internal ID */
    private transient var blocks = HashMap.HashMap<Nat, LastProcessedBlock>(0, Nat.equal, func(n: Nat) : Nat32 { Nat32.fromNat(n % 2**32) });
    /** HashMap mapping network names to internal IDs for fast lookup */
    private transient var networkToId = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);

    /**
     * Create or update last processed block number for a network
     * @param networkName - Name of the blockchain network
     * @param blockNumber - Latest processed block number
     * @returns Internal ID of the created or updated record
     */
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

    /**
     * Get last processed block information for a network
     * @param networkName - Name of the blockchain network
     * @returns Last processed block record or null if not found
     */
    public query func getLastProcessedBlock(networkName: Text) : async ?LastProcessedBlock {
        switch (networkToId.get(networkName)) {
            case (null) { null };
            case (?id) { blocks.get(id) };
        }
    };

    /**
     * Get all last processed block records
     * @returns Array of all last processed block records
     */
    public query func getAllLastProcessedBlocks() : async [LastProcessedBlock] {
        var blockArray: [LastProcessedBlock] = [];
        for ((id, block) in blocks.entries()) {
            blockArray := Array.append(blockArray, [block]);
        };
        blockArray
    };

    /**
     * Delete last processed block record for a network
     * @param networkName - Name of the blockchain network
     * @returns True if deletion successful, false if record not found
     */
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
/**
 * @fileoverview ChatterPay Blockchain Storage - Blockchain network management and configuration
 * @author ChatterPay Team
 */

import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Types "../types";
import ENV "../env/lib";

/**
 * BlockchainStorage Canister
 * 
 * Manages blockchain network configurations and contract addresses for the ChatterPay ecosystem.
 * Provides CRUD operations for blockchain networks and their associated smart contracts.
 */
persistent actor BlockchainStorage {
    /** Blockchain type definition from Types module */
    type Blockchain = Types.Blockchain;
    /** Contracts type definition from Types module */
    type Contracts = Types.Contracts;

    /** Counter for generating unique blockchain IDs */
    private var nextId: Nat = 0;
    /** HashMap storing blockchains by their internal ID */
    private transient var blockchains = HashMap.HashMap<Nat, Blockchain>(0, Nat.equal, func(n: Nat) : Nat32 { Nat32.fromNat(n % 2**32) });
    /** HashMap mapping blockchain chain IDs to internal IDs for fast lookup */
    private transient var  chainIdToId = HashMap.HashMap<Nat, Nat>(0, Nat.equal, func(n: Nat) : Nat32 { Nat32.fromNat(n % 2**32) });

    /** Secure API Manager actor reference */
    type SecureAPIManager = actor {
        getApiKey: shared (Text) -> async Result.Result<Text, Text>;
        storeApiKeyReference: shared (Text, Text, ?Int) -> async Result.Result<Text, Text>;
    };
    
    private transient let apiManager: SecureAPIManager = actor (ENV.getCanisterId("secure_api_manager"));

    /**
     * Create a new blockchain network configuration
     * @param name - Human-readable name of the blockchain network
     * @param chain_id - Unique chain identifier for the blockchain
     * @param rpc - RPC endpoint URL for blockchain interaction
     * @param logo - URL or path to blockchain logo image
     * @param explorer - Blockchain explorer URL for transaction viewing
     * @param scan_apikey - API key for blockchain scanning services (will be stored securely)
     * @param contracts - Smart contract addresses for this blockchain
     * @returns The internal ID of the created blockchain
     */
    public shared func createBlockchain(
        name: Text,
        chain_id: Nat,
        rpc: Text,
        logo: Text,
        explorer: Text,
        scan_apikey: Text,
        contracts: Contracts
    ) : async Result.Result<Nat, Text> {
        // Store API key securely first
        let serviceName = "blockchain_scan_" # name;
        switch (await apiManager.storeApiKeyReference(serviceName, scan_apikey, null)) {
            case (#err(e)) { return #err("Failed to store API key: " # e) };
            case (#ok(_)) {};
        };

        let blockchain: Blockchain = {
            id = nextId;
            name = name;
            chain_id = chain_id;
            rpc = rpc;
            logo = logo;
            explorer = explorer;
            scan_apikey = scan_apikey; // This will be removed in production
            contracts = contracts;
        };

        blockchains.put(nextId, blockchain);
        chainIdToId.put(chain_id, nextId);
        let createdId = nextId;
        nextId += 1;
        #ok(createdId)
    };

    /**
     * Get blockchain configuration by internal ID
     * @param id - Internal blockchain ID
     * @returns Blockchain configuration or null if not found
     */
    public query func getBlockchain(id: Nat) : async ?Blockchain {
        blockchains.get(id)
    };

    /**
     * Get blockchain configuration by chain ID
     * @param chainId - The blockchain's chain ID
     * @returns Blockchain configuration or null if not found
     */
    public query func getBlockchainByChainId(chainId: Nat) : async ?Blockchain {
        switch (chainIdToId.get(chainId)) {
            case (null) { null };
            case (?id) { blockchains.get(id) };
        }
    };

    /**
     * Update existing blockchain configuration
     * @param id - Internal blockchain ID to update
     * @param rpc - New RPC endpoint URL
     * @param explorer - New blockchain explorer URL
     * @param scan_apikey - New API key for scanning services
     * @param contracts - Updated smart contract addresses
     * @returns True if update successful, false if blockchain not found
     */
    public shared func updateBlockchain(
        id: Nat,
        rpc: Text,
        explorer: Text,
        scan_apikey: Text,
        contracts: Contracts
    ) : async Bool {
        switch (blockchains.get(id)) {
            case (null) { false };
            case (?existingChain) {
                let updatedChain: Blockchain = {
                    id = existingChain.id;
                    name = existingChain.name;
                    chain_id = existingChain.chain_id;
                    rpc = rpc;
                    logo = existingChain.logo;
                    explorer = explorer;
                    scan_apikey = scan_apikey;
                    contracts = contracts;
                };
                blockchains.put(id, updatedChain);
                true
            };
        }
    };

    /**
     * Delete a blockchain configuration
     * @param id - Internal blockchain ID to delete
     * @returns True if deletion successful, false if blockchain not found
     */
    public shared func deleteBlockchain(id: Nat) : async Bool {
        switch (blockchains.get(id)) {
            case (null) { false };
            case (?chain) {
                blockchains.delete(id);
                chainIdToId.delete(chain.chain_id);
                true
            };
        }
    };

    /**
     * Get all configured blockchain networks
     * @returns Array of all blockchain configurations
     */
    public query func getAllBlockchains() : async [Blockchain] {
        var chainArray: [Blockchain] = [];
        for ((id, chain) in blockchains.entries()) {
            chainArray := Array.append(chainArray, [chain]);
        };
        chainArray
    };
}
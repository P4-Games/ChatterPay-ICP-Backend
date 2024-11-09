import Array "mo:base/Array";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Types "../types";

actor BlockchainStorage {
    type Blockchain = Types.Blockchain;
    type Contracts = Types.Contracts;

    private stable var nextId: Nat = 0;
    private var blockchains = HashMap.HashMap<Nat, Blockchain>(0, Nat.equal, Hash.hash);
    private var chainIdToId = HashMap.HashMap<Nat, Nat>(0, Nat.equal, Hash.hash);

    // Create a new blockchain
    public shared func createBlockchain(
        name: Text,
        chain_id: Nat,
        rpc: Text,
        logo: Text,
        explorer: Text,
        scan_apikey: Text,
        contracts: Contracts
    ) : async Nat {
        let blockchain: Blockchain = {
            id = nextId;
            name = name;
            chain_id = chain_id;
            rpc = rpc;
            logo = logo;
            explorer = explorer;
            scan_apikey = scan_apikey;
            contracts = contracts;
        };

        blockchains.put(nextId, blockchain);
        chainIdToId.put(chain_id, nextId);
        nextId += 1;
        nextId - 1
    };

    // Get blockchain by ID
    public query func getBlockchain(id: Nat) : async ?Blockchain {
        blockchains.get(id)
    };

    // Get blockchain by chain_id
    public query func getBlockchainByChainId(chainId: Nat) : async ?Blockchain {
        switch (chainIdToId.get(chainId)) {
            case (null) { null };
            case (?id) { blockchains.get(id) };
        }
    };

    // Update blockchain
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

    // Delete blockchain
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

    // Get all blockchains
    public query func getAllBlockchains() : async [Blockchain] {
        var chainArray: [Blockchain] = [];
        for ((id, chain) in blockchains.entries()) {
            chainArray := Array.append(chainArray, [chain]);
        };
        chainArray
    };
}
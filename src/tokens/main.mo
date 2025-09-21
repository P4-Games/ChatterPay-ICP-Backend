/**
 * @fileoverview ChatterPay Token Storage - ERC-20 token management and configuration
 * @author ChatterPay Team
 */

import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Types "../types";

/**
 * TokenStorage Canister
 * 
 * Manages ERC-20 token configurations and metadata across different blockchain networks.
 * Provides CRUD operations for token information including addresses, symbols, and decimals.
 */
persistent actor TokenStorage {
    /** Token type definition from Types module */
    type Token = Types.Token;

    /** Counter for generating unique token IDs */
    private transient var nextId: Nat = 0;
    /** HashMap storing tokens by their internal ID */
    private transient var tokens = HashMap.HashMap<Nat, Token>(0, Nat.equal, func(n: Nat) : Nat32 { Nat32.fromNat(n % 2**32) });
    /** HashMap mapping token contract addresses to internal IDs for fast lookup */
    private transient var addressToId = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);

    /**
     * Create a new token configuration
     * @param name - Human-readable name of the token
     * @param chain_id - Blockchain network ID where this token exists
     * @param decimals - Number of decimal places for the token
     * @param address - Smart contract address of the token
     * @param logo - URL or path to token logo image (optional)
     * @param symbol - Token symbol (e.g., USDC, ETH)
     * @returns The internal ID of the created token
     */
    public shared func createToken(
        name: Text,
        chain_id: Nat,
        decimals: Nat,
        address: Text,
        logo: ?Text,
        symbol: Text
    ) : async Nat {
        let token: Token = {
            id = nextId;
            name = name;
            chain_id = chain_id;
            decimals = decimals;
            address = address;
            logo = logo;
            symbol = symbol;
        };

        tokens.put(nextId, token);
        addressToId.put(address, nextId);
        nextId += 1;
        nextId - 1
    };

    /**
     * Get token configuration by internal ID
     * @param id - Internal token ID
     * @returns Token configuration or null if not found
     */
    public query func getToken(id: Nat) : async ?Token {
        tokens.get(id)
    };

    /**
     * Get token configuration by contract address
     * @param address - Smart contract address of the token
     * @returns Token configuration or null if not found
     */
    public query func getTokenByAddress(address: Text) : async ?Token {
        switch (addressToId.get(address)) {
            case (null) { null };
            case (?id) { tokens.get(id) };
        }
    };

    /**
     * Get all tokens for a specific blockchain network
     * @param chainId - Blockchain network ID
     * @returns Array of tokens configured for the specified chain
     */
    public query func getTokensByChainId(chainId: Nat) : async [Token] {
        var chainTokens: [Token] = [];
        for ((id, token) in tokens.entries()) {
            if (token.chain_id == chainId) {
                chainTokens := Array.append(chainTokens, [token]);
            };
        };
        chainTokens
    };

    /**
     * Update existing token configuration
     * @param id - Internal token ID to update
     * @param name - New token name
     * @param decimals - New number of decimal places
     * @param logo - New logo URL or path (optional)
     * @param symbol - New token symbol
     * @returns True if update successful, false if token not found
     */
    public shared func updateToken(
        id: Nat,
        name: Text,
        decimals: Nat,
        logo: ?Text,
        symbol: Text
    ) : async Bool {
        switch (tokens.get(id)) {
            case (null) { false };
            case (?existingToken) {
                let updatedToken: Token = {
                    id = existingToken.id;
                    name = name;
                    chain_id = existingToken.chain_id;
                    decimals = decimals;
                    address = existingToken.address;
                    logo = logo;
                    symbol = symbol;
                };
                tokens.put(id, updatedToken);
                true
            };
        }
    };

    /**
     * Delete a token configuration
     * @param id - Internal token ID to delete
     * @returns True if deletion successful, false if token not found
     */
    public shared func deleteToken(id: Nat) : async Bool {
        switch (tokens.get(id)) {
            case (null) { false };
            case (?token) {
                tokens.delete(id);
                addressToId.delete(token.address);
                true
            };
        }
    };

    /**
     * Get all configured tokens
     * @returns Array of all token configurations
     */
    public query func getAllTokens() : async [Token] {
        var tokenArray: [Token] = [];
        for ((id, token) in tokens.entries()) {
            tokenArray := Array.append(tokenArray, [token]);
        };
        tokenArray
    };
}
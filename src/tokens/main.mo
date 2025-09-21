import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Types "../types";

persistent actor TokenStorage {
    type Token = Types.Token;

    private transient var nextId: Nat = 0;
    private transient var tokens = HashMap.HashMap<Nat, Token>(0, Nat.equal, func(n: Nat) : Nat32 { Nat32.fromNat(n % 2**32) });
    private transient var addressToId = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);

    // Create a new token
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

    // Get token by ID
    public query func getToken(id: Nat) : async ?Token {
        tokens.get(id)
    };

    // Get token by address
    public query func getTokenByAddress(address: Text) : async ?Token {
        switch (addressToId.get(address)) {
            case (null) { null };
            case (?id) { tokens.get(id) };
        }
    };

    // Get tokens by chain_id
    public query func getTokensByChainId(chainId: Nat) : async [Token] {
        var chainTokens: [Token] = [];
        for ((id, token) in tokens.entries()) {
            if (token.chain_id == chainId) {
                chainTokens := Array.append(chainTokens, [token]);
            };
        };
        chainTokens
    };

    // Update token
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

    // Delete token
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

    // Get all tokens
    public query func getAllTokens() : async [Token] {
        var tokenArray: [Token] = [];
        for ((id, token) in tokens.entries()) {
            tokenArray := Array.append(tokenArray, [token]);
        };
        tokenArray
    };
}
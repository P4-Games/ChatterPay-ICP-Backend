/**
 * @fileoverview ChatterPay Secure API Keys - Secure storage for API keys only
 * @author ChatterPay Team
 */

import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Array "mo:base/Array";
import Char "mo:base/Char";

/**
 * SecureAPIManager Actor
 * 
 * Manages API keys securely for blockchain scanning services.
 * IMPORTANT: This NEVER stores private keys - only API keys for external services.
 */
actor SecureAPIManager {
    /** API key storage entry */
    type ApiKeyEntry = {
        id: Text;
        service: Text;
        keyHash: Text; // Hashed version for reference
        createdAt: Int;
        lastUsed: Int;
        expiresAt: ?Int;
    };

    /** Access log entry for audit trail */
    type AccessLog = {
        id: Nat;
        timestamp: Int;
        caller: Principal;
        action: Text;
        service: Text;
        success: Bool;
    };

    // Storage
    private var nextLogId: Nat = 0;
    private stable var ownerPrincipal: ?Principal = null;
    
    private transient var apiKeys = HashMap.HashMap<Text, ApiKeyEntry>(0, Text.equal, Text.hash);
    private transient var accessLogs = HashMap.HashMap<Nat, AccessLog>(0, Nat.equal, func(n: Nat) : Nat32 { Nat32.fromNat(n % 2**32) });

    /**
     * Simple hash function for API keys (for reference only)
     */
    private func hashApiKey(apiKey: Text) : Text {
        var hash: Nat = 0;
        for (char in Text.toIter(apiKey)) {
            hash := hash * 31 + Nat32.toNat(Nat32.fromIntWrap(Int.abs(Char.toNat32(char))));
        };
        "hash_" # Nat.toText(hash)
    };

    /**
     * Log access attempt for audit trail
     */
    private func logAccess(caller: Principal, action: Text, service: Text, success: Bool) {
        let log: AccessLog = {
            id = nextLogId;
            timestamp = Time.now();
            caller = caller;
            action = action;
            service = service;
            success = success;
        };
        accessLogs.put(nextLogId, log);
        nextLogId += 1;
    };

    /**
     * Initialize the API manager (set owner)
     */
    public shared(msg) func initialize() : async Result.Result<Text, Text> {
        switch (ownerPrincipal) {
            case (?_) { 
                logAccess(msg.caller, "INITIALIZE", "system", false);
                #err("Already initialized") 
            };
            case (null) {
                ownerPrincipal := ?msg.caller;
                logAccess(msg.caller, "INITIALIZE", "system", true);
                #ok("API Manager initialized")
            };
        }
    };

    /**
     * Check if caller is authorized (owner only for sensitive operations)
     */
    private func isAuthorized(caller: Principal) : Bool {
        switch (ownerPrincipal) {
            case (?owner) { Principal.equal(caller, owner) };
            case (null) { false };
        }
    };

    /**
     * Store API key reference (hash only for security)
     */
    public shared(msg) func storeApiKeyReference(
        service: Text,
        apiKey: Text,
        expiresAt: ?Int
    ) : async Result.Result<Text, Text> {
        if (not isAuthorized(msg.caller)) {
            logAccess(msg.caller, "STORE_API_KEY", service, false);
            return #err("Unauthorized access");
        };

        let keyId = "api_" # service # "_" # Nat.toText(Int.abs(Time.now()));
        let keyHash = hashApiKey(apiKey);
        
        let entry: ApiKeyEntry = {
            id = keyId;
            service = service;
            keyHash = keyHash;
            createdAt = Time.now();
            lastUsed = 0;
            expiresAt = expiresAt;
        };

        apiKeys.put(keyId, entry);
        logAccess(msg.caller, "STORE_API_KEY", service, true);
        
        #ok(keyId)
    };

    /**
     * List available API services
     */
    public query func listServices() : async [Text] {
        var services: [Text] = [];
        for ((keyId, entry) in apiKeys.entries()) {
            // Check if service already in list
            var exists = false;
            for (service in services.vals()) {
                if (service == entry.service) {
                    exists := true;
                };
            };
            if (not exists) {
                services := Array.append(services, [entry.service]);
            };
        };
        services
    };

    /**
     * Delete API key
     */
    public shared(msg) func deleteApiKey(service: Text) : async Result.Result<Bool, Text> {
        if (not isAuthorized(msg.caller)) {
            logAccess(msg.caller, "DELETE_API_KEY", service, false);
            return #err("Unauthorized access");
        };

        var deleted = false;
        for ((keyId, entry) in apiKeys.entries()) {
            if (entry.service == service) {
                apiKeys.delete(keyId);
                deleted := true;
            };
        };

        if (deleted) {
            logAccess(msg.caller, "DELETE_API_KEY", service, true);
            #ok(true)
        } else {
            logAccess(msg.caller, "DELETE_API_KEY", service, false);
            #err("API key not found")
        }
    };

    /**
     * Get security metrics
     */
    public query func getSecurityMetrics() : async {
        totalApiKeys: Nat;
        totalAccessLogs: Nat;
        servicesCount: Nat;
    } {
        var servicesCount = 0;
        var seenServices = HashMap.HashMap<Text, Bool>(0, Text.equal, Text.hash);
        
        for ((keyId, entry) in apiKeys.entries()) {
            switch (seenServices.get(entry.service)) {
                case (null) {
                    seenServices.put(entry.service, true);
                    servicesCount += 1;
                };
                case (?_) {};
            };
        };
        
        {
            totalApiKeys = apiKeys.size();
            totalAccessLogs = nextLogId;
            servicesCount = servicesCount;
        }
    };

    /**
     * Get access logs (admin only)
     */
    public shared(msg) func getAccessLogs(limit: ?Nat) : async Result.Result<[AccessLog], Text> {
        if (not isAuthorized(msg.caller)) {
            return #err("Unauthorized access");
        };

        let maxLogs = switch (limit) {
            case (?n) { n };
            case (null) { 100 };
        };

        var logs: [AccessLog] = [];
        var count = 0;
        for ((id, log) in accessLogs.entries()) {
            if (count < maxLogs) {
                logs := Array.append(logs, [log]);
                count += 1;
            };
        };

        #ok(logs)
    };
}

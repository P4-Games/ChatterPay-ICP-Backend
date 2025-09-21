/**
 * @fileoverview ChatterPay User Storage - User management with security and audit features
 * @author ChatterPay Team
 */

import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Types "../types";

/**
 * UserStorage Canister
 * 
 * Comprehensive user management system with security features including rate limiting,
 * audit logging, and secure user data storage for the ChatterPay ecosystem.
 */
persistent actor UserStorage {
    /** User type definition from Types module */
    type User = Types.User;

    /** Audit log type for tracking user actions and security events */
    type AuditLog = {
        id: Nat;
        timestamp: Int;
        caller: Principal;
        action: Text;
        resource: Text;
        success: Bool;
        details: ?Text;
    };

    /** Rate limiting type for controlling API request frequency */
    type RateLimit = {
        count: Nat;
        lastReset: Int;
    };

    /** Counter for generating unique user IDs */
    private var nextId: Nat = 0;
    /** Counter for generating unique audit log IDs */
    private var nextLogId: Nat = 0;
    /** HashMap storing users by their internal ID */
    private transient var users = HashMap.HashMap<Nat, User>(0, Nat.equal, func(n: Nat) : Nat32 { Nat32.fromNat(n % 2**32) });
    /** HashMap mapping phone numbers to user IDs for fast lookup */
    private transient var phoneToId = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    /** HashMap storing audit logs by their internal ID */
    private transient var auditLogs = HashMap.HashMap<Nat, AuditLog>(0, Nat.equal, func(n: Nat) : Nat32 { Nat32.fromNat(n % 2**32) });
    /** HashMap storing rate limit data by caller principal text */
    private transient var rateLimits = HashMap.HashMap<Text, RateLimit>(0, Text.equal, Text.hash);

    /** Rate limiting window duration in nanoseconds (1 minute) */
    private transient let RATE_LIMIT_WINDOW: Int = 60_000_000_000;
    /** Maximum number of requests allowed per minute per caller */
    private transient let MAX_REQUESTS_PER_MINUTE: Nat = 10;

    /**
     * Check if a caller is within rate limits
     * @param caller - Principal making the request
     * @returns True if request is allowed, false if rate limited
     */
    private func checkRateLimit(caller: Principal) : Bool {
        let callerText = Principal.toText(caller);
        let now = Time.now();
        
        switch (rateLimits.get(callerText)) {
            case (null) {
                rateLimits.put(callerText, { count = 1; lastReset = now });
                true
            };
            case (?limit) {
                if (now - limit.lastReset > RATE_LIMIT_WINDOW) {
                    // Reset window
                    rateLimits.put(callerText, { count = 1; lastReset = now });
                    true
                } else if (limit.count >= MAX_REQUESTS_PER_MINUTE) {
                    false
                } else {
                    rateLimits.put(callerText, { 
                        count = limit.count + 1; 
                        lastReset = limit.lastReset 
                    });
                    true
                }
            };
        }
    };

    /**
     * Log an audit event for security and compliance
     * @param caller - Principal performing the action
     * @param action - Action being performed (e.g., "CREATE_USER")
     * @param resource - Resource being accessed (e.g., phone number)
     * @param success - Whether the action was successful
     * @param details - Additional details about the action (optional)
     */
    private func logAudit(caller: Principal, action: Text, resource: Text, success: Bool, details: ?Text) {
        let log: AuditLog = {
            id = nextLogId;
            timestamp = Time.now();
            caller = caller;
            action = action;
            resource = resource;
            success = success;
            details = details;
        };
        auditLogs.put(nextLogId, log);
        nextLogId += 1;
    };

    /**
     * Create a new user account with security validation
     * @param name - User's display name (optional)
     * @param email - User's email address (optional)
     * @param phone_number - User's phone number (required, must be unique)
     * @param photo - URL or path to user's profile photo (optional)
     * @param wallet - User's blockchain wallet address
     * @param code - User's verification or security code (optional)
     * @param privateKey - User's private key for blockchain interactions
     * @returns User ID if successful, error message if failed
     */
    public shared(msg) func createUser(
        name: ?Text,
        email: ?Text,
        phone_number: Text,
        photo: ?Text,
        wallet: Text,
        code: ?Nat,
        privateKey: Text
    ) : async Result.Result<Nat, Text> {
        // Check rate limit
        if (not checkRateLimit(msg.caller)) {
            logAudit(msg.caller, "CREATE_USER", phone_number, false, ?"Rate limit exceeded");
            return #err("Rate limit exceeded. Please wait before making more requests.");
        };

        // Check if phone number already exists
        switch (phoneToId.get(phone_number)) {
            case (?_existingId) {
                logAudit(msg.caller, "CREATE_USER", phone_number, false, ?"Phone number already exists");
                return #err("Phone number already registered");
            };
            case (null) { };
        };

        let user: User = {
            id = nextId;
            name = name;
            email = email;
            phone_number = phone_number;
            photo = photo;
            wallet = wallet;
            code = code;
            privateKey = privateKey;
        };

        users.put(nextId, user);
        phoneToId.put(phone_number, nextId);
        let userId = nextId;
        nextId += 1;
        
        logAudit(msg.caller, "CREATE_USER", phone_number, true, ?("User ID: " # Nat.toText(userId)));
        #ok(userId)
    };

    /**
     * Get user details by internal ID
     * @param id - Internal user ID
     * @returns User details or null if not found
     */
    public query func getUser(id: Nat) : async ?User {
        users.get(id)
    };

    /**
     * Get wallet address by phone number
     * @param phoneNumber - Phone number to lookup
     * @returns Wallet address or null if user not found
     */
    public query func getWalletByPhoneNumber(phoneNumber: Text) : async ?Text {
        switch (phoneToId.get(phoneNumber)) {
            case (null) { null };
            case (?userId) {
                switch (users.get(userId)) {
                    case (null) { null };
                    case (?user) { ?user.wallet };
                };
            };
        }
    };

    /**
     * Update existing user information
     * @param id - Internal user ID to update
     * @param name - New display name (optional)
     * @param email - New email address (optional)
     * @param photo - New profile photo URL (optional)
     * @param code - New verification code (optional)
     * @returns True if update successful, false if user not found
     */
    public shared func updateUser(
        id: Nat,
        name: ?Text,
        email: ?Text,
        photo: ?Text,
        code: ?Nat
    ) : async Bool {
        switch (users.get(id)) {
            case (null) { false };
            case (?existingUser) {
                let updatedUser: User = {
                    id = existingUser.id;
                    name = name;
                    email = email;
                    phone_number = existingUser.phone_number;
                    photo = photo;
                    wallet = existingUser.wallet;
                    code = code;
                    privateKey = existingUser.privateKey;
                };
                users.put(id, updatedUser);
                true
            };
        }
    };

    /**
     * Delete a user account
     * @param id - Internal user ID to delete
     * @returns True if deletion successful, false if user not found
     */
    public shared func deleteUser(id: Nat) : async Bool {
        switch (users.get(id)) {
            case (null) { false };
            case (?user) {
                users.delete(id);
                phoneToId.delete(user.phone_number);
                true
            };
        }
    };

    /**
     * Get all users in the system
     * @returns Array of all user records
     */
    public query func getAllUsers() : async [User] {
        var userArray: [User] = [];
        for ((id, user) in users.entries()) {
            userArray := Array.append(userArray, [user]);
        };
        userArray
    };

    /**
     * Get audit logs with optional limit (admin function)
     * @param limit - Maximum number of logs to return (optional, defaults to 100)
     * @returns Array of audit log entries
     */
    public query func getAuditLogs(limit: ?Nat) : async [AuditLog] {
        let logs = Buffer.Buffer<AuditLog>(0);
        let maxLogs = switch (limit) {
            case (?n) { n };
            case (null) { 100 }; // Default limit
        };
        
        var count = 0;
        for ((id, log) in auditLogs.entries()) {
            if (count < maxLogs) {
                logs.add(log);
                count += 1;
            };
        };
        Buffer.toArray(logs)
    };

    /**
     * Get audit logs for a specific caller
     * @param caller - Principal to get logs for
     * @param limit - Maximum number of logs to return (optional, defaults to 50)
     * @returns Array of audit log entries for the caller
     */
    public query func getAuditLogsByCaller(caller: Principal, limit: ?Nat) : async [AuditLog] {
        let logs = Buffer.Buffer<AuditLog>(0);
        let maxLogs = switch (limit) {
            case (?n) { n };
            case (null) { 50 };
        };
        
        var count = 0;
        for ((id, log) in auditLogs.entries()) {
            if (log.caller == caller and count < maxLogs) {
                logs.add(log);
                count += 1;
            };
        };
        Buffer.toArray(logs)
    };

    /**
     * Get current rate limit status for a caller
     * @param caller - Principal to check rate limit for
     * @returns Object containing remaining requests and reset time
     */
    public query func getRateLimitStatus(caller: Principal) : async {remaining: Nat; resetTime: Int} {
        let callerText = Principal.toText(caller);
        let now = Time.now();
        
        switch (rateLimits.get(callerText)) {
            case (null) {
                { remaining = MAX_REQUESTS_PER_MINUTE; resetTime = now + RATE_LIMIT_WINDOW }
            };
            case (?limit) {
                if (now - limit.lastReset > RATE_LIMIT_WINDOW) {
                    { remaining = MAX_REQUESTS_PER_MINUTE; resetTime = now + RATE_LIMIT_WINDOW }
                } else {
                    // Calculate remaining requests safely
                    let remaining = if (limit.count >= MAX_REQUESTS_PER_MINUTE) { 
                        0 
                    } else { 
                        // Safe calculation using iteration to avoid trap warning
                        var count = 0;
                        var remaining = MAX_REQUESTS_PER_MINUTE;
                        while (count < limit.count) {
                            remaining -= 1;
                            count += 1;
                        };
                        remaining
                    };
                    { remaining = remaining; resetTime = limit.lastReset + RATE_LIMIT_WINDOW }
                }
            };
        }
    };

    /**
     * Get security metrics and statistics
     * @returns Object containing total audit logs, failed attempts, and unique callers
     */
    public query func getSecurityMetrics() : async {
        totalAuditLogs: Nat;
        failedAttempts: Nat;
        uniqueCallers: Nat;
    } {
        var failedCount = 0;
        let callers = HashMap.HashMap<Text, Bool>(0, Text.equal, Text.hash);
        
        for ((id, log) in auditLogs.entries()) {
            if (not log.success) {
                failedCount += 1;
            };
            callers.put(Principal.toText(log.caller), true);
        };
        
        {
            totalAuditLogs = nextLogId;
            failedAttempts = failedCount;
            uniqueCallers = callers.size();
        }
    };
}
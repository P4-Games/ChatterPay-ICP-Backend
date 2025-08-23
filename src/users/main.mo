import Array "mo:base/Array";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Types "../types";

actor UserStorage {
    type User = Types.User;

    // Audit log types
    type AuditLog = {
        id: Nat;
        timestamp: Int;
        caller: Principal;
        action: Text;
        resource: Text;
        success: Bool;
        details: ?Text;
    };

    // Rate limiting types
    type RateLimit = {
        count: Nat;
        lastReset: Int;
    };

    private stable var nextId: Nat = 0;
    private stable var nextLogId: Nat = 0;
    private var users = HashMap.HashMap<Nat, User>(0, Nat.equal, Hash.hash);
    private var phoneToId = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    private var auditLogs = HashMap.HashMap<Nat, AuditLog>(0, Nat.equal, Hash.hash);
    private var rateLimits = HashMap.HashMap<Text, RateLimit>(0, Text.equal, Text.hash);

    // Rate limiting constants
    private let RATE_LIMIT_WINDOW: Int = 60_000_000_000; // 1 minute in nanoseconds
    private let MAX_REQUESTS_PER_MINUTE: Nat = 10;

    // Rate limiting check
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

    // Audit logging
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

    // Create a new user
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
            case (?existingId) {
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

    // Get user by ID
    public query func getUser(id: Nat) : async ?User {
        users.get(id)
    };

    // Implementation of getWalletByPhoneNumber
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

    // Update user
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

    // Delete user
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

    // Get all users
    public query func getAllUsers() : async [User] {
        var userArray: [User] = [];
        for ((id, user) in users.entries()) {
            userArray := Array.append(userArray, [user]);
        };
        userArray
    };

    // Get audit logs (admin function)
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

    // Get audit logs by caller
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

    // Get rate limit status for caller
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
                    let remaining = if (limit.count >= MAX_REQUESTS_PER_MINUTE) { 0 } 
                                  else { MAX_REQUESTS_PER_MINUTE - limit.count };
                    { remaining = remaining; resetTime = limit.lastReset + RATE_LIMIT_WINDOW }
                }
            };
        }
    };

    // Security metrics
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
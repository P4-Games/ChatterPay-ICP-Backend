/**
 * @fileoverview ChatterPay User Service - User management and profile operations
 * @author ChatterPay Team
 * @version 1.0.0
 */

import Time "mo:base/Time";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";

/**
 * User Service Canister
 * 
 * Handles user profile management, CRUD operations, and user-related
 * functionality for the ChatterPay ecosystem.
 */
persistent actor UserService {
    
    /** User type definition */
    public type User = {
        id: Nat;
        name: ?Text;
        email: ?Text;
        phone_number: Text;
        photo: ?Text;
        wallet: Text;
        code: ?Nat;
    };
    
    /** User update request */
    public type UserUpdateRequest = {
        name: ?Text;
        email: ?Text;
        photo: ?Text;
    };
    
    /** Email update request with 2FA */
    public type EmailUpdateRequest = {
        phone: Text;
        code: Text;
        email: Text;
    };
    
    /** Authentication context */
    public type AuthContext = {
        userId: Text;
        sessionId: Text;
        isValid: Bool;
    };
    
    // Storage (HashMaps cannot be stable, they will be transient)
    private transient var users = HashMap.HashMap<Text, User>(0, Text.equal, Text.hash);
    private transient var phoneToUserId = HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);
    
    /**
     * Simple JWT validation (mock implementation)
     * TODO: Replace with proper inter-canister call to auth_service
     */
    private func validateAuth(jwtToken: Text) : ?AuthContext {
        if (Text.startsWith(jwtToken, #text "jwt_")) {
            ?{
                userId = "1";
                sessionId = "mock_session";
                isValid = true;
            }
        } else {
            null
        }
    };
    
    /**
     * Validate user permission to access resource
     */
    private func validateUserPermission(authUserId: Text, targetUserId: Text) : Bool {
        authUserId == targetUserId
    };
    
    /**
     * Get user by ID
     * 
     * Equivalent to: GET /api/v1/user/[id]
     * Original Next.js implementation: Returns user profile data
     * 
     * @param userId - User ID from path parameter
     * @param jwtToken - JWT token for authentication
     * @returns User profile data or error
     */
    public func getUser(userId: Text, jwtToken: Text) : async Result.Result<User, Text> {
        // Validate authentication
        switch (validateAuth(jwtToken)) {
            case (null) { #err("UNAUTHORIZED") };
            case (?authContext) {
                if (not authContext.isValid) {
                    return #err("UNAUTHORIZED");
                };
                
                // Validate user permission
                if (not validateUserPermission(authContext.userId, userId)) {
                    return #err("FORBIDDEN");
                };
                
                // Get user data
                switch (users.get(userId)) {
                    case (null) { #err("USER_NOT_FOUND") };
                    case (?user) { #ok(user) };
                }
            };
        }
    };
    
    /**
     * Update user profile
     * 
     * Equivalent to: POST /api/v1/user/[id]
     * Original Next.js implementation: Updates user name and profile data
     * 
     * @param userId - User ID from path parameter
     * @param updateRequest - User update data
     * @param jwtToken - JWT token for authentication
     * @returns Success result or error
     */
    public func updateUser(userId: Text, updateRequest: UserUpdateRequest, jwtToken: Text) : async Result.Result<Bool, Text> {
        // Validate authentication
        switch (validateAuth(jwtToken)) {
            case (null) { #err("UNAUTHORIZED") };
            case (?authContext) {
                if (not authContext.isValid) {
                    return #err("UNAUTHORIZED");
                };
                
                // Validate user permission
                if (not validateUserPermission(authContext.userId, userId)) {
                    return #err("FORBIDDEN");
                };
                
                // Get existing user
                switch (users.get(userId)) {
                    case (null) { #err("USER_NOT_FOUND") };
                    case (?existingUser) {
                        // Update user data
                        let updatedUser: User = {
                            id = existingUser.id;
                            name = updateRequest.name;
                            email = switch (updateRequest.email) {
                                case (null) { existingUser.email };
                                case (?newEmail) { ?newEmail };
                            };
                            phone_number = existingUser.phone_number;
                            photo = updateRequest.photo;
                            wallet = existingUser.wallet;
                            code = existingUser.code;
                        };
                        
                        users.put(userId, updatedUser);
                        #ok(true)
                    };
                }
            };
        }
    };
    
    /**
     * Update user email with 2FA verification
     * 
     * Equivalent to: POST /api/v1/user/[id]/email
     * Original Next.js implementation: Updates email after 2FA code validation
     * 
     * @param userId - User ID from path parameter
     * @param emailRequest - Email update request with 2FA code
     * @param jwtToken - JWT token for authentication
     * @returns Success result or error
     */
    public func updateEmail(userId: Text, emailRequest: EmailUpdateRequest, jwtToken: Text) : async Result.Result<Bool, Text> {
        // Validate authentication
        switch (validateAuth(jwtToken)) {
            case (null) { #err("UNAUTHORIZED") };
            case (?authContext) {
                if (not authContext.isValid) {
                    return #err("UNAUTHORIZED");
                };
                
                // Validate user permission
                if (not validateUserPermission(authContext.userId, userId)) {
                    return #err("FORBIDDEN");
                };
                
                // Input validation
                if (emailRequest.phone == "" or emailRequest.code == "" or emailRequest.email == "") {
                    return #err("INVALID_REQUEST_PARAMS");
                };
                
                // TODO: Validate 2FA code via external service
                // For now, accept any 6-digit code
                if (Text.size(emailRequest.code) != 6) {
                    return #err("INVALID_2FA_CODE");
                };
                
                // Get existing user
                switch (users.get(userId)) {
                    case (null) { #err("USER_NOT_FOUND") };
                    case (?existingUser) {
                        // Verify phone number matches
                        if (existingUser.phone_number != emailRequest.phone) {
                            return #err("PHONE_MISMATCH");
                        };
                        
                        // Update email
                        let updatedUser: User = {
                            id = existingUser.id;
                            name = existingUser.name;
                            email = ?emailRequest.email;
                            phone_number = existingUser.phone_number;
                            photo = existingUser.photo;
                            wallet = existingUser.wallet;
                            code = null; // Clear 2FA code after use
                        };
                        
                        users.put(userId, updatedUser);
                        #ok(true)
                    };
                }
            };
        }
    };
    
    /**
     * Create a new user (internal function)
     * 
     * @param userData - User data to create
     * @returns Created user or error
     */
    public func createUser(userData: User) : async Result.Result<User, Text> {
        let userId = Nat.toText(userData.id);
        
        // Check if user already exists
        switch (users.get(userId)) {
            case (?_) { #err("USER_ALREADY_EXISTS") };
            case (null) {
                // Check if phone number is already registered
                switch (phoneToUserId.get(userData.phone_number)) {
                    case (?_) { #err("PHONE_ALREADY_REGISTERED") };
                    case (null) {
                        users.put(userId, userData);
                        phoneToUserId.put(userData.phone_number, userId);
                        #ok(userData)
                    };
                }
            };
        }
    };
    
    /**
     * Get user by phone number (internal function)
     * 
     * @param phone - Phone number to search for
     * @returns User data if found
     */
    public query func getUserByPhone(phone: Text) : async ?User {
        switch (phoneToUserId.get(phone)) {
            case (null) { null };
            case (?userId) {
                users.get(userId)
            };
        }
    };
    
    /**
     * Delete user account (admin function)
     * 
     * @param userId - User ID to delete
     * @param jwtToken - JWT token for authentication
     * @returns Success result or error
     */
    public func deleteUser(userId: Text, jwtToken: Text) : async Result.Result<Bool, Text> {
        // Validate authentication
        switch (validateAuth(jwtToken)) {
            case (null) { #err("UNAUTHORIZED") };
            case (?authContext) {
                if (not authContext.isValid) {
                    return #err("UNAUTHORIZED");
                };
                
                // Only allow users to delete their own accounts
                if (not validateUserPermission(authContext.userId, userId)) {
                    return #err("FORBIDDEN");
                };
                
                // Get user to remove phone mapping
                switch (users.get(userId)) {
                    case (null) { #err("USER_NOT_FOUND") };
                    case (?user) {
                        users.delete(userId);
                        phoneToUserId.delete(user.phone_number);
                        #ok(true)
                    };
                }
            };
        }
    };
    
    /**
     * Get all users (admin function)
     * 
     * @returns Array of all users
     */
    public query func getAllUsers() : async [User] {
        var userArray: [User] = [];
        for ((userId, user) in users.entries()) {
            userArray := Array.append(userArray, [user]);
        };
        userArray
    };
    
    /**
     * Service health check
     */
    public query func health() : async {
        status: Text;
        totalUsers: Nat;
        timestamp: Int;
    } {
        {
            status = "ok";
            totalUsers = users.size();
            timestamp = Time.now();
        }
    };
}

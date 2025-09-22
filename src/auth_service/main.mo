/**
 * @fileoverview ChatterPay Authentication Service - JWT and session management
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
 * Authentication Service Canister
 * 
 * Handles JWT token validation, session management, and user authentication
 * for the ChatterPay ecosystem. This is a core security component.
 */
persistent actor AuthService {
    
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
    
    /** JWT Token payload structure */
    public type JWTPayload = {
        userId: Text;
        sessionId: Text;
        iat: Int; // Issued at
        exp: Int; // Expires at
    };
    
    /** Authentication result for login */
    public type AuthResult = {
        user: User;
        sessionId: Text;
        jwtToken: Text;
    };
    
    /** Authentication context for validated requests */
    public type AuthContext = {
        userId: Text;
        sessionId: Text;
        isValid: Bool;
    };
    
    /** Session information */
    public type Session = {
        id: Text;
        userId: Text;
        createdAt: Int;
        lastUsed: Int;
        expiresAt: Int;
        ipAddress: ?Text;
        userAgent: ?Text;
    };
    
    private var nextSessionId: Nat = 0;

    private transient var sessions = HashMap.HashMap<Text, Session>(0, Text.equal, Text.hash);
    private transient var userSessions = HashMap.HashMap<Text, [Text]>(0, Text.equal, Text.hash);
    
    // Constants
    private let SESSION_DURATION: Int = 24 * 60 * 60 * 1_000_000_000; // 24 hours in nanoseconds
    
    /**
     * Generate a unique session ID
     */
    private func generateSessionId() : Text {
        let id = "session_" # Nat.toText(nextSessionId) # "_" # Nat.toText(Int.abs(Time.now()));
        nextSessionId += 1;
        id
    };
    
    /**
     * Create a new session for a user
     */
    private func createSession(userId: Text) : Text {
        let sessionId = generateSessionId();
        let now = Time.now();
        
        let session: Session = {
            id = sessionId;
            userId = userId;
            createdAt = now;
            lastUsed = now;
            expiresAt = now + SESSION_DURATION;
            ipAddress = null;
            userAgent = null;
        };
        
        sessions.put(sessionId, session);
        
        // Add to user sessions
        switch (userSessions.get(userId)) {
            case (null) { 
                userSessions.put(userId, [sessionId]);
            };
            case (?existingSessions) {
                userSessions.put(userId, Array.append(existingSessions, [sessionId]));
            };
        };
        
        sessionId
    };
    
    /**
     * Generate a simple JWT token (mock implementation)
     */
    private func generateJWT(user: User, sessionId: Text) : Text {
        let now = Time.now();
        "jwt_" # Nat.toText(user.id) # "_" # sessionId # "_" # Nat.toText(Int.abs(now))
    };
    
    /**
     * Validate a JWT token (mock implementation)
     */
    private func validateJWT(token: Text) : ?AuthContext {
        // Simple validation - check if token starts with "jwt_"
        if (Text.startsWith(token, #text "jwt_")) {
            ?{
                userId = "1"; // Mock user ID
                sessionId = "mock_session";
                isValid = true;
            }
        } else {
            null
        }
    };
    
    /**
     * Get current authenticated user
     * 
     * Equivalent to: GET /api/v1/auth/me
     * Original Next.js implementation: Validates JWT and returns user data
     * 
     * @param jwtToken - JWT token from Authorization header or cookie
     * @returns User data if authenticated, error if not
     */
    public func getMe(jwtToken: Text) : async Result.Result<User, Text> {
        // Validate JWT token
        switch (validateJWT(jwtToken)) {
            case (null) { #err("JWT_INVALID") };
            case (?authContext) {
                if (not authContext.isValid) {
                    return #err("JWT_INVALID");
                };
                
                // Return mock user for now
                let user: User = {
                    id = 1;
                    name = ?"Mock User";
                    email = ?"user@example.com";
                    phone_number = "+1234567890";
                    photo = ?"https://example.com/photo.jpg";
                    wallet = "0x1234567890abcdef";
                    code = ?123456;
                };
                #ok(user)
            };
        }
    };
    
    /**
     * User logout - terminate session
     * 
     * Equivalent to: POST /api/v1/user/[id]/logout
     * Original Next.js implementation: Clears session and JWT cookie
     * 
     * @param userId - User ID from path parameter
     * @param jwtToken - JWT token for authentication
     * @returns Success result or error
     */
    public func logout(userId: Text, jwtToken: Text) : async Result.Result<Bool, Text> {
        // Validate JWT token
        switch (validateJWT(jwtToken)) {
            case (null) { #err("JWT_INVALID") };
            case (?authContext) {
                if (not authContext.isValid) {
                    return #err("JWT_INVALID");
                };
                
                // Verify user owns this session
                if (authContext.userId != userId) {
                    return #err("UNAUTHORIZED");
                };
                
                // Remove session
                sessions.delete(authContext.sessionId);
                
                // Remove from user sessions
                switch (userSessions.get(userId)) {
                    case (null) {};
                    case (?userSessionList) {
                        let filteredSessions = Array.filter<Text>(userSessionList, func(sessionId) {
                            sessionId != authContext.sessionId
                        });
                        if (filteredSessions.size() > 0) {
                            userSessions.put(userId, filteredSessions);
                        } else {
                            userSessions.delete(userId);
                        };
                    };
                };
                
                #ok(true)
            };
        }
    };
    
    /**
     * Login with phone and 2FA code
     * 
     * Equivalent to: POST /api/v1/auth/login
     * Original Next.js implementation: Validates reCAPTCHA, checks user, validates 2FA code
     * 
     * @param phone - Phone number (will be hashed)
     * @param code - 2FA verification code
     * @param recaptchaToken - reCAPTCHA token for bot protection
     * @returns Authentication result with user, session, and JWT
     */
    public func login(phone: Text, code: Text, recaptchaToken: Text) : async Result.Result<AuthResult, Text> {
        // Input validation
        if (phone == "" or code == "" or recaptchaToken == "") {
            return #err("INVALID_REQUEST_PARAMS");
        };
        
        // TODO: Validate reCAPTCHA via external_apis canister
        // TODO: Get user by phone from database_proxy canister
        // TODO: Validate 2FA code
        
        // For now, create a mock user for testing
        let user: User = {
            id = 1;
            name = ?"Test User";
            email = ?"test@example.com";
            phone_number = phone;
            photo = null;
            wallet = "0x1234567890abcdef";
            code = ?123456;
        };
        
        // Create session
        let sessionId = createSession(Nat.toText(user.id));
        
        // Generate JWT
        let jwtToken = generateJWT(user, sessionId);
        
        let authResult: AuthResult = {
            user = user;
            sessionId = sessionId;
            jwtToken = jwtToken;
        };
        
        #ok(authResult)
    };
    
    /**
     * Service health check
     */
    public query func health() : async {
        status: Text;
        activeSessions: Nat;
        totalUsers: Nat;
    } {
        {
            status = "ok";
            activeSessions = sessions.size();
            totalUsers = userSessions.size();
        }
    };
}
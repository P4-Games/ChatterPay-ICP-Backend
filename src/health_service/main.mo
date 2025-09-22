/**
 * @fileoverview ChatterPay Health Service - System health monitoring
 * @author ChatterPay Team
 * @version 1.0.0
 */

import Time "mo:base/Time";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Float "mo:base/Float";

/**
 * Health Service Canister
 * 
 * Provides system health monitoring endpoints for the ChatterPay ecosystem.
 * This is the simplest canister in our architecture and serves as the foundation
 * for other more complex services.
 */
persistent actor HealthService {
    
    /** Health status response type */
    public type HealthStatus = {
        status: Text;
        timestamp: Int;
        uptime: Int;
        canister: Text;
        version: Text;
    };
    
    /** Service startup timestamp */
    private let startTime: Int = Time.now();
    
    /** Service version */
    private let version: Text = "1.0.0";
    
    /** Canister identifier */
    private let canisterId: Text = "health_service";
    
    /**
     * Health Check Endpoint
     * 
     * Equivalent to: GET /api/v1/health
     * Original Next.js implementation: return NextResponse.json({ data: 'ok' })
     * 
     * @returns Health status information
     */
    public query func health() : async HealthStatus {
        let now = Time.now();
        let uptime = now - startTime;
        
        {
            status = "ok";
            timestamp = now;
            uptime = uptime;
            canister = canisterId;
            version = version;
        }
    };
    
    /**
     * Detailed Health Check
     * 
     * Extended health information for monitoring and debugging
     * 
     * @returns Detailed health metrics
     */
    public query func healthDetailed() : async {
        status: Text;
        timestamp: Int;
        uptime: Int;
        uptimeHours: Float;
        canister: Text;
        version: Text;
        memorySize: Nat;
    } {
        let now = Time.now();
        let uptime = now - startTime;
        // Convert nanoseconds to hours (1 hour = 3.6 * 10^12 nanoseconds)
        let uptimeHours = Float.fromInt(uptime) / 3_600_000_000_000.0;
        
        {
            status = "ok";
            timestamp = now;
            uptime = uptime;
            uptimeHours = uptimeHours;
            canister = canisterId;
            version = version;
            memorySize = 0; // TODO: Implement memory usage tracking
        }
    };
    
    /**
     * Service Information
     * 
     * Returns service metadata and capabilities
     * 
     * @returns Service information
     */
    public query func info() : async {
        name: Text;
        version: Text;
        canister: Text;
        endpoints: [Text];
        capabilities: [Text];
    } {
        {
            name = "ChatterPay Health Service";
            version = version;
            canister = canisterId;
            endpoints = [
                "health() -> HealthStatus",
                "healthDetailed() -> DetailedHealth", 
                "info() -> ServiceInfo"
            ];
            capabilities = [
                "Health monitoring",
                "Uptime tracking",
                "Service discovery"
            ];
        }
    };
}

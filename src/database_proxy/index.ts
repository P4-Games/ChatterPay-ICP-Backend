/**
 * @fileoverview ChatterPay Database Proxy Service - TypeScript/Azle Implementation
 * @author ChatterPay Team
 * @version 1.0.0
 */

import { 
    Canister, 
    query, 
    update, 
    Record, 
    text, 
    nat64, 
    bool,
    Variant,
    ic,
    Vec,
    CandidType,
    Opt
} from 'azle/experimental';

/**
 * Candid type definitions for Database Proxy Service
 */

/** Database connection configuration */
const DBConfig = Record({
    mongoUri: text,
    dbName: text,
    maxConnections: nat64,
    timeoutMs: nat64
});

/** Database query parameters */
const QueryParams = Record({
    collection: text,
    filter: text, // JSON string
    options: text, // JSON string (optional)
    limit: Opt(nat64)
});

/** Database document */
const DBDocument = Record({
    id: text,
    data: text, // JSON string
    collection: text,
    createdAt: nat64,
    updatedAt: nat64
});

/** Database operation result */
const DBOperation = Record({
    success: bool,
    affectedCount: nat64,
    data: Opt(text), // JSON string
    message: text
});

/** Connection status */
const ConnectionStatus = Record({
    connected: bool,
    activeConnections: nat64,
    lastPing: nat64,
    dbName: text
});

/** Generic Result type for operations that can succeed or fail */
const Result = <T extends CandidType>(type: T) => Variant({
    Ok: type,
    Err: text
});

/**
 * State Management
 */

/** Owner principal - will be set on first deployment */
let OWNER: string | null = null;

/** Database configuration */
let dbConfig: any = {
    mongoUri: "",
    dbName: "chatterpay",
    maxConnections: 10,
    timeoutMs: 30000
};

/** Connection status */
let connectionStatus = {
    connected: false,
    activeConnections: 0,
    lastPing: 0,
    dbName: ""
};

/** Query cache for optimization */
let queryCache = new Map<string, any>();
const QUERY_CACHE_TTL = 2 * 60 * 1000; // 2 minutes

/**
 * Helper Functions
 */

/**
 * Simulate MongoDB connection (placeholder)
 * In production, use proper MongoDB driver
 */
async function connectToMongoDB(): Promise<boolean> {
    try {
        // Placeholder for MongoDB connection
        // In production, use MongoDB driver for Node.js
        connectionStatus = {
            connected: true,
            activeConnections: 1,
            lastPing: Date.now(),
            dbName: dbConfig.dbName
        };
        return true;
    } catch (error) {
        connectionStatus.connected = false;
        return false;
    }
}

/**
 * Execute MongoDB query (placeholder)
 */
async function executeQuery(collection: string, operation: string, params: any): Promise<any> {
    try {
        // Placeholder for MongoDB operations
        // In production, use proper MongoDB queries
        return {
            success: true,
            data: [],
            affectedCount: 0
        };
    } catch (error) {
        throw new Error(`Query execution failed: ${error}`);
    }
}

/**
 * ChatterPay Database Proxy Service Canister
 * 
 * Provides centralized database access for all ChatterPay services,
 * handling MongoDB connections, queries, and data management.
 */
export default Canister({
    /**
     * Initialize the canister owner
     * Can only be called once when OWNER is null
     * @returns The owner principal ID or error message
     */
    initializeOwner: update([], Result(text), () => {
        if (OWNER !== null) {
            return { Err: "Owner already initialized" };
        }
        OWNER = ic.caller().toString();
        return { Ok: OWNER };
    }),

    /**
     * Get the current owner principal ID
     * @returns The owner principal ID or empty string if not set
     */
    getOwner: query([], text, () => OWNER || ""),

    /**
     * Update database configuration (owner only)
     * @param config - Database configuration
     * @returns Success boolean or error message
     */
    updateConfig: update([DBConfig], Result(bool), async (config: any) => {
        if (OWNER === null) {
            return { Err: "Owner not initialized" };
        }
        if (ic.caller().toString() !== OWNER) {
            return { Err: "Only owner can update configuration" };
        }

        dbConfig = {
            mongoUri: config.mongoUri || dbConfig.mongoUri,
            dbName: config.dbName || dbConfig.dbName,
            maxConnections: Number(config.maxConnections) || dbConfig.maxConnections,
            timeoutMs: Number(config.timeoutMs) || dbConfig.timeoutMs
        };

        // Attempt to reconnect with new config
        const connected = await connectToMongoDB();
        if (!connected) {
            return { Err: "Failed to connect with new configuration" };
        }

        return { Ok: true };
    }),

    /**
     * Get connection status
     * @returns Current database connection status
     */
    getConnectionStatus: query([], ConnectionStatus, () => {
        return {
            connected: connectionStatus.connected,
            activeConnections: BigInt(connectionStatus.activeConnections),
            lastPing: BigInt(connectionStatus.lastPing),
            dbName: connectionStatus.dbName || dbConfig.dbName
        };
    }),

    /**
     * Test database connection
     * @returns Connection test result
     */
    testConnection: update([], Result(bool), async () => {
        try {
            const connected = await connectToMongoDB();
            return { Ok: connected };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Connection test failed: ${message}` };
        }
    }),

    /**
     * Find documents in a collection
     * @param params - Query parameters
     * @returns Found documents or error
     */
    findDocuments: update([QueryParams], Result(Vec(DBDocument)), async (params: any) => {
        try {
            if (!connectionStatus.connected) {
                const connected = await connectToMongoDB();
                if (!connected) {
                    return { Err: "Database not connected" };
                }
            }

            const cacheKey = `find_${params.collection}_${params.filter}`;
            const cached = queryCache.get(cacheKey);
            
            // Return cached data if still valid
            if (cached && (Date.now() - cached.timestamp) < QUERY_CACHE_TTL) {
                return { Ok: cached.data };
            }

            const result = await executeQuery(params.collection, 'find', {
                filter: JSON.parse(params.filter),
                options: params.options ? JSON.parse(params.options) : {},
                limit: params.limit ? Number(params.limit) : 100
            });

            // Mock response for demo
            const mockDocuments = [
                {
                    id: "doc_001",
                    data: JSON.stringify({ name: "Sample Document", value: 123 }),
                    collection: params.collection,
                    createdAt: BigInt(Date.now() - 86400000), // 1 day ago
                    updatedAt: BigInt(Date.now())
                }
            ];

            // Cache the response
            queryCache.set(cacheKey, {
                data: mockDocuments,
                timestamp: Date.now()
            });

            return { Ok: mockDocuments };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Find operation failed: ${message}` };
        }
    }),

    /**
     * Insert a document into a collection
     * @param collection - Collection name
     * @param document - Document data (JSON string)
     * @returns Operation result
     */
    insertDocument: update([text, text], Result(DBOperation), async (collection: string, documentData: string) => {
        try {
            if (!connectionStatus.connected) {
                const connected = await connectToMongoDB();
                if (!connected) {
                    return { Err: "Database not connected" };
                }
            }

            // Validate JSON
            const parsedData = JSON.parse(documentData);
            
            const result = await executeQuery(collection, 'insertOne', {
                document: parsedData
            });

            // Clear related cache entries
            for (const [key] of queryCache.entries()) {
                if (key.includes(collection)) {
                    queryCache.delete(key);
                }
            }

            const operation = {
                success: true,
                affectedCount: BigInt(1),
                data: JSON.stringify({ insertedId: "new_doc_id_" + Date.now() }),
                message: "Document inserted successfully"
            };

            return { Ok: operation };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Insert operation failed: ${message}` };
        }
    }),

    /**
     * Update documents in a collection
     * @param collection - Collection name
     * @param filter - Filter criteria (JSON string)
     * @param update - Update operations (JSON string)
     * @returns Operation result
     */
    updateDocuments: update([text, text, text], Result(DBOperation), async (collection: string, filter: string, updateData: string) => {
        try {
            if (!connectionStatus.connected) {
                const connected = await connectToMongoDB();
                if (!connected) {
                    return { Err: "Database not connected" };
                }
            }

            // Validate JSON
            const parsedFilter = JSON.parse(filter);
            const parsedUpdate = JSON.parse(updateData);
            
            const result = await executeQuery(collection, 'updateMany', {
                filter: parsedFilter,
                update: parsedUpdate
            });

            // Clear related cache entries
            for (const [key] of queryCache.entries()) {
                if (key.includes(collection)) {
                    queryCache.delete(key);
                }
            }

            const operation = {
                success: true,
                affectedCount: BigInt(Math.floor(Math.random() * 5) + 1), // Mock affected count
                data: JSON.stringify({ modifiedCount: 1 }),
                message: "Documents updated successfully"
            };

            return { Ok: operation };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Update operation failed: ${message}` };
        }
    }),

    /**
     * Delete documents from a collection
     * @param collection - Collection name
     * @param filter - Filter criteria (JSON string)
     * @returns Operation result
     */
    deleteDocuments: update([text, text], Result(DBOperation), async (collection: string, filter: string) => {
        try {
            if (!connectionStatus.connected) {
                const connected = await connectToMongoDB();
                if (!connected) {
                    return { Err: "Database not connected" };
                }
            }

            // Validate JSON
            const parsedFilter = JSON.parse(filter);
            
            const result = await executeQuery(collection, 'deleteMany', {
                filter: parsedFilter
            });

            // Clear related cache entries
            for (const [key] of queryCache.entries()) {
                if (key.includes(collection)) {
                    queryCache.delete(key);
                }
            }

            const operation = {
                success: true,
                affectedCount: BigInt(Math.floor(Math.random() * 3) + 1), // Mock affected count
                data: JSON.stringify({ deletedCount: 1 }),
                message: "Documents deleted successfully"
            };

            return { Ok: operation };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Delete operation failed: ${message}` };
        }
    }),

    /**
     * Get collection statistics
     * @param collection - Collection name
     * @returns Collection statistics
     */
    getCollectionStats: update([text], Result(Record({
        name: text,
        documentCount: nat64,
        averageSize: nat64,
        totalSize: nat64,
        indexes: nat64
    })), async (collection: string) => {
        try {
            if (!connectionStatus.connected) {
                const connected = await connectToMongoDB();
                if (!connected) {
                    return { Err: "Database not connected" };
                }
            }

            const result = await executeQuery(collection, 'stats', {});

            // Mock statistics
            const stats = {
                name: collection,
                documentCount: BigInt(Math.floor(Math.random() * 10000) + 100),
                averageSize: BigInt(Math.floor(Math.random() * 1000) + 500),
                totalSize: BigInt(Math.floor(Math.random() * 1000000) + 50000),
                indexes: BigInt(Math.floor(Math.random() * 5) + 2)
            };

            return { Ok: stats };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Stats operation failed: ${message}` };
        }
    }),

    /**
     * Clear query cache (owner only)
     * @returns Success boolean or error
     */
    clearCache: update([], Result(bool), () => {
        if (OWNER === null) {
            return { Err: "Owner not initialized" };
        }
        if (ic.caller().toString() !== OWNER) {
            return { Err: "Only owner can clear cache" };
        }

        queryCache.clear();
        return { Ok: true };
    }),

    /**
     * Get cache statistics
     * @returns Cache statistics
     */
    getCacheStats: query([], Record({
        size: nat64,
        hitRate: text,
        timestamp: nat64
    }), () => {
        return {
            size: BigInt(queryCache.size),
            hitRate: "85%", // Mock hit rate
            timestamp: BigInt(Date.now())
        };
    }),

    /**
     * Service health check
     * @returns Health status
     */
    health: query([], Record({
        status: text,
        dbConnected: bool,
        cacheSize: nat64,
        activeConnections: nat64,
        timestamp: nat64
    }), () => {
        return {
            status: connectionStatus.connected ? "ok" : "degraded",
            dbConnected: connectionStatus.connected,
            cacheSize: BigInt(queryCache.size),
            activeConnections: BigInt(connectionStatus.activeConnections),
            timestamp: BigInt(Date.now())
        };
    })
});

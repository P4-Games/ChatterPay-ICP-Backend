/**
 * @fileoverview ChatterPay Analytics Service - TypeScript/Azle Implementation
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
    float64,
    Opt
} from 'azle/experimental';

/**
 * Candid type definitions for Analytics Service
 */

/** Analytics event */
const AnalyticsEvent = Record({
    id: text,
    userId: text,
    eventType: text,
    eventData: text, // JSON string
    chainId: Opt(nat64),
    timestamp: nat64,
    sessionId: Opt(text)
});

/** User analytics summary */
const UserAnalytics = Record({
    userId: text,
    totalTransactions: nat64,
    totalVolume: float64,
    averageTransactionValue: float64,
    favoriteChain: text,
    firstActivity: nat64,
    lastActivity: nat64,
    activeNetworks: Vec(text)
});

/** Platform analytics */
const PlatformAnalytics = Record({
    totalUsers: nat64,
    totalTransactions: nat64,
    totalVolume: float64,
    averageDailyUsers: nat64,
    topChains: Vec(text),
    growthRate: float64,
    timestamp: nat64
});

/** Notification data */
const NotificationData = Record({
    id: text,
    userId: text,
    title: text,
    body: text,
    type: text, // transaction, security, promotion, etc.
    data: text, // JSON string with additional data
    read: bool,
    createdAt: nat64,
    expiresAt: Opt(nat64)
});

/** Push notification request */
const PushNotificationRequest = Record({
    userIds: Vec(text),
    title: text,
    body: text,
    type: text,
    data: text,
    scheduleAt: Opt(nat64) // For scheduled notifications
});

/** Analytics query parameters */
const AnalyticsQuery = Record({
    userId: Opt(text),
    eventType: Opt(text),
    chainId: Opt(nat64),
    startDate: nat64,
    endDate: nat64,
    limit: Opt(nat64)
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

/** Analytics events storage */
let analyticsEvents = new Map<string, any>();

/** User notifications storage */
let userNotifications = new Map<string, any[]>();

/** Push Protocol configuration */
let pushConfig = {
    apiKey: "",
    channelAddress: "",
    environment: "staging" // staging or prod
};

/** Analytics cache */
let analyticsCache = new Map<string, any>();
const ANALYTICS_CACHE_TTL = 5 * 60 * 1000; // 5 minutes

/**
 * Helper Functions
 */

/**
 * Generate unique ID
 */
function generateId(): string {
    return `${Date.now()}_${Math.random().toString(36).substring(2)}`;
}

/**
 * Send push notification via Push Protocol
 */
async function sendPushNotification(userIds: string[], title: string, body: string, data: any): Promise<boolean> {
    try {
        // Placeholder for Push Protocol integration
        // In production, use @pushprotocol/restapi
        console.log(`Sending push notification to ${userIds.length} users: ${title}`);
        return true;
    } catch (error) {
        console.error("Push notification failed:", error);
        return false;
    }
}

/**
 * ChatterPay Analytics Service Canister
 * 
 * Provides comprehensive analytics, user tracking, and push notifications
 * for the ChatterPay ecosystem.
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
     * Update Push Protocol configuration (owner only)
     * @param apiKey - Push Protocol API key
     * @param channelAddress - Channel address
     * @param environment - Environment (staging/prod)
     * @returns Success boolean or error message
     */
    updatePushConfig: update([text, text, text], Result(bool), (apiKey: string, channelAddress: string, environment: string) => {
        if (OWNER === null) {
            return { Err: "Owner not initialized" };
        }
        if (ic.caller().toString() !== OWNER) {
            return { Err: "Only owner can update configuration" };
        }

        pushConfig = {
            apiKey,
            channelAddress,
            environment
        };

        return { Ok: true };
    }),

    /**
     * Track analytics event
     * @param event - Analytics event data
     * @returns Success boolean or error
     */
    trackEvent: update([AnalyticsEvent], Result(bool), (event: any) => {
        try {
            const eventId = event.id || generateId();
            const eventData = {
                id: eventId,
                userId: event.userId,
                eventType: event.eventType,
                eventData: event.eventData,
                chainId: event.chainId,
                timestamp: event.timestamp || BigInt(Date.now()),
                sessionId: event.sessionId
            };

            analyticsEvents.set(eventId, eventData);

            // Clear related cache entries
            for (const [key] of analyticsCache.entries()) {
                if (key.includes(event.userId) || key.includes(event.eventType)) {
                    analyticsCache.delete(key);
                }
            }

            return { Ok: true };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Event tracking failed: ${message}` };
        }
    }),

    /**
     * Query analytics events
     * @param query - Query parameters
     * @returns Matching events or error
     */
    queryEvents: update([AnalyticsQuery], Result(Vec(AnalyticsEvent)), (query: any) => {
        try {
            const events = Array.from(analyticsEvents.values());
            let filteredEvents = events;

            // Apply filters
            if (query.userId) {
                filteredEvents = filteredEvents.filter(e => e.userId === query.userId);
            }
            if (query.eventType) {
                filteredEvents = filteredEvents.filter(e => e.eventType === query.eventType);
            }
            if (query.chainId) {
                filteredEvents = filteredEvents.filter(e => e.chainId && Number(e.chainId) === Number(query.chainId));
            }

            // Apply date range
            filteredEvents = filteredEvents.filter(e => {
                const timestamp = Number(e.timestamp);
                return timestamp >= Number(query.startDate) && timestamp <= Number(query.endDate);
            });

            // Apply limit
            const limit = query.limit ? Number(query.limit) : 100;
            filteredEvents = filteredEvents.slice(0, limit);

            return { Ok: filteredEvents };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Event query failed: ${message}` };
        }
    }),

    /**
     * Get user analytics summary
     * @param userId - User ID
     * @returns User analytics or error
     */
    getUserAnalytics: update([text], Result(UserAnalytics), (userId: string) => {
        try {
            const cacheKey = `user_analytics_${userId}`;
            const cached = analyticsCache.get(cacheKey);
            
            // Return cached data if still valid
            if (cached && (Date.now() - cached.timestamp) < ANALYTICS_CACHE_TTL) {
                return { Ok: cached.data };
            }

            const userEvents = Array.from(analyticsEvents.values()).filter(e => e.userId === userId);
            const transactionEvents = userEvents.filter(e => e.eventType === 'transaction');
            
            // Calculate analytics
            const totalTransactions = transactionEvents.length;
            let totalVolume = 0;
            const chainCounts = new Map<string, number>();
            let firstActivity = Date.now();
            let lastActivity = 0;

            for (const event of userEvents) {
                const timestamp = Number(event.timestamp);
                if (timestamp < firstActivity) firstActivity = timestamp;
                if (timestamp > lastActivity) lastActivity = timestamp;

                if (event.eventType === 'transaction') {
                    try {
                        const data = JSON.parse(event.eventData);
                        totalVolume += parseFloat(data.value || 0);
                    } catch (e) {
                        // Skip invalid event data
                    }
                }

                if (event.chainId) {
                    const chainId = event.chainId.toString();
                    chainCounts.set(chainId, (chainCounts.get(chainId) || 0) + 1);
                }
            }

            // Find favorite chain
            let favoriteChain = "unknown";
            let maxCount = 0;
            for (const [chainId, count] of chainCounts.entries()) {
                if (count > maxCount) {
                    maxCount = count;
                    favoriteChain = chainId;
                }
            }

            const userAnalytics = {
                userId,
                totalTransactions: BigInt(totalTransactions),
                totalVolume,
                averageTransactionValue: totalTransactions > 0 ? totalVolume / totalTransactions : 0,
                favoriteChain,
                firstActivity: BigInt(firstActivity),
                lastActivity: BigInt(lastActivity),
                activeNetworks: Array.from(chainCounts.keys())
            };

            // Cache the response
            analyticsCache.set(cacheKey, {
                data: userAnalytics,
                timestamp: Date.now()
            });

            return { Ok: userAnalytics };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `User analytics failed: ${message}` };
        }
    }),

    /**
     * Get platform analytics
     * @returns Platform analytics or error
     */
    getPlatformAnalytics: update([], Result(PlatformAnalytics), () => {
        try {
            const cacheKey = "platform_analytics";
            const cached = analyticsCache.get(cacheKey);
            
            // Return cached data if still valid
            if (cached && (Date.now() - cached.timestamp) < ANALYTICS_CACHE_TTL) {
                return { Ok: cached.data };
            }

            const allEvents = Array.from(analyticsEvents.values());
            const uniqueUsers = new Set(allEvents.map(e => e.userId));
            const transactionEvents = allEvents.filter(e => e.eventType === 'transaction');
            
            let totalVolume = 0;
            const chainCounts = new Map<string, number>();

            for (const event of transactionEvents) {
                try {
                    const data = JSON.parse(event.eventData);
                    totalVolume += parseFloat(data.value || 0);
                } catch (e) {
                    // Skip invalid event data
                }

                if (event.chainId) {
                    const chainId = event.chainId.toString();
                    chainCounts.set(chainId, (chainCounts.get(chainId) || 0) + 1);
                }
            }

            // Get top chains
            const topChains = Array.from(chainCounts.entries())
                .sort((a, b) => b[1] - a[1])
                .slice(0, 5)
                .map(([chainId]) => chainId);

            const platformAnalytics = {
                totalUsers: BigInt(uniqueUsers.size),
                totalTransactions: BigInt(transactionEvents.length),
                totalVolume,
                averageDailyUsers: BigInt(Math.floor(uniqueUsers.size / 30)), // Rough estimate
                topChains,
                growthRate: 15.5, // Mock growth rate
                timestamp: BigInt(Date.now())
            };

            // Cache the response
            analyticsCache.set(cacheKey, {
                data: platformAnalytics,
                timestamp: Date.now()
            });

            return { Ok: platformAnalytics };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Platform analytics failed: ${message}` };
        }
    }),

    /**
     * Create notification for user
     * @param notification - Notification data
     * @returns Success boolean or error
     */
    createNotification: update([NotificationData], Result(text), (notification: any) => {
        try {
            const notificationId = notification.id || generateId();
            const notificationData = {
                id: notificationId,
                userId: notification.userId,
                title: notification.title,
                body: notification.body,
                type: notification.type,
                data: notification.data,
                read: false,
                createdAt: BigInt(Date.now()),
                expiresAt: notification.expiresAt
            };

            // Add to user notifications
            const userNotifs = userNotifications.get(notification.userId) || [];
            userNotifs.push(notificationData);
            userNotifications.set(notification.userId, userNotifs);

            return { Ok: notificationId };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Notification creation failed: ${message}` };
        }
    }),

    /**
     * Get user notifications
     * @param userId - User ID
     * @param unreadOnly - Return only unread notifications
     * @returns User notifications or error
     */
    getUserNotifications: query([text, bool], Result(Vec(NotificationData)), (userId: string, unreadOnly: boolean) => {
        try {
            const userNotifs = userNotifications.get(userId) || [];
            let filteredNotifs = userNotifs;

            if (unreadOnly) {
                filteredNotifs = userNotifs.filter(n => !n.read);
            }

            // Filter out expired notifications
            const now = Date.now();
            filteredNotifs = filteredNotifs.filter(n => {
                if (n.expiresAt && Number(n.expiresAt) < now) {
                    return false;
                }
                return true;
            });

            return { Ok: filteredNotifs };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Get notifications failed: ${message}` };
        }
    }),

    /**
     * Mark notification as read
     * @param userId - User ID
     * @param notificationId - Notification ID
     * @returns Success boolean or error
     */
    markNotificationRead: update([text, text], Result(bool), (userId: string, notificationId: string) => {
        try {
            const userNotifs = userNotifications.get(userId) || [];
            const notification = userNotifs.find(n => n.id === notificationId);
            
            if (!notification) {
                return { Err: "Notification not found" };
            }

            notification.read = true;
            userNotifications.set(userId, userNotifs);

            return { Ok: true };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Mark read failed: ${message}` };
        }
    }),

    /**
     * Send push notification
     * @param request - Push notification request
     * @returns Success boolean or error
     */
    sendPushNotification: update([PushNotificationRequest], Result(bool), async (request: any) => {
        try {
            if (!pushConfig.apiKey) {
                return { Err: "Push Protocol not configured" };
            }

            const success = await sendPushNotification(
                request.userIds,
                request.title,
                request.body,
                JSON.parse(request.data || "{}")
            );

            if (!success) {
                return { Err: "Push notification delivery failed" };
            }

            // Also create in-app notifications
            for (const userId of request.userIds) {
                const notification = {
                    id: generateId(),
                    userId,
                    title: request.title,
                    body: request.body,
                    type: request.type,
                    data: request.data,
                    read: false,
                    createdAt: BigInt(Date.now()),
                    expiresAt: null
                };

                const userNotifs = userNotifications.get(userId) || [];
                userNotifs.push(notification);
                userNotifications.set(userId, userNotifs);
            }

            return { Ok: true };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Push notification failed: ${message}` };
        }
    }),

    /**
     * Clear analytics cache (owner only)
     * @returns Success boolean or error
     */
    clearCache: update([], Result(bool), () => {
        if (OWNER === null) {
            return { Err: "Owner not initialized" };
        }
        if (ic.caller().toString() !== OWNER) {
            return { Err: "Only owner can clear cache" };
        }

        analyticsCache.clear();
        return { Ok: true };
    }),

    /**
     * Get service statistics
     * @returns Service statistics
     */
    getStats: query([], Record({
        totalEvents: nat64,
        totalUsers: nat64,
        totalNotifications: nat64,
        cacheSize: nat64,
        timestamp: nat64
    }), () => {
        const uniqueUsers = new Set(Array.from(analyticsEvents.values()).map(e => e.userId));
        let totalNotifications = 0;
        for (const notifs of userNotifications.values()) {
            totalNotifications += notifs.length;
        }

        return {
            totalEvents: BigInt(analyticsEvents.size),
            totalUsers: BigInt(uniqueUsers.size),
            totalNotifications: BigInt(totalNotifications),
            cacheSize: BigInt(analyticsCache.size),
            timestamp: BigInt(Date.now())
        };
    }),

    /**
     * Service health check
     * @returns Health status
     */
    health: query([], Record({
        status: text,
        pushConfigured: bool,
        eventsStored: nat64,
        timestamp: nat64
    }), () => {
        return {
            status: "ok",
            pushConfigured: !!pushConfig.apiKey,
            eventsStored: BigInt(analyticsEvents.size),
            timestamp: BigInt(Date.now())
        };
    })
});

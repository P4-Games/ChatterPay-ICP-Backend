/**
 * @fileoverview ChatterPay External APIs Service - TypeScript/Azle Implementation
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
    float64
} from 'azle/experimental';

/**
 * Candid type definitions for External APIs Service
 */

/** reCAPTCHA validation parameters */
const RecaptchaRequest = Record({
    token: text,
    ip: text
});

/** WhatsApp message parameters */
const WhatsAppRequest = Record({
    phone: text,
    code: text,
    message: text
});

/** Price request parameters */
const PriceRequest = Record({
    tokens: Vec(text),
    currency: text // USD, EUR, etc.
});

/** Token price data */
const TokenPrice = Record({
    symbol: text,
    name: text,
    price: float64,
    change24h: float64,
    lastUpdated: nat64
});

/** Price response */
const PriceResponse = Record({
    prices: Vec(TokenPrice),
    timestamp: nat64,
    source: text
});

/** API configuration */
const APIConfig = Record({
    recaptchaSecret: text,
    chatizaloApiKey: text,
    chatizaloUrl: text,
    coinGeckoApiKey: text,
    api3Endpoint: text
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

/** API Configuration */
let apiConfig: any = {
    recaptchaSecret: "",
    chatizaloApiKey: "",
    chatizaloUrl: "https://api.chatizalo.com/v1",
    coinGeckoApiKey: "",
    api3Endpoint: "https://api.api3.org/v1"
};

/** Price cache for optimization */
let priceCache = new Map<string, any>();
const PRICE_CACHE_TTL = 5 * 60 * 1000; // 5 minutes

/**
 * Helper Functions
 */

/**
 * Make HTTP request (simplified for demo)
 * In production, use proper HTTP client
 */
async function makeHttpRequest(url: string, options: any = {}): Promise<any> {
    try {
        // This is a placeholder - Azle doesn't have built-in HTTP client yet
        // In production, you would use a proper HTTP client library
        return { success: true, data: {}, status: 200 };
    } catch (error) {
        throw new Error(`HTTP request failed: ${error}`);
    }
}

/**
 * ChatterPay External APIs Service Canister
 * 
 * Provides external API integrations including reCAPTCHA validation,
 * WhatsApp messaging, and cryptocurrency price feeds.
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
     * Update API configuration (owner only)
     * @param config - API configuration object
     * @returns Success boolean or error message
     */
    updateConfig: update([APIConfig], Result(bool), async (config: any) => {
        if (OWNER === null) {
            return { Err: "Owner not initialized" };
        }
        if (ic.caller().toString() !== OWNER) {
            return { Err: "Only owner can update configuration" };
        }

        apiConfig = {
            recaptchaSecret: config.recaptchaSecret || apiConfig.recaptchaSecret,
            chatizaloApiKey: config.chatizaloApiKey || apiConfig.chatizaloApiKey,
            chatizaloUrl: config.chatizaloUrl || apiConfig.chatizaloUrl,
            coinGeckoApiKey: config.coinGeckoApiKey || apiConfig.coinGeckoApiKey,
            api3Endpoint: config.api3Endpoint || apiConfig.api3Endpoint
        };

        return { Ok: true };
    }),

    /**
     * Validate reCAPTCHA token
     * @param request - reCAPTCHA validation request
     * @returns Validation result or error
     */
    validateRecaptcha: update([RecaptchaRequest], Result(bool), async (request: any) => {
        try {
            if (!apiConfig.recaptchaSecret) {
                return { Err: "reCAPTCHA secret not configured" };
            }

            // Google reCAPTCHA API call
            const url = "https://www.google.com/recaptcha/api/siteverify";
            const params = new URLSearchParams({
                secret: apiConfig.recaptchaSecret,
                response: request.token,
                remoteip: request.ip
            });

            const response = await makeHttpRequest(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: params.toString()
            });

            // Mock response for demo - in production, parse actual response
            const isValid = response.success && Math.random() > 0.1; // 90% success rate for demo
            
            return { Ok: isValid };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `reCAPTCHA validation failed: ${message}` };
        }
    }),

    /**
     * Send WhatsApp message via Chatizalo API
     * @param request - WhatsApp message request
     * @returns Success boolean or error
     */
    sendWhatsAppMessage: update([WhatsAppRequest], Result(bool), async (request: any) => {
        try {
            if (!apiConfig.chatizaloApiKey) {
                return { Err: "Chatizalo API key not configured" };
            }

            // Format phone number (remove non-digits and ensure international format)
            const cleanPhone = request.phone.replace(/\D/g, '');
            const formattedPhone = cleanPhone.startsWith('52') ? cleanPhone : `52${cleanPhone}`;

            // Chatizalo API call
            const url = `${apiConfig.chatizaloUrl}/messages`;
            const payload = {
                phone: formattedPhone,
                message: request.message.replace('{CODE}', request.code),
                type: 'text'
            };

            const response = await makeHttpRequest(url, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${apiConfig.chatizaloApiKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(payload)
            });

            // Mock response for demo
            const success = response.success && Math.random() > 0.05; // 95% success rate for demo
            
            return { Ok: success };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `WhatsApp message failed: ${message}` };
        }
    }),

    /**
     * Get cryptocurrency prices from CoinGecko
     * @param request - Price request with token symbols
     * @returns Price data or error
     */
    getCoinGeckoPrices: update([PriceRequest], Result(PriceResponse), async (request: any) => {
        try {
            const cacheKey = `coingecko_${request.tokens.join(',')}_${request.currency}`;
            const cached = priceCache.get(cacheKey);
            
            // Return cached data if still valid
            if (cached && (Date.now() - cached.timestamp) < PRICE_CACHE_TTL) {
                return { Ok: cached.data };
            }

            // CoinGecko API call
            const tokenIds = request.tokens.join(',');
            const url = `https://api.coingecko.com/api/v3/simple/price?ids=${tokenIds}&vs_currencies=${request.currency}&include_24hr_change=true`;
            
            const headers: any = {
                'Accept': 'application/json'
            };
            
            if (apiConfig.coinGeckoApiKey) {
                headers['X-CG-Demo-API-Key'] = apiConfig.coinGeckoApiKey;
            }

            const response = await makeHttpRequest(url, {
                method: 'GET',
                headers
            });

            // Mock response for demo
            const mockPrices = request.tokens.map((token: string, index: number) => ({
                symbol: token.toUpperCase(),
                name: `${token.charAt(0).toUpperCase() + token.slice(1)} Token`,
                price: 1000 + (Math.random() * 9000), // Random price between 1000-10000
                change24h: (Math.random() - 0.5) * 20, // Random change between -10% and +10%
                lastUpdated: BigInt(Date.now())
            }));

            const priceResponse = {
                prices: mockPrices,
                timestamp: BigInt(Date.now()),
                source: "coingecko"
            };

            // Cache the response
            priceCache.set(cacheKey, {
                data: priceResponse,
                timestamp: Date.now()
            });

            return { Ok: priceResponse };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `CoinGecko price fetch failed: ${message}` };
        }
    }),

    /**
     * Get prices from API3 oracle feeds
     * @param request - Price request with feed addresses
     * @returns Price data or error
     */
    getAPI3Prices: update([PriceRequest], Result(PriceResponse), async (request: any) => {
        try {
            const cacheKey = `api3_${request.tokens.join(',')}_${request.currency}`;
            const cached = priceCache.get(cacheKey);
            
            // Return cached data if still valid
            if (cached && (Date.now() - cached.timestamp) < PRICE_CACHE_TTL) {
                return { Ok: cached.data };
            }

            // API3 oracle feeds call
            const url = `${apiConfig.api3Endpoint}/feeds`;
            
            const response = await makeHttpRequest(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    feeds: request.tokens,
                    currency: request.currency
                })
            });

            // Mock response for demo
            const mockPrices = request.tokens.map((token: string, index: number) => ({
                symbol: token.toUpperCase(),
                name: `${token.charAt(0).toUpperCase() + token.slice(1)} Oracle`,
                price: 800 + (Math.random() * 9200), // Random price between 800-10000
                change24h: (Math.random() - 0.5) * 15, // Random change between -7.5% and +7.5%
                lastUpdated: BigInt(Date.now())
            }));

            const priceResponse = {
                prices: mockPrices,
                timestamp: BigInt(Date.now()),
                source: "api3"
            };

            // Cache the response
            priceCache.set(cacheKey, {
                data: priceResponse,
                timestamp: Date.now()
            });

            return { Ok: priceResponse };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `API3 price fetch failed: ${message}` };
        }
    }),

    /**
     * Clear price cache (owner only)
     * @returns Success boolean or error
     */
    clearPriceCache: update([], Result(bool), () => {
        if (OWNER === null) {
            return { Err: "Owner not initialized" };
        }
        if (ic.caller().toString() !== OWNER) {
            return { Err: "Only owner can clear cache" };
        }

        priceCache.clear();
        return { Ok: true };
    }),

    /**
     * Get cache statistics
     * @returns Cache statistics
     */
    getCacheStats: query([], Record({
        size: nat64,
        timestamp: nat64
    }), () => {
        return {
            size: BigInt(priceCache.size),
            timestamp: BigInt(Date.now())
        };
    }),

    /**
     * Test API connectivity
     * @returns Connectivity test results
     */
    testConnectivity: update([], Record({
        recaptcha: bool,
        whatsapp: bool,
        coingecko: bool,
        api3: bool,
        timestamp: nat64
    }), async () => {
        const results = {
            recaptcha: !!apiConfig.recaptchaSecret,
            whatsapp: !!apiConfig.chatizaloApiKey,
            coingecko: true, // CoinGecko has free tier
            api3: !!apiConfig.api3Endpoint,
            timestamp: BigInt(Date.now())
        };

        return results;
    }),

    /**
     * Service health check
     * @returns Health status
     */
    health: query([], Record({
        status: text,
        configuredAPIs: nat64,
        cacheSize: nat64,
        timestamp: nat64
    }), () => {
        let configuredCount = 0;
        if (apiConfig.recaptchaSecret) configuredCount++;
        if (apiConfig.chatizaloApiKey) configuredCount++;
        if (apiConfig.coinGeckoApiKey) configuredCount++;
        if (apiConfig.api3Endpoint) configuredCount++;

        return {
            status: "ok",
            configuredAPIs: BigInt(configuredCount),
            cacheSize: BigInt(priceCache.size),
            timestamp: BigInt(Date.now())
        };
    })
});

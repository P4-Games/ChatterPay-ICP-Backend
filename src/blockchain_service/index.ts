/**
 * @fileoverview ChatterPay Blockchain Service - TypeScript/Azle Implementation
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
 * Candid type definitions for Blockchain Service
 */

/** Blockchain network configuration */
const NetworkConfig = Record({
    chainId: nat64,
    name: text,
    rpcUrl: text,
    explorerUrl: text,
    nativeCurrency: text,
    enabled: bool
});

/** Token balance information */
const TokenBalance = Record({
    symbol: text,
    name: text,
    address: text,
    balance: text, // String to handle large numbers
    decimals: nat64,
    price: float64,
    value: float64 // USD value
});

/** Wallet balance summary */
const WalletBalance = Record({
    address: text,
    chainId: nat64,
    nativeBalance: text,
    nativeValue: float64,
    tokens: Vec(TokenBalance),
    totalValue: float64,
    lastUpdated: nat64
});

/** Transaction data */
const TransactionData = Record({
    hash: text,
    from: text,
    to: text,
    value: text,
    gasUsed: text,
    gasPrice: text,
    status: text,
    blockNumber: nat64,
    timestamp: nat64,
    chainId: nat64
});

/** Transfer request */
const TransferRequest = Record({
    from: text,
    to: text,
    amount: text,
    tokenAddress: Opt(text), // None for native currency
    chainId: nat64,
    gasLimit: Opt(text),
    gasPrice: Opt(text)
});

/** Transfer result */
const TransferResult = Record({
    success: bool,
    txHash: text,
    gasUsed: text,
    effectiveGasPrice: text,
    message: text
});

/** Gas estimation */
const GasEstimate = Record({
    gasLimit: text,
    gasPrice: text,
    maxFeePerGas: text,
    maxPriorityFeePerGas: text,
    estimatedCost: text,
    chainId: nat64
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

/** Supported networks */
let networks = new Map<string, any>();

/** Balance cache */
let balanceCache = new Map<string, any>();
const BALANCE_CACHE_TTL = 30 * 1000; // 30 seconds

/** Transaction cache */
let transactionCache = new Map<string, any>();
const TX_CACHE_TTL = 60 * 1000; // 1 minute

/**
 * Helper Functions
 */

/**
 * Initialize default networks
 */
function initializeDefaultNetworks() {
    const defaultNetworks = [
        {
            chainId: 1,
            name: "Ethereum Mainnet",
            rpcUrl: "https://ethereum.publicnode.com",
            explorerUrl: "https://etherscan.io",
            nativeCurrency: "ETH",
            enabled: true
        },
        {
            chainId: 137,
            name: "Polygon",
            rpcUrl: "https://polygon-rpc.com",
            explorerUrl: "https://polygonscan.com",
            nativeCurrency: "MATIC",
            enabled: true
        },
        {
            chainId: 42161,
            name: "Arbitrum One",
            rpcUrl: "https://arb1.arbitrum.io/rpc",
            explorerUrl: "https://arbiscan.io",
            nativeCurrency: "ETH",
            enabled: true
        },
        {
            chainId: 534352,
            name: "Scroll",
            rpcUrl: "https://rpc.scroll.io",
            explorerUrl: "https://scrollscan.com",
            nativeCurrency: "ETH",
            enabled: true
        }
    ];

    for (const network of defaultNetworks) {
        networks.set(network.chainId.toString(), network);
    }
}

/**
 * Simulate blockchain RPC call
 */
async function makeRPCCall(chainId: number, method: string, params: any[]): Promise<any> {
    try {
        // Placeholder for actual RPC calls
        // In production, use ethers.js or similar library
        return {
            success: true,
            data: {},
            chainId
        };
    } catch (error) {
        throw new Error(`RPC call failed: ${error}`);
    }
}

/**
 * ChatterPay Blockchain Service Canister
 * 
 * Provides comprehensive blockchain integration including wallet balances,
 * token transfers, transaction history, and multi-chain support.
 */
export default Canister({
    /**
     * Initialize the canister owner and default networks
     * Can only be called once when OWNER is null
     * @returns The owner principal ID or error message
     */
    initializeOwner: update([], Result(text), () => {
        if (OWNER !== null) {
            return { Err: "Owner already initialized" };
        }
        OWNER = ic.caller().toString();
        initializeDefaultNetworks();
        return { Ok: OWNER };
    }),

    /**
     * Get the current owner principal ID
     * @returns The owner principal ID or empty string if not set
     */
    getOwner: query([], text, () => OWNER || ""),

    /**
     * Add or update a network configuration (owner only)
     * @param config - Network configuration
     * @returns Success boolean or error message
     */
    updateNetwork: update([NetworkConfig], Result(bool), (config: any) => {
        if (OWNER === null) {
            return { Err: "Owner not initialized" };
        }
        if (ic.caller().toString() !== OWNER) {
            return { Err: "Only owner can update networks" };
        }

        networks.set(config.chainId.toString(), {
            chainId: Number(config.chainId),
            name: config.name,
            rpcUrl: config.rpcUrl,
            explorerUrl: config.explorerUrl,
            nativeCurrency: config.nativeCurrency,
            enabled: config.enabled
        });

        return { Ok: true };
    }),

    /**
     * Get all supported networks
     * @returns List of network configurations
     */
    getSupportedNetworks: query([], Vec(NetworkConfig), () => {
        const networkList = [];
        for (const [chainId, config] of networks.entries()) {
            networkList.push({
                chainId: BigInt(config.chainId),
                name: config.name,
                rpcUrl: config.rpcUrl,
                explorerUrl: config.explorerUrl,
                nativeCurrency: config.nativeCurrency,
                enabled: config.enabled
            });
        }
        return networkList;
    }),

    /**
     * Get wallet balance for a specific chain
     * @param address - Wallet address
     * @param chainId - Chain ID
     * @returns Wallet balance information or error
     */
    getWalletBalance: update([text, nat64], Result(WalletBalance), async (address: string, chainId: bigint) => {
        try {
            const chainIdStr = chainId.toString();
            const network = networks.get(chainIdStr);
            
            if (!network) {
                return { Err: "Unsupported network" };
            }

            const cacheKey = `balance_${address}_${chainIdStr}`;
            const cached = balanceCache.get(cacheKey);
            
            // Return cached data if still valid
            if (cached && (Date.now() - cached.timestamp) < BALANCE_CACHE_TTL) {
                return { Ok: cached.data };
            }

            // Make RPC calls to get balance
            const nativeBalance = await makeRPCCall(Number(chainId), 'eth_getBalance', [address, 'latest']);
            
            // Mock token balances
            const mockTokens = [
                {
                    symbol: "USDC",
                    name: "USD Coin",
                    address: "0xa0b86a33e6441c8c1c1b3c8c1d3c9c8c1c1c1c1c",
                    balance: "1000000000", // 1000 USDC (6 decimals)
                    decimals: BigInt(6),
                    price: 1.0,
                    value: 1000.0
                },
                {
                    symbol: "WETH",
                    name: "Wrapped Ether",
                    address: "0xc0b86a33e6441c8c1c1b3c8c1d3c9c8c1c1c1c1c",
                    balance: "2000000000000000000", // 2 WETH (18 decimals)
                    decimals: BigInt(18),
                    price: 2000.0,
                    value: 4000.0
                }
            ];

            const walletBalance = {
                address,
                chainId: BigInt(chainId),
                nativeBalance: "5000000000000000000", // 5 ETH
                nativeValue: 10000.0, // 5 ETH * $2000
                tokens: mockTokens,
                totalValue: 15000.0, // 10000 + 1000 + 4000
                lastUpdated: BigInt(Date.now())
            };

            // Cache the response
            balanceCache.set(cacheKey, {
                data: walletBalance,
                timestamp: Date.now()
            });

            return { Ok: walletBalance };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Balance fetch failed: ${message}` };
        }
    }),

    /**
     * Get wallet transactions
     * @param address - Wallet address
     * @param chainId - Chain ID
     * @param limit - Maximum number of transactions
     * @returns Transaction history or error
     */
    getWalletTransactions: update([text, nat64, Opt(nat64)], Result(Vec(TransactionData)), async (address: string, chainId: bigint, limit?: bigint) => {
        try {
            const chainIdStr = chainId.toString();
            const network = networks.get(chainIdStr);
            
            if (!network) {
                return { Err: "Unsupported network" };
            }

            const txLimit = limit ? Number(limit) : 50;
            const cacheKey = `tx_${address}_${chainIdStr}_${txLimit}`;
            const cached = transactionCache.get(cacheKey);
            
            // Return cached data if still valid
            if (cached && (Date.now() - cached.timestamp) < TX_CACHE_TTL) {
                return { Ok: cached.data };
            }

            // Mock transaction data
            const mockTransactions = [];
            for (let i = 0; i < Math.min(txLimit, 10); i++) {
                mockTransactions.push({
                    hash: `0x${Math.random().toString(16).substring(2).padStart(64, '0')}`,
                    from: i % 2 === 0 ? address : `0x${'1'.repeat(40)}`,
                    to: i % 2 === 0 ? `0x${'2'.repeat(40)}` : address,
                    value: (Math.random() * 10).toFixed(18),
                    gasUsed: "21000",
                    gasPrice: "20000000000",
                    status: "success",
                    blockNumber: BigInt(18000000 + i),
                    timestamp: BigInt(Date.now() - (i * 3600000)), // 1 hour apart
                    chainId: BigInt(chainId)
                });
            }

            // Cache the response
            transactionCache.set(cacheKey, {
                data: mockTransactions,
                timestamp: Date.now()
            });

            return { Ok: mockTransactions };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Transaction fetch failed: ${message}` };
        }
    }),

    /**
     * Transfer tokens or native currency
     * @param request - Transfer request parameters
     * @returns Transfer result or error
     */
    transferTokens: update([TransferRequest], Result(TransferResult), async (request: any) => {
        try {
            const chainIdStr = request.chainId.toString();
            const network = networks.get(chainIdStr);
            
            if (!network) {
                return { Err: "Unsupported network" };
            }

            // Validate addresses
            if (!request.from.match(/^0x[a-fA-F0-9]{40}$/) || !request.to.match(/^0x[a-fA-F0-9]{40}$/)) {
                return { Err: "Invalid address format" };
            }

            // For demo purposes, simulate a successful transfer
            // In production, this would use ethers.js to send actual transactions
            const mockTxHash = `0x${Math.random().toString(16).substring(2).padStart(64, '0')}`;
            
            const transferResult = {
                success: true,
                txHash: mockTxHash,
                gasUsed: "21000",
                effectiveGasPrice: "20000000000",
                message: "Transfer completed successfully"
            };

            // Clear balance cache for affected addresses
            for (const [key] of balanceCache.entries()) {
                if (key.includes(request.from) || key.includes(request.to)) {
                    balanceCache.delete(key);
                }
            }

            return { Ok: transferResult };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Transfer failed: ${message}` };
        }
    }),

    /**
     * Estimate gas for a transaction
     * @param request - Transfer request (for estimation)
     * @returns Gas estimation or error
     */
    estimateGas: update([TransferRequest], Result(GasEstimate), async (request: any) => {
        try {
            const chainIdStr = request.chainId.toString();
            const network = networks.get(chainIdStr);
            
            if (!network) {
                return { Err: "Unsupported network" };
            }

            // Mock gas estimation
            const baseGasLimit = request.tokenAddress ? "65000" : "21000"; // Higher for token transfers
            const gasPrice = "20000000000"; // 20 gwei
            const maxFeePerGas = "25000000000"; // 25 gwei
            const maxPriorityFeePerGas = "2000000000"; // 2 gwei
            
            const estimatedCost = (BigInt(baseGasLimit) * BigInt(gasPrice)).toString();

            const gasEstimate = {
                gasLimit: baseGasLimit,
                gasPrice,
                maxFeePerGas,
                maxPriorityFeePerGas,
                estimatedCost,
                chainId: BigInt(request.chainId)
            };

            return { Ok: gasEstimate };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Gas estimation failed: ${message}` };
        }
    }),

    /**
     * Get transaction by hash
     * @param txHash - Transaction hash
     * @param chainId - Chain ID
     * @returns Transaction data or error
     */
    getTransaction: update([text, nat64], Result(TransactionData), async (txHash: string, chainId: bigint) => {
        try {
            const chainIdStr = chainId.toString();
            const network = networks.get(chainIdStr);
            
            if (!network) {
                return { Err: "Unsupported network" };
            }

            // Mock transaction data
            const transaction = {
                hash: txHash,
                from: `0x${'1'.repeat(40)}`,
                to: `0x${'2'.repeat(40)}`,
                value: "1000000000000000000", // 1 ETH
                gasUsed: "21000",
                gasPrice: "20000000000",
                status: "success",
                blockNumber: BigInt(18000000),
                timestamp: BigInt(Date.now() - 3600000), // 1 hour ago
                chainId: BigInt(chainId)
            };

            return { Ok: transaction };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Transaction fetch failed: ${message}` };
        }
    }),

    /**
     * Clear all caches (owner only)
     * @returns Success boolean or error
     */
    clearCaches: update([], Result(bool), () => {
        if (OWNER === null) {
            return { Err: "Owner not initialized" };
        }
        if (ic.caller().toString() !== OWNER) {
            return { Err: "Only owner can clear caches" };
        }

        balanceCache.clear();
        transactionCache.clear();
        return { Ok: true };
    }),

    /**
     * Get service statistics
     * @returns Service statistics
     */
    getStats: query([], Record({
        supportedNetworks: nat64,
        balanceCacheSize: nat64,
        transactionCacheSize: nat64,
        timestamp: nat64
    }), () => {
        return {
            supportedNetworks: BigInt(networks.size),
            balanceCacheSize: BigInt(balanceCache.size),
            transactionCacheSize: BigInt(transactionCache.size),
            timestamp: BigInt(Date.now())
        };
    }),

    /**
     * Service health check
     * @returns Health status
     */
    health: query([], Record({
        status: text,
        networksConfigured: nat64,
        cacheHealth: text,
        timestamp: nat64
    }), () => {
        const enabledNetworks = Array.from(networks.values()).filter(n => n.enabled).length;
        
        return {
            status: enabledNetworks > 0 ? "ok" : "degraded",
            networksConfigured: BigInt(enabledNetworks),
            cacheHealth: "optimal",
            timestamp: BigInt(Date.now())
        };
    })
});

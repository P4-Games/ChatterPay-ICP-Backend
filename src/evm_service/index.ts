/**
 * @fileoverview ChatterPay EVM Service - Unified contract management and blockchain interaction
 * @author ChatterPay Team
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
    CandidType
} from 'azle/experimental';
import { ethers, JsonRpcProvider, Wallet } from 'ethers';
import type { TransactionReceipt, TransactionResponse } from 'ethers';

/**
 * RPC endpoint configurations from environment variables
 */
const ARBITRUM_SEPOLIA_RPC = process.env.ARBITRUM_SEPOLIA_RPC || "https://sepolia-rollup.arbitrum.io/rpc";
const POLYGON_RPC = process.env.POLYGON_RPC || "https://polygon-rpc.com";
const BSC_RPC = process.env.BSC_RPC || "https://bsc-dataseed.binance.org";
const ETHEREUM_RPC = process.env.ETHEREUM_RPC || "https://ethereum.publicnode.com";
const SCROLL_RPC = process.env.SCROLL_RPC || "https://rpc.scroll.io";
const SCROLL_SEPOLIA_RPC = process.env.SCROLL_SEPOLIA_RPC || "https://sepolia-rpc.scroll.io";

/**
 * Supported blockchain configurations
 * Maps chain ID to network name and RPC endpoint
 */
const CHAIN_CONFIGS = {
    421614: { name: "Arbitrum Sepolia", rpc: ARBITRUM_SEPOLIA_RPC },
    137: { name: "Polygon", rpc: POLYGON_RPC },
    56: { name: "BSC", rpc: BSC_RPC },
    1: { name: "Ethereum", rpc: ETHEREUM_RPC },
    534352: { name: "Scroll", rpc: SCROLL_RPC },
    534351: { name: "Scroll Sepolia", rpc: SCROLL_SEPOLIA_RPC }
} as const;

/** Default chain ID if not specified */
const DEFAULT_CHAIN_ID = Number(process.env.CHAIN_ID || "421614");

/** Map of initialized JsonRpcProvider instances by chain ID */
const providers = new Map<number, JsonRpcProvider>();
for (const [chainId, config] of Object.entries(CHAIN_CONFIGS)) {
    providers.set(Number(chainId), new JsonRpcProvider(config.rpc));
}

/**
 * Get JsonRpcProvider for a specific chain
 * @param chainId - The chain ID to get provider for. Defaults to DEFAULT_CHAIN_ID
 * @returns The JsonRpcProvider instance for the specified chain
 * @throws Error if chain ID is not supported
 */
function getProvider(chainId?: number): JsonRpcProvider {
    const id = chainId || DEFAULT_CHAIN_ID;
    const provider = providers.get(id);
    if (!provider) {
        throw new Error(`Unsupported chain ID: ${id}`);
    }
    return provider;
}

/**
 * Candid type definitions for ICP canister interface
 */

/** Parameters for pre-signed transaction operations */
const SignedTransferParams = Record({
    to: text,
    from: text,
    amount: text,
    signedTransaction: text, // Pre-signed transaction hex
    chainId: nat64
});

/** Parameters for gas estimation */
const GasEstimateParams = Record({
    to: text,
    from: text,
    amount: text,
    chainId: nat64
});

/** Result of gas estimation containing fee data */
const GasEstimateResult = Record({
    gasLimit: text,
    gasPrice: text,
    maxFeePerGas: text,
    maxPriorityFeePerGas: text,
    estimatedCost: text
});

/** Information about a supported blockchain */
const ChainInfo = Record({
    chainId: nat64,
    name: text,
    supported: bool
});

/** Result of a successful transfer operation */
const TransferResult = Record({
    txHash: text,
    status: text,
    gasUsed: text,
    effectiveGasPrice: text
});

/** Status information for a transaction */
const TransactionStatusResult = Record({
    status: text,
    confirmations: nat64,
    gasUsed: text,
    effectiveGasPrice: text
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

/** ChatterPay contract addresses by network ID */
let chatterPayContracts: { [networkId: number]: {
    factory?: string;
    implementation?: string;
    nft?: string;
    paymaster?: string;
    entryPoint?: string;
}} = {
    // Scroll Mainnet
    534352: {
        factory: "",
        implementation: "",
        nft: "",
        paymaster: "",
        entryPoint: ""
    },
    // Scroll Sepolia  
    534351: {
        factory: "",
        implementation: "",
        nft: "",
        paymaster: "",
        entryPoint: ""
    }
    // Can add any network: Ethereum, Polygon, Arbitrum, etc.
};

/** Contract ABIs by contract type */
let contractABIs: { [contractType: string]: string } = {
    factory: "",
    implementation: "",
    nft: "",
    paymaster: "",
    entryPoint: ""
};

/**
 * ChatterPay EVM Service Canister
 * 
 * Provides unified contract management and blockchain interaction capabilities
 * for the ChatterPay ecosystem across multiple EVM-compatible networks.
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
     * Transfer ownership to a new principal
     * @param newOwner - The new owner's principal ID
     * @returns Success boolean or error message
     */
    setOwner: update([text], Result(bool), (newOwner: string) => {
        if (OWNER === null) {
            return { Err: "Owner not initialized. Call initializeOwner first." };
        }
        if (ic.caller().toString() !== OWNER) {
            return { Err: "Only current owner can transfer ownership" };
        }
        OWNER = newOwner;
        return { Ok: true };
    }),

    /**
     * Get the current owner principal ID
     * @returns The owner principal ID or empty string if not set
     */
    getOwner: query([], text, () => OWNER || ""),

    /**
     * Update contract addresses for a specific network
     * Only the owner can perform this operation
     * @param networkId - The network ID (e.g., 534352 for Scroll)
     * @param contracts - Object containing contract addresses
     * @returns Success boolean or error message
     */
    updateNetworkContracts: update([nat64, Record({
        factory: text,
        implementation: text,
        nft: text,
        paymaster: text,
        entryPoint: text
    })], Result(bool), (networkId: bigint, contracts: any) => {
        if (OWNER === null) {
            return { Err: "Owner not initialized" };
        }
        if (ic.caller().toString() !== OWNER) {
            return { Err: "Only owner can update contracts" };
        }
        
        chatterPayContracts[Number(networkId)] = {
            factory: contracts.factory || undefined,
            implementation: contracts.implementation || undefined,
            nft: contracts.nft || undefined,
            paymaster: contracts.paymaster || undefined,
            entryPoint: contracts.entryPoint || undefined
        };
        return { Ok: true };
    }),

    /**
     * Update contract ABIs for all contract types
     * Only the owner can perform this operation
     * @param abis - Object containing ABI JSON strings for each contract type
     * @returns Success boolean or error message
     */
    updateABIs: update([Record({
        factory: text,
        implementation: text,
        nft: text,
        paymaster: text,
        entryPoint: text
    })], Result(bool), (abis: any) => {
        if (OWNER === null) {
            return { Err: "Owner not initialized" };
        }
        if (ic.caller().toString() !== OWNER) {
            return { Err: "Only owner can update ABIs" };
        }
        
        contractABIs.factory = abis.factory;
        contractABIs.implementation = abis.implementation;
        contractABIs.nft = abis.nft;
        contractABIs.paymaster = abis.paymaster;
        contractABIs.entryPoint = abis.entryPoint;
        return { Ok: true };
    }),

    /**
     * Get contract addresses for a specific network
     * @param networkId - The network ID to get contracts for
     * @returns Object containing contract addresses for the network
     */
    getNetworkContracts: query([nat64], Record({
        factory: text,
        implementation: text,
        nft: text,
        paymaster: text,
        entryPoint: text
    }), (networkId: bigint) => {
        const contracts = chatterPayContracts[Number(networkId)] || {};
        return {
            factory: contracts.factory || "",
            implementation: contracts.implementation || "",
            nft: contracts.nft || "",
            paymaster: contracts.paymaster || "",
            entryPoint: contracts.entryPoint || ""
        };
    }),

    /**
     * Get all supported network IDs
     * @returns Array of network IDs that have been configured
     */
    getSupportedNetworks: query([], text, () => {
        return JSON.stringify(Object.keys(chatterPayContracts).map(id => BigInt(id)));
    }),

    /**
     * Create a new user wallet using the factory contract
     * @param networkId - The network ID where the wallet should be created
     * @param userHash - Unique hash identifier for the user
     * @param salt - Random salt for wallet address generation
     * @returns The predicted wallet address or error message
     */
    createUserWallet: update([nat64, text, text], Result(text), async (networkId: bigint, userHash: string, salt: string) => {
        try {
            const contracts = chatterPayContracts[Number(networkId)];
            if (!contracts?.factory) {
                return { Err: "Factory contract not configured for this network" };
            }

            const provider = getProvider(Number(networkId));
            const factoryABI = contractABIs.factory;
            
            if (!factoryABI) {
                return { Err: "Factory ABI not configured" };
            }

            // For now, return predicted address (implement actual factory call later)
            const predictedAddress = ethers.getCreateAddress({
                from: contracts.factory,
                nonce: parseInt(userHash + salt, 16) % 1000000
            });

            return { Ok: predictedAddress };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Wallet creation failed: ${message}` };
        }
    }),

    /**
     * Call any method on a ChatterPay contract using pre-signed transaction
     * @param callParams - Parameters including network ID, contract type, method name, params, and signed transaction
     * @returns Transaction result with hash, status, and gas used
     */
    callContract: update([Record({
        networkId: nat64,
        contractType: text, // "factory", "implementation", "nft", etc.
        methodName: text,
        params: text, // JSON array of parameters
        signedTransaction: text // Pre-signed transaction
    })], Result(Record({
        txHash: text,
        status: text,
        gasUsed: text
    })), async (callParams: any) => {
        try {
            const contracts = chatterPayContracts[Number(callParams.networkId)];
            if (!contracts) {
                return { Err: "Network not supported" };
            }

            const contractType = callParams.contractType as keyof typeof contracts;
            const contractAddress = contracts[contractType];
            if (!contractAddress) {
                return { Err: `${callParams.contractType} contract not configured for this network` };
            }

            const abi = contractABIs[callParams.contractType as string];
            if (!abi) {
                return { Err: `ABI not configured for ${callParams.contractType}` };
            }

            const provider = getProvider(Number(callParams.networkId));
            
            // Broadcast the pre-signed transaction
            const tx = await provider.broadcastTransaction(callParams.signedTransaction as string);
            const receipt = await tx.wait();

            if (!receipt) {
                return { Err: "Transaction receipt not found" };
            }

            return {
                Ok: {
                    txHash: tx.hash,
                    status: receipt.status === 1 ? 'CONFIRMED' : 'FAILED',
                    gasUsed: receipt.gasUsed.toString()
                }
            };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Contract call failed: ${message}` };
        }
    }),

    /**
     * Execute a native token transfer using pre-signed transaction
     * @param params - Transfer parameters including to, from, amount, signed transaction, and chain ID
     * @returns Transaction result with hash, status, gas used, and effective gas price
     */
    transferSigned: update([SignedTransferParams], Result(TransferResult), async (params: any) => {
        try {
            // Validate inputs
            if (!ethers.isAddress(params.to as string)) {
                return { Err: "Invalid recipient address" };
            }

            const provider = getProvider(Number(params.chainId));
            
            // Broadcast the pre-signed transaction
            const transaction = await provider.broadcastTransaction(params.signedTransaction as string);

            // Wait for confirmation with timeout
            const receipt = await Promise.race([
                transaction.wait(1), // Wait for 1 confirmation
                new Promise<TransactionReceipt>((_, reject) => 
                    setTimeout(() => reject(new Error("Transaction timeout")), 60000)
                )
            ]);

            if (!receipt) {
                return { Err: "Transaction failed to confirm" };
            }

            return {
                Ok: {
                    txHash: transaction.hash,
                    status: receipt.status === 1 ? 'CONFIRMED' : 'FAILED',
                    gasUsed: receipt.gasUsed.toString(),
                    effectiveGasPrice: (receipt.gasPrice || 0n).toString()
                }
            };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Transaction failed: ${message}` };
        }
    }),

    /**
     * Get the current status of a transaction
     * @param txHash - The transaction hash to check
     * @returns Transaction status with confirmations, gas used, and effective gas price
     */
    getTransactionStatus: query([text], Result(TransactionStatusResult), async (txHash: string) => {
        try {
            const provider = getProvider(); // Use default provider
            const tx = await provider.getTransaction(txHash);
            if (!tx) {
                return { Err: "Transaction not found" };
            }

            const receipt = await tx.wait();
            if (!receipt) {
                return { Err: "Receipt not found" };
            }
            
            const confirmations = await tx.confirmations();

            return {
                Ok: {
                    status: receipt.status === 1 ? 'CONFIRMED' : 'FAILED',
                    confirmations: BigInt(confirmations || 0),
                    gasUsed: receipt.gasUsed.toString(),
                    effectiveGasPrice: (receipt.gasPrice || 0n).toString()
                }
            };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: message };
        }
    }),

    /**
     * Validate if an address is a valid Ethereum address
     * @param address - The address string to validate
     * @returns Boolean indicating if the address is valid
     */
    validateAddress: query([text], Result(bool), (address: string) => {
        try {
            return { Ok: ethers.isAddress(address) };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: message };
        }
    }),

    /**
     * Estimate gas costs for a transaction
     * @param params - Gas estimation parameters including to, from, amount, and chain ID
     * @returns Gas estimation with limit, price, and total estimated cost
     */
    estimateGas: query([GasEstimateParams], Result(GasEstimateResult), async (params: any) => {
        try {
            if (!ethers.isAddress(params.to as string)) {
                return { Err: "Invalid recipient address" };
            }

            const provider = getProvider(Number(params.chainId));
            const value = ethers.parseEther(params.amount as string);

            const tx = {
                to: params.to as string,
                from: params.from as string,
                value,
                chainId: Number(params.chainId),
            };

            const [gasLimit, feeData] = await Promise.all([
                provider.estimateGas(tx),
                provider.getFeeData()
            ]);

            const estimatedCost = gasLimit * (feeData.gasPrice || 0n);

            return {
                Ok: {
                    gasLimit: gasLimit.toString(),
                    gasPrice: (feeData.gasPrice || 0n).toString(),
                    maxFeePerGas: (feeData.maxFeePerGas || 0n).toString(),
                    maxPriorityFeePerGas: (feeData.maxPriorityFeePerGas || 0n).toString(),
                    estimatedCost: estimatedCost.toString()
                }
            };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Gas estimation failed: ${message}` };
        }
    }),

    /**
     * Get information about all supported blockchain networks
     * @returns Array of chain information including ID, name, and support status
     */
    getSupportedChains: query([], Vec(ChainInfo), () => {
        return Object.entries(CHAIN_CONFIGS).map(([chainId, config]) => ({
            chainId: BigInt(chainId),
            name: config.name,
            supported: true
        }));
    }),

    /**
     * Get information about a specific blockchain network
     * @param chainId - The chain ID to get information for
     * @returns Chain information or error if not supported
     */
    getChainInfo: query([nat64], Result(ChainInfo), (chainId: bigint) => {
        const id = Number(chainId);
        const config = CHAIN_CONFIGS[id as keyof typeof CHAIN_CONFIGS];
        
        if (!config) {
            return { Err: "Unsupported chain ID" };
        }

        return {
            Ok: {
                chainId: BigInt(id),
                name: config.name,
                supported: true
            }
        };
    })
});
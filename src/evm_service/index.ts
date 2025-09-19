import { 
    Canister, 
    query, 
    update, 
    Record, 
    text, 
    nat64, 
    bool,
    Variant,
    caller,
    Principal
} from 'azle/experimental';
import { ethers, JsonRpcProvider, Wallet } from 'ethers';
import type { TransactionReceipt, TransactionResponse } from 'ethers';

// Config from environment
const ARBITRUM_SEPOLIA_RPC = process.env.ARBITRUM_SEPOLIA_RPC || "https://sepolia-rollup.arbitrum.io/rpc";
const POLYGON_RPC = process.env.POLYGON_RPC || "https://polygon-rpc.com";
const BSC_RPC = process.env.BSC_RPC || "https://bsc-dataseed.binance.org";
const ETHEREUM_RPC = process.env.ETHEREUM_RPC || "https://ethereum.publicnode.com";
const SCROLL_RPC = process.env.SCROLL_RPC || "https://rpc.scroll.io";
const SCROLL_SEPOLIA_RPC = process.env.SCROLL_SEPOLIA_RPC || "https://sepolia-rpc.scroll.io";

// Chain configurations
const CHAIN_CONFIGS = {
    421614: { name: "Arbitrum Sepolia", rpc: ARBITRUM_SEPOLIA_RPC },
    137: { name: "Polygon", rpc: POLYGON_RPC },
    56: { name: "BSC", rpc: BSC_RPC },
    1: { name: "Ethereum", rpc: ETHEREUM_RPC },
    534352: { name: "Scroll", rpc: SCROLL_RPC },
    534351: { name: "Scroll Sepolia", rpc: SCROLL_SEPOLIA_RPC }
};

const DEFAULT_CHAIN_ID = Number(process.env.CHAIN_ID || "421614");

// Initialize providers for different chains
const providers = new Map<number, JsonRpcProvider>();
for (const [chainId, config] of Object.entries(CHAIN_CONFIGS)) {
    providers.set(Number(chainId), new JsonRpcProvider(config.rpc));
}

// Get provider for specific chain
function getProvider(chainId?: number): JsonRpcProvider {
    const id = chainId || DEFAULT_CHAIN_ID;
    const provider = providers.get(id);
    if (!provider) {
        throw new Error(`Unsupported chain ID: ${id}`);
    }
    return provider;
}

// Candid types
const TransferParams = Record({
    to: text,
    from: text,
    amount: text,
    privateKey: text,
    chainId: nat64
});

const GasEstimateParams = Record({
    to: text,
    from: text,
    amount: text,
    chainId: nat64
});

const GasEstimateResult = Record({
    gasLimit: text,
    gasPrice: text,
    maxFeePerGas: text,
    maxPriorityFeePerGas: text,
    estimatedCost: text
});

const ChainInfo = Record({
    chainId: nat64,
    name: text,
    supported: bool
});

const TransferResult = Record({
    txHash: text,
    status: text,
    gasUsed: text,
    effectiveGasPrice: text
});

const TransactionStatusResult = Record({
    status: text,
    confirmations: nat64,
    gasUsed: text,
    effectiveGasPrice: text
});

const Result = <T>(type: T) => Variant({
    Ok: type,
    Err: text
});

// Owner management - will be set on first deployment
let OWNER: string | null = null;

// ChatterPay contracts by network ID (any network supported)
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

// ABIs by contract type
let contractABIs: { [contractType: string]: string } = {
    factory: "",
    implementation: "",
    nft: "",
    paymaster: "",
    entryPoint: ""
};

export default Canister({
    // Initialize owner (can only be called once, when OWNER is null)
    initializeOwner: update([], Result(text), () => {
        if (OWNER !== null) {
            return { Err: "Owner already initialized" };
        }
        OWNER = caller().toString();
        return { Ok: OWNER };
    }),

    // Transfer ownership (only current owner)
    setOwner: update([text], Result(bool), (newOwner: string) => {
        if (OWNER === null) {
            return { Err: "Owner not initialized. Call initializeOwner first." };
        }
        if (caller().toString() !== OWNER) {
            return { Err: "Only current owner can transfer ownership" };
        }
        OWNER = newOwner;
        return { Ok: true };
    }),

    getOwner: query([], text, () => OWNER || ""),

    // Update contract addresses for any network (owner only)
    updateNetworkContracts: update([nat64, Record({
        factory: text,
        implementation: text,
        nft: text,
        paymaster: text,
        entryPoint: text
    })], Result(bool), (networkId: bigint, contracts: Record<string, string>) => {
        if (OWNER === null) {
            return { Err: "Owner not initialized" };
        }
        if (caller().toString() !== OWNER) {
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

    // Update ABIs (owner only)
    updateABIs: update([Record({
        factory: text,
        implementation: text,
        nft: text,
        paymaster: text,
        entryPoint: text
    })], Result(bool), (abis: Record<string, string>) => {
        if (OWNER === null) {
            return { Err: "Owner not initialized" };
        }
        if (caller().toString() !== OWNER) {
            return { Err: "Only owner can update ABIs" };
        }
        
        contractABIs.factory = abis.factory;
        contractABIs.implementation = abis.implementation;
        contractABIs.nft = abis.nft;
        contractABIs.paymaster = abis.paymaster;
        contractABIs.entryPoint = abis.entryPoint;
        return { Ok: true };
    }),

    // Get contracts for any network
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

    // Get all supported networks
    getSupportedNetworks: query([], [nat64], () => {
        return Object.keys(chatterPayContracts).map(id => BigInt(id));
    }),

    // Create user wallet using factory contract
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

    // Call any ChatterPay contract method
    callContract: update([Record({
        networkId: nat64,
        contractType: text, // "factory", "implementation", "nft", etc.
        methodName: text,
        params: text, // JSON array of parameters
        privateKey: text
    })], Result(Record({
        txHash: text,
        status: text,
        gasUsed: text
    })), async (callParams: Record<string, unknown>) => {
        try {
            const contracts = chatterPayContracts[Number(callParams.networkId)];
            if (!contracts) {
                return { Err: "Network not supported" };
            }

            const contractAddress = contracts[callParams.contractType as keyof typeof contracts];
            if (!contractAddress) {
                return { Err: `${callParams.contractType} contract not configured for this network` };
            }

            const abi = contractABIs[callParams.contractType];
            if (!abi) {
                return { Err: `ABI not configured for ${callParams.contractType}` };
            }

            const provider = getProvider(Number(callParams.networkId));
            const wallet = new Wallet(callParams.privateKey, provider);
            const contract = new ethers.Contract(contractAddress, JSON.parse(abi), wallet);
            
            const methodParams = JSON.parse(callParams.params);
            const tx = await contract[callParams.methodName](...methodParams);
            const receipt = await tx.wait();

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

    transfer: update([TransferParams], Result(TransferResult), async (params: Record<string, unknown>) => {
        try {
            // Validate inputs
            if (!ethers.isAddress(params.to)) {
                return { Err: "Invalid recipient address" };
            }

            const provider = getProvider(Number(params.chainId));
            const wallet = new Wallet(params.privateKey, provider);

            // Get balance as bigint
            const balance = await provider.getBalance(wallet.address);
            const value = ethers.parseEther(params.amount);
            
            if (balance < value) {
                return { Err: "Insufficient balance" };
            }

            // Prepare transaction
            const tx = {
                to: params.to,
                value,
                chainId: Number(params.chainId),
            };

            // Get gas data with retry logic
            let gasLimit: bigint;
            let feeData;
            try {
                [gasLimit, feeData] = await Promise.all([
                    provider.estimateGas(tx),
                    provider.getFeeData()
                ]);
            } catch (error: unknown) {
                const message = error instanceof Error ? error.message : String(error);
                return { Err: `Gas estimation failed: ${message}` };
            }

            // Send transaction
            const transaction: TransactionResponse = await wallet.sendTransaction({
                ...tx,
                gasLimit: (gasLimit * BigInt(12)) / BigInt(10), // Add 20% buffer
                maxFeePerGas: feeData.maxFeePerGas,
                maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
            });

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
                    effectiveGasPrice: (receipt.gasPrice || receipt.effectiveGasPrice || 0n).toString()
                }
            };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: `Transaction failed: ${message}` };
        }
    }),

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

    validateAddress: query([text], Result(bool), (address: string) => {
        try {
            return { Ok: ethers.isAddress(address) };
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : String(error);
            return { Err: message };
        }
    }),

    estimateGas: query([GasEstimateParams], Result(GasEstimateResult), async (params: Record<string, unknown>) => {
        try {
            if (!ethers.isAddress(params.to)) {
                return { Err: "Invalid recipient address" };
            }

            const provider = getProvider(Number(params.chainId));
            const value = ethers.parseEther(params.amount);

            const tx = {
                to: params.to,
                from: params.from,
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

    getSupportedChains: query([], [ChainInfo], () => {
        return Object.entries(CHAIN_CONFIGS).map(([chainId, config]) => ({
            chainId: BigInt(chainId),
            name: config.name,
            supported: true
        }));
    }),

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
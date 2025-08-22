import { 
    Canister, 
    query, 
    update, 
    Record, 
    text, 
    nat64, 
    bool,
    Variant 
} from 'azle/experimental';
import { ethers, JsonRpcProvider, Wallet } from 'ethers';
import type { TransactionReceipt, TransactionResponse } from 'ethers';

// Config from environment
const ARBITRUM_SEPOLIA_RPC = process.env.ARBITRUM_SEPOLIA_RPC || "https://sepolia-rollup.arbitrum.io/rpc";
const POLYGON_RPC = process.env.POLYGON_RPC || "https://polygon-rpc.com";
const BSC_RPC = process.env.BSC_RPC || "https://bsc-dataseed.binance.org";
const ETHEREUM_RPC = process.env.ETHEREUM_RPC || "https://ethereum.publicnode.com";

// Chain configurations
const CHAIN_CONFIGS = {
    421614: { name: "Arbitrum Sepolia", rpc: ARBITRUM_SEPOLIA_RPC },
    137: { name: "Polygon", rpc: POLYGON_RPC },
    56: { name: "BSC", rpc: BSC_RPC },
    1: { name: "Ethereum", rpc: ETHEREUM_RPC }
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

export default Canister({
    transfer: update([TransferParams], Result(TransferResult), async (params) => {
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
            } catch (error: any) {
                return { Err: `Gas estimation failed: ${error.message}` };
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
        } catch (error: any) {
            return { Err: `Transaction failed: ${error.message}` };
        }
    }),

    getTransactionStatus: query([text], Result(TransactionStatusResult), async (txHash) => {
        try {
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
        } catch (error: any) {
            return { Err: error.message };
        }
    }),

    validateAddress: query([text], Result(bool), (address) => {
        try {
            return { Ok: ethers.isAddress(address) };
        } catch (error: any) {
            return { Err: error.message };
        }
    }),

    estimateGas: query([GasEstimateParams], Result(GasEstimateResult), async (params) => {
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
        } catch (error: any) {
            return { Err: `Gas estimation failed: ${error.message}` };
        }
    }),

    getSupportedChains: query([], [ChainInfo], () => {
        return Object.entries(CHAIN_CONFIGS).map(([chainId, config]) => ({
            chainId: BigInt(chainId),
            name: config.name,
            supported: true
        }));
    }),

    getChainInfo: query([nat64], Result(ChainInfo), (chainId) => {
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
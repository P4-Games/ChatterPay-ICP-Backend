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
const CHAIN_ID = Number(process.env.CHAIN_ID || "421614");

// Initialize provider
const provider = new JsonRpcProvider(ARBITRUM_SEPOLIA_RPC);

// Candid types
const TransferParams = Record({
    to: text,
    from: text,
    amount: text,
    privateKey: text
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
                chainId: CHAIN_ID,
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
    })
});
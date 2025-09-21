/**
 * @fileoverview ChatterPay Transaction Manager - Multi-chain transaction processing and analytics
 * @author ChatterPay Team
 */

import Principal "mo:base/Principal";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import ENV "../env/lib";

/**
 * TransactionManager Canister
 * 
 * Handles multi-chain transaction processing, execution, and analytics for the ChatterPay ecosystem.
 * Integrates with EVM service for blockchain interactions and provides comprehensive transaction tracking.
 */
persistent actor TransactionManager {
    /** Transaction type definition matching database schema fields */
    type Transaction = {
        id: Text;
        trx_hash: Text;
        wallet_from: Text;
        wallet_to: Text;
        trx_type: Text; 
        date: Int;
        status: Text;
        amount: Nat;
        token: Text;
    };

    /** Counter for generating unique transaction IDs */
    private var nextId: Nat = 0;
    /** HashMap storing transactions by their ID */
    private transient var transactions = HashMap.HashMap<Text, Transaction>(0, Text.equal, Text.hash);

    /** EVM service actor interface for blockchain interactions */
    type EVMService = actor {
        transfer: shared ({
            to: Text;
            from: Text;
            amount: Text;
            privateKey: Text;
            chainId: Nat;
        }) -> async {
            #Ok: {
                txHash: Text;
                status: Text;
            };
            #Err: Text;
        };
        validateAddress: shared (Text) -> async {
            #Ok: Bool;
            #Err: Text;
        };
        estimateGas: shared ({
            to: Text;
            from: Text;
            amount: Text;
            chainId: Nat;
        }) -> async {
            #Ok: {
                gasLimit: Text;
                gasPrice: Text;
                maxFeePerGas: Text;
                maxPriorityFeePerGas: Text;
                estimatedCost: Text;
            };
            #Err: Text;
        };
    };

    /** Initialize EVM service with canister ID from environment */
    private transient let evmService: EVMService = actor (ENV.getCanisterId("evm_service"));

    /**
     * Execute a multi-chain token transfer transaction
     * @param to - Recipient wallet address
     * @param amount - Amount to transfer (in wei or token units)
     * @param privateKey - Private key for signing the transaction
     * @param chainId - Optional chain ID, defaults to Arbitrum Sepolia
     * @returns Transaction result with hash and status, or error message
     */
    public shared(msg) func makeTransfer(
        to: Text,
        amount: Nat,
        privateKey: Text,
        chainId: ?Nat
    ) : async Result.Result<Transaction, Text> {
        try {
            let addressValid = await evmService.validateAddress(to);
            switch (addressValid) {
                case (#Err(e)) { return #err("Invalid address: " # e) };
                case (#Ok(valid)) {
                    if (not valid) { return #err("Invalid address format") };
                };
            };

            let caller_text = Principal.toText(msg.caller);
            let selectedChainId = switch (chainId) {
                case (?id) { id };
                case (null) { 421614 }; // Default to Arbitrum Sepolia
            };

            // Execute transfer with EVM service
            let result = await evmService.transfer({
                to = to;
                from = caller_text;
                amount = Nat.toText(amount);
                privateKey = privateKey;
                chainId = selectedChainId;
            });

            switch (result) {
                case (#Ok(data)) {
                    // Store transaction in schema-compatible structure
                    let txn: Transaction = {
                        id = Nat.toText(nextId);
                        trx_hash = data.txHash;
                        wallet_from = caller_text;
                        wallet_to = to;
                        trx_type = "TRANSFER";  // Set `trx_type` instead of `type`
                        date = Time.now();
                        status = data.status;
                        amount = amount;
                        token = "TOKEN";
                    };

                    transactions.put(txn.id, txn);
                    nextId += 1;

                    #ok(txn)
                };
                case (#Err(e)) {
                    #err(e)
                };
            }
        } catch (e) {
            #err("Transaction failed: " # Error.message(e))
        }
    };

    /**
     * Get transaction details by ID
     * @param id - Transaction ID
     * @returns Transaction details or null if not found
     */
    public query func getTransaction(id: Text) : async ?Transaction {
        transactions.get(id)
    };

    /**
     * Get all transactions in the system
     * @returns Array of all transactions
     */
    public query func getAllTransactions() : async [Transaction] {
        let txns = Buffer.Buffer<Transaction>(0);
        for ((_, tx) in transactions.entries()) {
            txns.add(tx);
        };
        Buffer.toArray(txns)
    };

    /**
     * Get transactions associated with a specific wallet address
     * @param address - Wallet address to search for
     * @returns Array of transactions where the address is sender or recipient
     */
    public query func getTransactionsByAddress(address: Text) : async [Transaction] {
        let txns = Buffer.Buffer<Transaction>(0);
        for ((_, tx) in transactions.entries()) {
            if (tx.wallet_from == address or tx.wallet_to == address) {
                txns.add(tx);
            };
        };
        Buffer.toArray(txns)
    };

    /**
     * Get all transactions with pending status
     * @returns Array of pending transactions
     */
    public query func getPendingTransactions() : async [Transaction] {
        let txns = Buffer.Buffer<Transaction>(0);
        for ((_, tx) in transactions.entries()) {
            if (tx.status == "PENDING") {
                txns.add(tx);
            };
        };
        Buffer.toArray(txns)
    };

    /**
     * Get transaction count grouped by status for analytics
     * @returns Array of tuples containing status and count
     */
    public query func getTransactionCountByStatus() : async [(Text, Nat)] {
        var confirmed: Nat = 0;
        var pending: Nat = 0;
        var failed: Nat = 0;
        
        for ((_, tx) in transactions.entries()) {
            switch (tx.status) {
                case ("CONFIRMED") { confirmed += 1 };
                case ("PENDING") { pending += 1 };
                case ("FAILED") { failed += 1 };
                case (_) { };
            };
        };
        
        [("CONFIRMED", confirmed), ("PENDING", pending), ("FAILED", failed)]
    };

    /**
     * Get total transaction volume across all confirmed transactions
     * @returns Total volume in wei or token units
     */
    public query func getTotalTransactionVolume() : async Nat {
        var totalVolume: Nat = 0;
        for ((_, tx) in transactions.entries()) {
            if (tx.status == "CONFIRMED") {
                totalVolume += tx.amount;
            };
        };
        totalVolume
    };

    /**
     * Get transaction count for a specific wallet address
     * @param address - Wallet address to count transactions for
     * @returns Number of transactions associated with the address
     */
    public query func getTransactionCountByAddress(address: Text) : async Nat {
        var count: Nat = 0;
        for ((_, tx) in transactions.entries()) {
            if (tx.wallet_from == address or tx.wallet_to == address) {
                count += 1;
            };
        };
        count
    };

    /**
     * Estimate gas costs for a multi-chain transfer
     * @param to - Recipient wallet address
     * @param amount - Amount to transfer
     * @param chainId - Optional chain ID, defaults to Arbitrum Sepolia
     * @returns Gas estimation details or error message
     */
    public shared func estimateTransferGas(
        to: Text,
        amount: Nat,
        chainId: ?Nat
    ) : async Result.Result<{gasLimit: Text; gasPrice: Text; estimatedCost: Text}, Text> {
        try {
            let selectedChainId = switch (chainId) {
                case (?id) { id };
                case (null) { 421614 }; // Default to Arbitrum Sepolia
            };

            let result = await evmService.estimateGas({
                to = to;
                from = "0x0000000000000000000000000000000000000000"; // Placeholder for estimation
                amount = Nat.toText(amount);
                chainId = selectedChainId;
            });

            switch (result) {
                case (#Ok(gasData)) {
                    #ok({
                        gasLimit = gasData.gasLimit;
                        gasPrice = gasData.gasPrice;
                        estimatedCost = gasData.estimatedCost;
                    })
                };
                case (#Err(e)) {
                    #err("Gas estimation failed: " # e)
                };
            }
        } catch (e) {
            #err("Gas estimation error: " # Error.message(e))
        }
    };
};

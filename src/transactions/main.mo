import Array "mo:base/Array";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Types "../types";
import Float "mo:base/Float";

actor TransactionStorage {
    type Transaction = Types.Transaction;

    private stable var nextId: Nat = 0;
    private var transactions = HashMap.HashMap<Nat, Transaction>(0, Nat.equal, Hash.hash);
    private var hashToId = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);

    // Create a new transaction
    public shared func createTransaction(
        trx_hash: Text,
        wallet_from: Text,
        wallet_to: Text,
        type_: Text,
        status: Text,
        amount: Float,
        token: Text
    ) : async Nat {
        let transaction: Transaction = {
            id = nextId;
            trx_hash = trx_hash;
            wallet_from = wallet_from;
            wallet_to = wallet_to;
            type_ = type_;
            date = Time.now();
            status = status;
            amount = amount;
            token = token;
        };

        transactions.put(nextId, transaction);
        hashToId.put(trx_hash, nextId);
        nextId += 1;
        nextId - 1
    };

    // Get transaction by ID
    public query func getTransaction(id: Nat) : async ?Transaction {
        transactions.get(id)
    };

    // Get transaction by hash
    public query func getTransactionByHash(hash: Text) : async ?Transaction {
        switch (hashToId.get(hash)) {
            case (null) { null };
            case (?id) { transactions.get(id) };
        }
    };

    // Update transaction status
    public shared func updateTransactionStatus(id: Nat, newStatus: Text) : async Bool {
        switch (transactions.get(id)) {
            case (null) { false };
            case (?existingTx) {
                let updatedTx: Transaction = {
                    id = existingTx.id;
                    trx_hash = existingTx.trx_hash;
                    wallet_from = existingTx.wallet_from;
                    wallet_to = existingTx.wallet_to;
                    type_ = existingTx.type_;
                    date = existingTx.date;
                    status = newStatus;
                    amount = existingTx.amount;
                    token = existingTx.token;
                };
                transactions.put(id, updatedTx);
                true
            };
        }
    };

    // Get transactions by wallet (either sender or receiver)
    public query func getTransactionsByWallet(wallet: Text) : async [Transaction] {
        var walletTransactions: [Transaction] = [];
        for ((id, tx) in transactions.entries()) {
            if (tx.wallet_from == wallet or tx.wallet_to == wallet) {
                walletTransactions := Array.append(walletTransactions, [tx]);
            };
        };
        walletTransactions
    };

    // Get transactions by token
    public query func getTransactionsByToken(tokenAddress: Text) : async [Transaction] {
        var tokenTransactions: [Transaction] = [];
        for ((id, tx) in transactions.entries()) {
            if (tx.token == tokenAddress) {
                tokenTransactions := Array.append(tokenTransactions, [tx]);
            };
        };
        tokenTransactions
    };

    // Get all transactions
    public query func getAllTransactions() : async [Transaction] {
        var transactionArray: [Transaction] = [];
        for ((id, tx) in transactions.entries()) {
            transactionArray := Array.append(transactionArray, [tx]);
        };
        transactionArray
    };
}
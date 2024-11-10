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

actor TransactionManager {
    // Adjusted Transaction type to match Mongoose schema fields
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

    // Storage
    private stable var nextId: Nat = 0;
    private var transactions = HashMap.HashMap<Text, Transaction>(0, Text.equal, Text.hash);

    // EVM service interface
    type EVMService = actor {
        transfer: shared ({
            to: Text;
            from: Text;
            amount: Text;
            privateKey: Text;
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
    };

    // Initialize EVM service with canister ID from environment
    private let evmService: EVMService = actor (ENV.getCanisterId("evm_service"));

    // Create and execute transaction
    public shared(msg) func makeTransfer(
        to: Text,
        amount: Nat,
        privateKey: Text
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

            // Execute transfer with EVM service
            let result = await evmService.transfer({
                to = to;
                from = caller_text;
                amount = Nat.toText(amount);
                privateKey = privateKey;
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

    // Get transaction by ID
    public query func getTransaction(id: Text) : async ?Transaction {
        transactions.get(id)
    };

    // Get all transactions
    public query func getAllTransactions() : async [Transaction] {
        let txns = Buffer.Buffer<Transaction>(0);
        for ((_, tx) in transactions.entries()) {
            txns.add(tx);
        };
        Buffer.toArray(txns)
    };

    // Get transactions by address
    public query func getTransactionsByAddress(address: Text) : async [Transaction] {
        let txns = Buffer.Buffer<Transaction>(0);
        for ((_, tx) in transactions.entries()) {
            if (tx.wallet_from == address or tx.wallet_to == address) {
                txns.add(tx);
            };
        };
        Buffer.toArray(txns)
    };

    // Get pending transactions
    public query func getPendingTransactions() : async [Transaction] {
        let txns = Buffer.Buffer<Transaction>(0);
        for ((_, tx) in transactions.entries()) {
            if (tx.status == "PENDING") {
                txns.add(tx);
            };
        };
        Buffer.toArray(txns)
    };
};

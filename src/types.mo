/**
 * @fileoverview ChatterPay Types - Core type definitions for the ChatterPay ecosystem
 * @author ChatterPay Team
 */

module {
    /** Transaction type for blockchain transaction records */
    public type Transaction = {
        id: Nat;
        trx_hash: Text;
        wallet_from: Text;
        wallet_to: Text;
        type_: Text;  // 'type' is a reserved word in Motoko
        date: Int;    // Timestamp in nanoseconds
        status: Text;
        amount: Float;
        token: Text;
    };

    /** User type for user account information */
    public type User = {
        id: Nat;
        name: ?Text;         // Optional fields use ?Type
        email: ?Text;
        phone_number: Text;
        photo: ?Text;
        wallet: Text;
        code: ?Nat;
        privateKey: Text;
    };

    /** Contracts type for smart contract addresses */
    public type Contracts = {
        entryPoint: ?Text;
        factoryAddress: ?Text;
        chatterPayAddress: ?Text;
        chatterPayBeaconAddress: ?Text;
        chatterNFTAddress: ?Text;
        paymasterAddress: ?Text;
    };

    /** Blockchain type for blockchain network configuration */
    public type Blockchain = {
        id: Nat;
        name: Text;
        chain_id: Nat;
        rpc: Text;
        logo: Text;
        explorer: Text;
        scan_apikey: Text;
        contracts: Contracts;
    };

    /** Token type for ERC-20 token configuration */
    public type Token = {
        id: Nat;
        name: Text;
        chain_id: Nat;
        decimals: Nat;
        logo: ?Text;
        address: Text;
        symbol: Text;
    };

    /** LastProcessedBlock type for blockchain synchronization tracking */
    public type LastProcessedBlock = {
        id: Nat;
        networkName: Text;
        blockNumber: Nat;
        updatedAt: Int;  // Timestamp in nanoseconds
    };

    /** ImageUrl type for NFT image storage across different platforms */
    public type ImageUrl = {
        gcp: ?Text;
        icp: ?Text;
        ipfs: ?Text;
    };

    /** Geolocation type for NFT location metadata */
    public type Geolocation = {
        latitud: ?Text;
        longitud: ?Text;
    };

    /** NFTMetadata type for NFT descriptive information */
    public type NFTMetadata = {
        image_url: ImageUrl;
        description: Text;
        geolocation: ?Geolocation;
    };

    /** NFT type for Non-Fungible Token records */
    public type NFT = {
        id: Text;
        channel_user_id: Text;
        wallet: Text;
        trxId: Text;
        timestamp: Int;  // Timestamp in nanoseconds
        original: Bool;
        total_of_this: Nat;
        copy_of: ?Text;
        copy_order: Nat;
        copy_of_original: ?Text;
        copy_order_original: Nat;
        metadata: NFTMetadata;
    };
}
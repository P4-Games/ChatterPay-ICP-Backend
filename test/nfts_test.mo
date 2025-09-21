/**
 * @fileoverview ChatterPay NFTs Canister Tests - Comprehensive NFT management testing suite
 * @author ChatterPay Team
 */

import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Result "mo:base/Result";
import TestUtils "./test_utils";
import Types "../src/types";

/**
 * NFTs Canister Test Suite
 * 
 * Comprehensive testing for the NFTStorage canister including
 * NFT creation, metadata management, ownership tracking, and copy management.
 */
persistent actor NFTsTest {
    private transient var nftStorage: ?NFTStorage = null;

    // Mock NFTStorage actor for testing
    private type NFTStorage = actor {
        createNFT: shared (channel_user_id: Text, wallet: Text, trxId: Text, original: Bool, total_of_this: Nat, copy_of: ?Text, copy_order: Nat, copy_of_original: ?Text, copy_order_original: Nat, metadata: Types.NFTMetadata) -> async Text;
        getNFT: shared query (id: Text) -> async ?Types.NFT;
        getNFTsByWallet: shared query (wallet: Text) -> async [Types.NFT];
        getLastId: shared query () -> async Nat;
        updateNFTMetadata: shared (id: Text, metadata: Types.NFTMetadata) -> async Bool;
        getAllNFTs: shared query () -> async [Types.NFT];
        getNFTsByChannelUserId: shared query (channelUserId: Text) -> async [Types.NFT];
        getOriginalNFTs: shared query () -> async [Types.NFT];
        getNFTCopies: shared query (originalId: Text) -> async [Types.NFT];
        validateMetadata: shared (metadata: Types.NFTMetadata) -> async Result.Result<Bool, Text>;
        batchCreateNFTs: shared (nftData: [(Text, Text, Text, Bool, Nat, ?Text, Nat, ?Text, Nat, Types.NFTMetadata)]) -> async Result.Result<[Text], Text>;
        batchUpdateMetadata: shared (updates: [(Text, Types.NFTMetadata)]) -> async Result.Result<[Bool], Text>;
        getNFTCountByWallet: shared query (wallet: Text) -> async Nat;
    };

    public func setupTestCanister(canisterId: Text): async () {
        nftStorage := ?(actor(canisterId): NFTStorage);
    };

    /**
     * Generate mock NFT metadata for testing
     */
    private func generateMockMetadata(): Types.NFTMetadata {
        {
            image_url = {
                gcp = ?"https://storage.googleapis.com/test-bucket/nft-image.png";
                icp = ?"https://test-canister.ic0.app/nft-image.png";
                ipfs = ?"ipfs://QmTest123456789";
            };
            description = "Test NFT for comprehensive testing";
            geolocation = ?{
                latitud = ?"40.7128";
                longitud = ?"-74.0060";
            };
        }
    };

    /**
     * Test NFT creation functionality
     */
    public func testCreateNFT(): async Bool {
        try {
            switch (nftStorage) {
                case (?storage) {
                    let metadata = generateMockMetadata();
                    let nftId = await storage.createNFT(
                        "test_channel_user_123",
                        "0x1234567890123456789012345678901234567890",
                        "0xabcdef1234567890abcdef1234567890abcdef12",
                        true, // original
                        1, // total_of_this
                        null, // copy_of
                        0, // copy_order
                        null, // copy_of_original
                        0, // copy_order_original
                        metadata
                    );
                    Text.size(nftId) > 0
                };
                case (null) {
                    Debug.print("Error: NFTStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testCreateNFT: " # Error.message(e));
            false
        }
    };

    /**
     * Test NFT retrieval by ID
     */
    public func testGetNFT(): async Bool {
        try {
            switch (nftStorage) {
                case (?storage) {
                    let metadata = generateMockMetadata();
                    let nftId = await storage.createNFT(
                        "test_channel_user_456",
                        "0x2345678901234567890123456789012345678901",
                        "0xbcdef1234567890abcdef1234567890abcdef123",
                        true,
                        1,
                        null,
                        0,
                        null,
                        0,
                        metadata
                    );

                    let retrievedNFT = await storage.getNFT(nftId);
                    switch (retrievedNFT) {
                        case (?nft) {
                            nft.id == nftId and 
                            nft.channel_user_id == "test_channel_user_456" and
                            nft.original == true and
                            nft.metadata.description == "Test NFT for comprehensive testing"
                        };
                        case (null) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: NFTStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testGetNFT: " # Error.message(e));
            false
        }
    };

    /**
     * Test getting NFTs by wallet address
     */
    public func testGetNFTsByWallet(): async Bool {
        try {
            switch (nftStorage) {
                case (?storage) {
                    let testWallet = "0x3456789012345678901234567890123456789012";
                    let metadata = generateMockMetadata();
                    
                    // Create multiple NFTs for the same wallet
                    let nftId1 = await storage.createNFT(
                        "test_user_1",
                        testWallet,
                        "0xtrx1",
                        true,
                        1,
                        null,
                        0,
                        null,
                        0,
                        metadata
                    );

                    let nftId2 = await storage.createNFT(
                        "test_user_1",
                        testWallet,
                        "0xtrx2",
                        true,
                        1,
                        null,
                        0,
                        null,
                        0,
                        metadata
                    );

                    let walletNFTs = await storage.getNFTsByWallet(testWallet);
                    
                    // Should have at least 2 NFTs for this wallet
                    var foundNFT1 = false;
                    var foundNFT2 = false;
                    
                    for (nft in walletNFTs.vals()) {
                        if (nft.id == nftId1) { foundNFT1 := true };
                        if (nft.id == nftId2) { foundNFT2 := true };
                    };
                    
                    foundNFT1 and foundNFT2
                };
                case (null) {
                    Debug.print("Error: NFTStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testGetNFTsByWallet: " # Error.message(e));
            false
        }
    };

    /**
     * Test NFT metadata update functionality
     */
    public func testUpdateNFTMetadata(): async Bool {
        try {
            switch (nftStorage) {
                case (?storage) {
                    let originalMetadata = generateMockMetadata();
                    let nftId = await storage.createNFT(
                        "test_update_user",
                        "0x4567890123456789012345678901234567890123",
                        "0xupdate_trx",
                        true,
                        1,
                        null,
                        0,
                        null,
                        0,
                        originalMetadata
                    );

                    // Create updated metadata
                    let updatedMetadata: Types.NFTMetadata = {
                        image_url = {
                            gcp = ?"https://storage.googleapis.com/updated-bucket/updated-nft.png";
                            icp = ?"https://updated-canister.ic0.app/updated-nft.png";
                            ipfs = ?"ipfs://QmUpdated987654321";
                        };
                        description = "Updated NFT description for testing";
                        geolocation = ?{
                            latitud = ?"51.5074";
                            longitud = ?"-0.1278";
                        };
                    };

                    let updateResult = await storage.updateNFTMetadata(nftId, updatedMetadata);
                    
                    if (updateResult) {
                        // Verify the update
                        let updatedNFT = await storage.getNFT(nftId);
                        switch (updatedNFT) {
                            case (?nft) {
                                nft.metadata.description == "Updated NFT description for testing"
                            };
                            case (null) { false };
                        }
                    } else {
                        false
                    }
                };
                case (null) {
                    Debug.print("Error: NFTStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testUpdateNFTMetadata: " # Error.message(e));
            false
        }
    };

    /**
     * Test getting NFTs by channel user ID
     */
    public func testGetNFTsByChannelUserId(): async Bool {
        try {
            switch (nftStorage) {
                case (?storage) {
                    let testChannelUserId = "channel_user_test_789";
                    let metadata = generateMockMetadata();
                    
                    let nftId = await storage.createNFT(
                        testChannelUserId,
                        "0x5678901234567890123456789012345678901234",
                        "0xchannel_trx",
                        true,
                        1,
                        null,
                        0,
                        null,
                        0,
                        metadata
                    );

                    let channelUserNFTs = await storage.getNFTsByChannelUserId(testChannelUserId);
                    
                    // Should find at least one NFT for this channel user
                    var foundNFT = false;
                    for (nft in channelUserNFTs.vals()) {
                        if (nft.id == nftId and nft.channel_user_id == testChannelUserId) {
                            foundNFT := true;
                        };
                    };
                    
                    foundNFT
                };
                case (null) {
                    Debug.print("Error: NFTStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testGetNFTsByChannelUserId: " # Error.message(e));
            false
        }
    };

    /**
     * Test original NFTs and copy management
     */
    public func testNFTCopyManagement(): async Bool {
        try {
            switch (nftStorage) {
                case (?storage) {
                    let metadata = generateMockMetadata();
                    
                    // Create an original NFT
                    let originalId = await storage.createNFT(
                        "original_creator",
                        "0x6789012345678901234567890123456789012345",
                        "0xoriginal_trx",
                        true, // original
                        3, // total copies planned
                        null,
                        0,
                        null,
                        0,
                        metadata
                    );

                    // Create copies of the original
                    let copy1Id = await storage.createNFT(
                        "copy_creator_1",
                        "0x7890123456789012345678901234567890123456",
                        "0xcopy1_trx",
                        false, // not original
                        3,
                        ?originalId, // copy_of
                        1, // copy_order
                        ?originalId, // copy_of_original
                        1, // copy_order_original
                        metadata
                    );

                    let copy2Id = await storage.createNFT(
                        "copy_creator_2",
                        "0x8901234567890123456789012345678901234567",
                        "0xcopy2_trx",
                        false,
                        3,
                        ?originalId,
                        2,
                        ?originalId,
                        2,
                        metadata
                    );

                    // Test getting original NFTs
                    let originalNFTs = await storage.getOriginalNFTs();
                    var foundOriginal = false;
                    for (nft in originalNFTs.vals()) {
                        if (nft.id == originalId and nft.original == true) {
                            foundOriginal := true;
                        };
                    };

                    // Test getting copies of the original
                    let copies = await storage.getNFTCopies(originalId);
                    var foundCopy1 = false;
                    var foundCopy2 = false;
                    for (copy in copies.vals()) {
                        if (copy.id == copy1Id) { foundCopy1 := true };
                        if (copy.id == copy2Id) { foundCopy2 := true };
                    };

                    foundOriginal and foundCopy1 and foundCopy2
                };
                case (null) {
                    Debug.print("Error: NFTStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testNFTCopyManagement: " # Error.message(e));
            false
        }
    };

    /**
     * Test metadata validation
     */
    public func testMetadataValidation(): async Bool {
        try {
            switch (nftStorage) {
                case (?storage) {
                    // Test valid metadata
                    let validMetadata = generateMockMetadata();
                    let validResult = await storage.validateMetadata(validMetadata);
                    
                    // Test invalid metadata (empty description)
                    let invalidMetadata: Types.NFTMetadata = {
                        image_url = {
                            gcp = ?"https://storage.googleapis.com/test-bucket/nft.png";
                            icp = null;
                            ipfs = null;
                        };
                        description = ""; // Invalid: empty description
                        geolocation = null;
                    };
                    let invalidResult = await storage.validateMetadata(invalidMetadata);

                    switch (validResult, invalidResult) {
                        case (#ok(_), #err(_)) { true }; // Valid should pass, invalid should fail
                        case (_, _) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: NFTStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testMetadataValidation: " # Error.message(e));
            false
        }
    };

    /**
     * Test batch NFT creation
     */
    public func testBatchCreateNFTs(): async Bool {
        try {
            switch (nftStorage) {
                case (?storage) {
                    let metadata1 = generateMockMetadata();
                    let metadata2 = generateMockMetadata();
                    
                    let batchData = [
                        ("batch_user_1", "0x9012345678901234567890123456789012345678", "0xbatch_trx_1", true, 1, null, 0, null, 0, metadata1),
                        ("batch_user_2", "0x0123456789012345678901234567890123456789", "0xbatch_trx_2", true, 1, null, 0, null, 0, metadata2)
                    ];

                    let batchResult = await storage.batchCreateNFTs(batchData);
                    
                    switch (batchResult) {
                        case (#ok(nftIds)) {
                            nftIds.size() == 2 and Text.size(nftIds[0]) > 0 and Text.size(nftIds[1]) > 0
                        };
                        case (#err(_)) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: NFTStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testBatchCreateNFTs: " # Error.message(e));
            false
        }
    };

    /**
     * Test NFT count by wallet
     */
    public func testGetNFTCountByWallet(): async Bool {
        try {
            switch (nftStorage) {
                case (?storage) {
                    let testWallet = "0x1111222233334444555566667777888899990000";
                    let metadata = generateMockMetadata();
                    
                    let initialCount = await storage.getNFTCountByWallet(testWallet);
                    
                    // Create an NFT for this wallet
                    let _nftId = await storage.createNFT(
                        "count_test_user",
                        testWallet,
                        "0xcount_trx",
                        true,
                        1,
                        null,
                        0,
                        null,
                        0,
                        metadata
                    );

                    let newCount = await storage.getNFTCountByWallet(testWallet);
                    newCount == initialCount + 1
                };
                case (null) {
                    Debug.print("Error: NFTStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testGetNFTCountByWallet: " # Error.message(e));
            false
        }
    };

    /**
     * Test error handling for invalid operations
     */
    public func testErrorHandling(): async Bool {
        try {
            switch (nftStorage) {
                case (?storage) {
                    // Test getting non-existent NFT
                    let nonExistentNFT = await storage.getNFT("non_existent_id");
                    
                    // Test updating non-existent NFT
                    let metadata = generateMockMetadata();
                    let updateResult = await storage.updateNFTMetadata("non_existent_id", metadata);
                    
                    // Test getting NFTs for non-existent wallet
                    let emptyWalletNFTs = await storage.getNFTsByWallet("0x0000000000000000000000000000000000000000");

                    // All operations should handle non-existent data gracefully
                    switch (nonExistentNFT) {
                        case (null) { 
                            not updateResult and emptyWalletNFTs.size() == 0
                        };
                        case (?_) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: NFTStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testErrorHandling: " # Error.message(e));
            false
        }
    };

    /**
     * Run all NFT tests
     */
    public func runAllTests(canisterId: Text): async Text {
        await setupTestCanister(canisterId);

        Debug.print("\n🧪 Starting NFTs Canister Tests...\n");

        // Run tests and collect results
        let createNFTResult = await testCreateNFT();
        let getNFTResult = await testGetNFT();
        let getNFTsByWalletResult = await testGetNFTsByWallet();
        let updateNFTMetadataResult = await testUpdateNFTMetadata();
        let getNFTsByChannelUserIdResult = await testGetNFTsByChannelUserId();
        let nftCopyManagementResult = await testNFTCopyManagement();
        let metadataValidationResult = await testMetadataValidation();
        let batchCreateNFTsResult = await testBatchCreateNFTs();
        let getNFTCountByWalletResult = await testGetNFTCountByWallet();
        let errorHandlingResult = await testErrorHandling();

        let buffer = Buffer.Buffer<TestUtils.TestResult>(0);
        
        buffer.add({
            name = "Create NFT";
            passed = createNFTResult;
            error = if (createNFTResult) null else ?"NFT creation failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Get NFT";
            passed = getNFTResult;
            error = if (getNFTResult) null else ?"Get NFT by ID failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Get NFTs by Wallet";
            passed = getNFTsByWalletResult;
            error = if (getNFTsByWalletResult) null else ?"Get NFTs by wallet failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Update NFT Metadata";
            passed = updateNFTMetadataResult;
            error = if (updateNFTMetadataResult) null else ?"NFT metadata update failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Get NFTs by Channel User ID";
            passed = getNFTsByChannelUserIdResult;
            error = if (getNFTsByChannelUserIdResult) null else ?"Get NFTs by channel user ID failed";
            duration = 0;
        });
        
        buffer.add({
            name = "NFT Copy Management";
            passed = nftCopyManagementResult;
            error = if (nftCopyManagementResult) null else ?"NFT copy management failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Metadata Validation";
            passed = metadataValidationResult;
            error = if (metadataValidationResult) null else ?"Metadata validation failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Batch Create NFTs";
            passed = batchCreateNFTsResult;
            error = if (batchCreateNFTsResult) null else ?"Batch NFT creation failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Get NFT Count by Wallet";
            passed = getNFTCountByWalletResult;
            error = if (getNFTCountByWalletResult) null else ?"Get NFT count by wallet failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Error Handling";
            passed = errorHandlingResult;
            error = if (errorHandlingResult) null else ?"Error handling failed";
            duration = 0;
        });

        let results = Buffer.toArray(buffer);
        let report = TestUtils.generateReport(results);
        Debug.print(report);
        report
    };
};

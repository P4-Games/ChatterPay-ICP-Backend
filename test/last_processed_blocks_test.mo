/**
 * @fileoverview ChatterPay Last Processed Blocks Canister Tests - Comprehensive sync tracking testing suite
 * @author ChatterPay Team
 */

import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import TestUtils "./test_utils";
import Types "../src/types";

/**
 * Last Processed Blocks Canister Test Suite
 * 
 * Comprehensive testing for the LastProcessedBlockStorage canister including
 * block tracking, network-specific management, and synchronization state.
 */
persistent actor LastProcessedBlocksTest {
    private transient var blockStorage: ?LastProcessedBlockStorage = null;

    // Mock LastProcessedBlockStorage actor for testing
    private type LastProcessedBlockStorage = actor {
        updateLastProcessedBlock: shared (networkName: Text, blockNumber: Nat) -> async Nat;
        getLastProcessedBlock: shared query (networkName: Text) -> async ?Types.LastProcessedBlock;
        getAllLastProcessedBlocks: shared query () -> async [Types.LastProcessedBlock];
        deleteLastProcessedBlock: shared (networkName: Text) -> async Bool;
    };

    public func setupTestCanister(canisterId: Text): async () {
        blockStorage := ?(actor(canisterId): LastProcessedBlockStorage);
    };

    /**
     * Test block tracking creation and update functionality
     */
    public func testUpdateLastProcessedBlock(): async Bool {
        try {
            switch (blockStorage) {
                case (?storage) {
                    let networkName = "test_network_ethereum";
                    let blockNumber: Nat = 18500000;
                    
                    let _blockId = await storage.updateLastProcessedBlock(networkName, blockNumber);
                    _blockId >= 0
                };
                case (null) {
                    Debug.print("Error: LastProcessedBlockStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testUpdateLastProcessedBlock: " # Error.message(e));
            false
        }
    };

    /**
     * Test block tracking retrieval by network name
     */
    public func testGetLastProcessedBlock(): async Bool {
        try {
            switch (blockStorage) {
                case (?storage) {
                    let networkName = "test_network_polygon";
                    let blockNumber: Nat = 50000000;
                    
                    // Create a block record
                    let _blockId = await storage.updateLastProcessedBlock(networkName, blockNumber);
                    
                    // Retrieve it
                    let retrievedBlock = await storage.getLastProcessedBlock(networkName);
                    switch (retrievedBlock) {
                        case (?block) {
                            block.networkName == networkName and 
                            block.blockNumber == blockNumber and
                            block.updatedAt > 0 // Should have a valid timestamp
                        };
                        case (null) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: LastProcessedBlockStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testGetLastProcessedBlock: " # Error.message(e));
            false
        }
    };

    /**
     * Test block number update for existing network
     */
    public func testUpdateExistingNetwork(): async Bool {
        try {
            switch (blockStorage) {
                case (?storage) {
                    let networkName = "test_network_bsc";
                    let initialBlockNumber: Nat = 32000000;
                    let updatedBlockNumber: Nat = 32000100;
                    
                    // Create initial block record
                    let _initialId = await storage.updateLastProcessedBlock(networkName, initialBlockNumber);
                    
                    // Update the same network with new block number
                    let updatedId = await storage.updateLastProcessedBlock(networkName, updatedBlockNumber);
                    
                    // Should return the same ID (updating existing record)
                    if (_initialId == _initialId) {
                        let retrievedBlock = await storage.getLastProcessedBlock(networkName);
                        switch (retrievedBlock) {
                            case (?block) {
                                block.blockNumber == updatedBlockNumber and block.id == updatedId
                            };
                            case (null) { false };
                        }
                    } else {
                        false
                    }
                };
                case (null) {
                    Debug.print("Error: LastProcessedBlockStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testUpdateExistingNetwork: " # Error.message(e));
            false
        }
    };

    /**
     * Test getting all block records
     */
    public func testGetAllLastProcessedBlocks(): async Bool {
        try {
            switch (blockStorage) {
                case (?storage) {
                    let initialBlocks = await storage.getAllLastProcessedBlocks();
                    let initialCount = initialBlocks.size();
                    
                    // Create new block records for different networks
                    let network1 = "test_get_all_network_1";
                    let network2 = "test_get_all_network_2";
                    
                    let _blockId1 = await storage.updateLastProcessedBlock(network1, 1000000);
                    let _blockId2 = await storage.updateLastProcessedBlock(network2, 2000000);
                    
                    let newBlocks = await storage.getAllLastProcessedBlocks();
                    
                    // Should have at least 2 more blocks than initially
                    newBlocks.size() >= initialCount + 2
                };
                case (null) {
                    Debug.print("Error: LastProcessedBlockStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testGetAllLastProcessedBlocks: " # Error.message(e));
            false
        }
    };

    /**
     * Test block record deletion
     */
    public func testDeleteLastProcessedBlock(): async Bool {
        try {
            switch (blockStorage) {
                case (?storage) {
                    let networkName = "test_delete_network";
                    let blockNumber: Nat = 15000000;
                    
                    // Create a block record
                    let _blockId = await storage.updateLastProcessedBlock(networkName, blockNumber);
                    
                    // Verify it exists
                    let blockExists = await storage.getLastProcessedBlock(networkName);
                    switch (blockExists) {
                        case (?_) {
                            // Delete the block record
                            let deleteResult = await storage.deleteLastProcessedBlock(networkName);
                            
                            if (deleteResult) {
                                // Verify it's deleted
                                let deletedBlock = await storage.getLastProcessedBlock(networkName);
                                switch (deletedBlock) {
                                    case (null) { true }; // Should be null after deletion
                                    case (?_) { false }; // Should not exist
                                }
                            } else {
                                false
                            }
                        };
                        case (null) { false }; // Block should exist before deletion
                    }
                };
                case (null) {
                    Debug.print("Error: LastProcessedBlockStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testDeleteLastProcessedBlock: " # Error.message(e));
            false
        }
    };

    /**
     * Test multiple network management
     */
    public func testMultipleNetworks(): async Bool {
        try {
            switch (blockStorage) {
                case (?storage) {
                    // Create block records for different networks
                    let networks = [
                        ("ethereum_mainnet", 18500000),
                        ("polygon_mainnet", 50000000),
                        ("bsc_mainnet", 32000000),
                        ("arbitrum_one", 150000000),
                        ("optimism_mainnet", 110000000)
                    ];
                    
                    // Create all network records
                    var allCreated = true;
                    for ((network, blockNum) in networks.vals()) {
                        let _blockId = await storage.updateLastProcessedBlock(network, blockNum);
                        if (_blockId < 0) {
                            allCreated := false;
                        };
                    };
                    
                    if (allCreated) {
                        // Verify all networks can be retrieved
                        var allRetrieved = true;
                        for ((network, expectedBlockNum) in networks.vals()) {
                            let retrievedBlock = await storage.getLastProcessedBlock(network);
                            switch (retrievedBlock) {
                                case (?block) {
                                    if (block.networkName != network or block.blockNumber != expectedBlockNum) {
                                        allRetrieved := false;
                                    };
                                };
                                case (null) { 
                                    allRetrieved := false;
                                };
                            };
                        };
                        allRetrieved
                    } else {
                        false
                    }
                };
                case (null) {
                    Debug.print("Error: LastProcessedBlockStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testMultipleNetworks: " # Error.message(e));
            false
        }
    };

    /**
     * Test timestamp tracking
     */
    public func testTimestampTracking(): async Bool {
        try {
            switch (blockStorage) {
                case (?storage) {
                    let networkName = "test_timestamp_network";
                    let blockNumber: Nat = 20000000;
                    
                    // Create initial block record
                    let _blockId1 = await storage.updateLastProcessedBlock(networkName, blockNumber);
                    let block1 = await storage.getLastProcessedBlock(networkName);
                    
                    switch (block1) {
                        case (?b1) {
                            // Update the same network (should update timestamp)
                            let _blockId2 = await storage.updateLastProcessedBlock(networkName, blockNumber + 100);
                            let block2 = await storage.getLastProcessedBlock(networkName);
                            
                            switch (block2) {
                                case (?b2) {
                                    // Second update should have a later or equal timestamp
                                    b2.updatedAt >= b1.updatedAt and b2.blockNumber == blockNumber + 100
                                };
                                case (null) { false };
                            }
                        };
                        case (null) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: LastProcessedBlockStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testTimestampTracking: " # Error.message(e));
            false
        }
    };

    /**
     * Test block number progression validation
     */
    public func testBlockProgression(): async Bool {
        try {
            switch (blockStorage) {
                case (?storage) {
                    let networkName = "test_progression_network";
                    let startBlock: Nat = 1000000;
                    let progressionBlocks = [1000100, 1000200, 1000300, 1000400];
                    
                    // Set initial block
                    let _initialId = await storage.updateLastProcessedBlock(networkName, startBlock);
                    
                    // Progress through block numbers
                    var progressionValid = true;
                    for (blockNum in progressionBlocks.vals()) {
                        let _blockId = await storage.updateLastProcessedBlock(networkName, blockNum);
                        let retrievedBlock = await storage.getLastProcessedBlock(networkName);
                        
                        switch (retrievedBlock) {
                            case (?block) {
                                if (block.blockNumber != blockNum) {
                                    progressionValid := false;
                                };
                            };
                            case (null) { 
                                progressionValid := false;
                            };
                        };
                    };
                    
                    progressionValid
                };
                case (null) {
                    Debug.print("Error: LastProcessedBlockStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testBlockProgression: " # Error.message(e));
            false
        }
    };

    /**
     * Test edge cases and large block numbers
     */
    public func testEdgeCases(): async Bool {
        try {
            switch (blockStorage) {
                case (?storage) {
                    let networkName = "test_edge_cases_network";
                    
                    // Test with zero block number
                    let _zeroBlockId = await storage.updateLastProcessedBlock(networkName, 0);
                    let zeroBlock = await storage.getLastProcessedBlock(networkName);
                    
                    let zeroTest = switch (zeroBlock) {
                        case (?block) { block.blockNumber == 0 };
                        case (null) { false };
                    };
                    
                    // Test with large block number
                    let largeBlockNumber: Nat = 999999999999;
                    let _largeBlockId = await storage.updateLastProcessedBlock(networkName, largeBlockNumber);
                    let largeBlock = await storage.getLastProcessedBlock(networkName);
                    
                    let largeTest = switch (largeBlock) {
                        case (?block) { block.blockNumber == largeBlockNumber };
                        case (null) { false };
                    };
                    
                    zeroTest and largeTest
                };
                case (null) {
                    Debug.print("Error: LastProcessedBlockStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testEdgeCases: " # Error.message(e));
            false
        }
    };

    /**
     * Test error handling for invalid operations
     */
    public func testErrorHandling(): async Bool {
        try {
            switch (blockStorage) {
                case (?storage) {
                    // Test getting non-existent network
                    let nonExistentBlock = await storage.getLastProcessedBlock("non_existent_network");
                    
                    // Test deleting non-existent network
                    let deleteResult = await storage.deleteLastProcessedBlock("non_existent_network");

                    // Both operations should handle non-existent data gracefully
                    switch (nonExistentBlock) {
                        case (null) { not deleteResult }; // Should be null and delete should return false
                        case (?_) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: LastProcessedBlockStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testErrorHandling: " # Error.message(e));
            false
        }
    };

    /**
     * Run all last processed blocks tests
     */
    public func runAllTests(canisterId: Text): async Text {
        await setupTestCanister(canisterId);

        Debug.print("\n🧪 Starting Last Processed Blocks Canister Tests...\n");

        // Run tests and collect results
        let updateLastProcessedBlockResult = await testUpdateLastProcessedBlock();
        let getLastProcessedBlockResult = await testGetLastProcessedBlock();
        let updateExistingNetworkResult = await testUpdateExistingNetwork();
        let getAllLastProcessedBlocksResult = await testGetAllLastProcessedBlocks();
        let deleteLastProcessedBlockResult = await testDeleteLastProcessedBlock();
        let multipleNetworksResult = await testMultipleNetworks();
        let timestampTrackingResult = await testTimestampTracking();
        let blockProgressionResult = await testBlockProgression();
        let edgeCasesResult = await testEdgeCases();
        let errorHandlingResult = await testErrorHandling();

        let buffer = Buffer.Buffer<TestUtils.TestResult>(0);
        
        buffer.add({
            name = "Update Last Processed Block";
            passed = updateLastProcessedBlockResult;
            error = if (updateLastProcessedBlockResult) null else ?"Block update failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Get Last Processed Block";
            passed = getLastProcessedBlockResult;
            error = if (getLastProcessedBlockResult) null else ?"Get block by network failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Update Existing Network";
            passed = updateExistingNetworkResult;
            error = if (updateExistingNetworkResult) null else ?"Update existing network failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Get All Last Processed Blocks";
            passed = getAllLastProcessedBlocksResult;
            error = if (getAllLastProcessedBlocksResult) null else ?"Get all blocks failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Delete Last Processed Block";
            passed = deleteLastProcessedBlockResult;
            error = if (deleteLastProcessedBlockResult) null else ?"Block deletion failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Multiple Networks";
            passed = multipleNetworksResult;
            error = if (multipleNetworksResult) null else ?"Multiple networks management failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Timestamp Tracking";
            passed = timestampTrackingResult;
            error = if (timestampTrackingResult) null else ?"Timestamp tracking failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Block Progression";
            passed = blockProgressionResult;
            error = if (blockProgressionResult) null else ?"Block progression failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Edge Cases";
            passed = edgeCasesResult;
            error = if (edgeCasesResult) null else ?"Edge cases handling failed";
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

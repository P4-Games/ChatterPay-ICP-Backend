/**
 * @fileoverview ChatterPay Blockchains Canister Tests - Comprehensive blockchain network testing suite
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
 * Blockchains Canister Test Suite
 * 
 * Comprehensive testing for the BlockchainStorage canister including
 * CRUD operations, network configuration, and contract management.
 */
persistent actor BlockchainsTest {
    private transient var blockchainStorage: ?BlockchainStorage = null;

    // Mock BlockchainStorage actor for testing
    private type BlockchainStorage = actor {
        createBlockchain: shared (name: Text, chain_id: Nat, rpc: Text, logo: Text, explorer: Text, scan_apikey: Text, contracts: Types.Contracts) -> async Nat;
        getBlockchain: shared query (id: Nat) -> async ?Types.Blockchain;
        getBlockchainByChainId: shared query (chainId: Nat) -> async ?Types.Blockchain;
        updateBlockchain: shared (id: Nat, rpc: Text, explorer: Text, scan_apikey: Text, contracts: Types.Contracts) -> async Bool;
        deleteBlockchain: shared (id: Nat) -> async Bool;
        getAllBlockchains: shared query () -> async [Types.Blockchain];
    };

    public func setupTestCanister(canisterId: Text): async () {
        blockchainStorage := ?(actor(canisterId): BlockchainStorage);
    };

    /**
     * Generate mock contracts for testing
     */
    private func generateMockContracts(): Types.Contracts {
        {
            entryPoint = ?"0x1111111111111111111111111111111111111111";
            factoryAddress = ?"0x2222222222222222222222222222222222222222";
            chatterPayAddress = ?"0x3333333333333333333333333333333333333333";
            chatterPayBeaconAddress = ?"0x4444444444444444444444444444444444444444";
            chatterNFTAddress = ?"0x5555555555555555555555555555555555555555";
            paymasterAddress = ?"0x6666666666666666666666666666666666666666";
        }
    };

    /**
     * Test blockchain creation functionality
     */
    public func testCreateBlockchain(): async Bool {
        try {
            switch (blockchainStorage) {
                case (?storage) {
                    let contracts = generateMockContracts();
                    let _blockchainId = await storage.createBlockchain(
                        "Test Network",
                        12345, // Test chain ID
                        "https://test-rpc.example.com",
                        "https://example.com/test-logo.png",
                        "https://test-explorer.example.com",
                        "test_api_key_12345",
                        contracts
                    );
                    _blockchainId >= 0
                };
                case (null) {
                    Debug.print("Error: BlockchainStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testCreateBlockchain: " # Error.message(e));
            false
        }
    };

    /**
     * Test blockchain retrieval by ID
     */
    public func testGetBlockchain(): async Bool {
        try {
            switch (blockchainStorage) {
                case (?storage) {
                    let contracts = generateMockContracts();
                    let _blockchainId = await storage.createBlockchain(
                        "Retrieve Test Network",
                        54321,
                        "https://retrieve-test-rpc.example.com",
                        "https://example.com/retrieve-logo.png",
                        "https://retrieve-explorer.example.com",
                        "retrieve_api_key",
                        contracts
                    );

                    let retrievedBlockchain = await storage.getBlockchain(_blockchainId);
                    switch (retrievedBlockchain) {
                        case (?blockchain) {
                            blockchain.id == _blockchainId and 
                            blockchain.name == "Retrieve Test Network" and
                            blockchain.chain_id == 54321 and
                            blockchain.rpc == "https://retrieve-test-rpc.example.com"
                        };
                        case (null) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: BlockchainStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testGetBlockchain: " # Error.message(e));
            false
        }
    };

    /**
     * Test blockchain retrieval by chain ID
     */
    public func testGetBlockchainByChainId(): async Bool {
        try {
            switch (blockchainStorage) {
                case (?storage) {
                    let testChainId: Nat = 98765;
                    let contracts = generateMockContracts();
                    
                    let _blockchainId = await storage.createBlockchain(
                        "Chain ID Test Network",
                        testChainId,
                        "https://chainid-test-rpc.example.com",
                        "https://example.com/chainid-logo.png",
                        "https://chainid-explorer.example.com",
                        "chainid_api_key",
                        contracts
                    );

                    let retrievedBlockchain = await storage.getBlockchainByChainId(testChainId);
                    switch (retrievedBlockchain) {
                        case (?blockchain) {
                            blockchain.chain_id == testChainId and 
                            blockchain.name == "Chain ID Test Network"
                        };
                        case (null) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: BlockchainStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testGetBlockchainByChainId: " # Error.message(e));
            false
        }
    };

    /**
     * Test blockchain update functionality
     */
    public func testUpdateBlockchain(): async Bool {
        try {
            switch (blockchainStorage) {
                case (?storage) {
                    let contracts = generateMockContracts();
                    let _blockchainId = await storage.createBlockchain(
                        "Update Test Network",
                        11111,
                        "https://original-rpc.example.com",
                        "https://example.com/original-logo.png",
                        "https://original-explorer.example.com",
                        "original_api_key",
                        contracts
                    );

                    // Create updated contracts
                    let updatedContracts: Types.Contracts = {
                        entryPoint = ?"0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
                        factoryAddress = ?"0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB";
                        chatterPayAddress = ?"0xCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC";
                        chatterPayBeaconAddress = ?"0xDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD";
                        chatterNFTAddress = ?"0xEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE";
                        paymasterAddress = ?"0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
                    };

                    let updateResult = await storage.updateBlockchain(
                        _blockchainId,
                        "https://updated-rpc.example.com", // Updated RPC
                        "https://updated-explorer.example.com", // Updated explorer
                        "updated_api_key", // Updated API key
                        updatedContracts // Updated contracts
                    );

                    if (updateResult) {
                        // Verify the update
                        let updatedBlockchain = await storage.getBlockchain(_blockchainId);
                        switch (updatedBlockchain) {
                            case (?blockchain) {
                                blockchain.rpc == "https://updated-rpc.example.com" and
                                blockchain.explorer == "https://updated-explorer.example.com" and
                                blockchain.scan_apikey == "updated_api_key"
                            };
                            case (null) { false };
                        }
                    } else {
                        false
                    }
                };
                case (null) {
                    Debug.print("Error: BlockchainStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testUpdateBlockchain: " # Error.message(e));
            false
        }
    };

    /**
     * Test blockchain deletion functionality
     */
    public func testDeleteBlockchain(): async Bool {
        try {
            switch (blockchainStorage) {
                case (?storage) {
                    let contracts = generateMockContracts();
                    let _blockchainId = await storage.createBlockchain(
                        "Delete Test Network",
                        22222,
                        "https://delete-test-rpc.example.com",
                        "https://example.com/delete-logo.png",
                        "https://delete-explorer.example.com",
                        "delete_api_key",
                        contracts
                    );

                    // Verify blockchain exists
                    let blockchainExists = await storage.getBlockchain(_blockchainId);
                    switch (blockchainExists) {
                        case (?_) {
                            // Delete the blockchain
                            let deleteResult = await storage.deleteBlockchain(_blockchainId);
                            
                            if (deleteResult) {
                                // Verify blockchain is deleted
                                let deletedBlockchain = await storage.getBlockchain(_blockchainId);
                                switch (deletedBlockchain) {
                                    case (null) { true }; // Should be null after deletion
                                    case (?_) { false }; // Should not exist
                                }
                            } else {
                                false
                            }
                        };
                        case (null) { false }; // Blockchain should exist before deletion
                    }
                };
                case (null) {
                    Debug.print("Error: BlockchainStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testDeleteBlockchain: " # Error.message(e));
            false
        }
    };

    /**
     * Test getting all blockchains
     */
    public func testGetAllBlockchains(): async Bool {
        try {
            switch (blockchainStorage) {
                case (?storage) {
                    let initialBlockchains = await storage.getAllBlockchains();
                    let initialCount = initialBlockchains.size();

                    // Create a new blockchain
                    let contracts = generateMockContracts();
                    let _blockchainId = await storage.createBlockchain(
                        "All Blockchains Test",
                        33333,
                        "https://all-test-rpc.example.com",
                        "https://example.com/all-logo.png",
                        "https://all-explorer.example.com",
                        "all_api_key",
                        contracts
                    );

                    let newBlockchains = await storage.getAllBlockchains();
                    newBlockchains.size() == initialCount + 1
                };
                case (null) {
                    Debug.print("Error: BlockchainStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testGetAllBlockchains: " # Error.message(e));
            false
        }
    };

    /**
     * Test contract address validation
     */
    public func testContractValidation(): async Bool {
        try {
            switch (blockchainStorage) {
                case (?storage) {
                    // Test with minimal contracts (some optional fields null)
                    let minimalContracts: Types.Contracts = {
                        entryPoint = ?"0x1111111111111111111111111111111111111111";
                        factoryAddress = null; // Optional field
                        chatterPayAddress = ?"0x3333333333333333333333333333333333333333";
                        chatterPayBeaconAddress = null; // Optional field
                        chatterNFTAddress = null; // Optional field
                        paymasterAddress = ?"0x6666666666666666666666666666666666666666";
                    };

                    let _blockchainId = await storage.createBlockchain(
                        "Minimal Contracts Test",
                        44444,
                        "https://minimal-rpc.example.com",
                        "https://example.com/minimal-logo.png",
                        "https://minimal-explorer.example.com",
                        "minimal_api_key",
                        minimalContracts
                    );

                    let retrievedBlockchain = await storage.getBlockchain(_blockchainId);
                    switch (retrievedBlockchain) {
                        case (?blockchain) {
                            switch (blockchain.contracts.entryPoint, blockchain.contracts.factoryAddress) {
                                case (?entryPoint, null) {
                                    entryPoint == "0x1111111111111111111111111111111111111111"
                                };
                                case (_, _) { false };
                            }
                        };
                        case (null) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: BlockchainStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testContractValidation: " # Error.message(e));
            false
        }
    };

    /**
     * Test known blockchain networks
     */
    public func testKnownNetworks(): async Bool {
        try {
            switch (blockchainStorage) {
                case (?storage) {
                    let contracts = generateMockContracts();
                    
                    // Test Ethereum mainnet
                    let _ethId = await storage.createBlockchain(
                        "Ethereum",
                        1,
                        "https://ethereum.publicnode.com",
                        "https://ethereum.org/logo.png",
                        "https://etherscan.io",
                        "eth_api_key",
                        contracts
                    );

                    // Test Polygon
                    let _polygonId = await storage.createBlockchain(
                        "Polygon",
                        137,
                        "https://polygon-rpc.com",
                        "https://polygon.technology/logo.png",
                        "https://polygonscan.com",
                        "polygon_api_key",
                        contracts
                    );

                    // Verify both networks were created
                    let ethNetwork = await storage.getBlockchainByChainId(1);
                    let polygonNetwork = await storage.getBlockchainByChainId(137);

                    switch (ethNetwork, polygonNetwork) {
                        case (?eth, ?polygon) {
                            eth.name == "Ethereum" and 
                            polygon.name == "Polygon" and
                            eth.chain_id == 1 and 
                            polygon.chain_id == 137
                        };
                        case (_, _) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: BlockchainStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testKnownNetworks: " # Error.message(e));
            false
        }
    };

    /**
     * Test error handling for invalid operations
     */
    public func testErrorHandling(): async Bool {
        try {
            switch (blockchainStorage) {
                case (?storage) {
                    // Test getting non-existent blockchain
                    let nonExistentBlockchain = await storage.getBlockchain(99999);
                    
                    // Test getting by non-existent chain ID
                    let nonExistentChain = await storage.getBlockchainByChainId(99999);
                    
                    // Test updating non-existent blockchain
                    let contracts = generateMockContracts();
                    let updateResult = await storage.updateBlockchain(
                        99999,
                        "https://non-existent.example.com",
                        "https://non-existent-explorer.example.com",
                        "non_existent_key",
                        contracts
                    );
                    
                    // Test deleting non-existent blockchain
                    let deleteResult = await storage.deleteBlockchain(99999);

                    // All operations should handle non-existent blockchains gracefully
                    switch (nonExistentBlockchain, nonExistentChain) {
                        case (null, null) { not updateResult and not deleteResult };
                        case (_, _) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: BlockchainStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testErrorHandling: " # Error.message(e));
            false
        }
    };

    /**
     * Run all blockchain tests
     */
    public func runAllTests(canisterId: Text): async Text {
        await setupTestCanister(canisterId);

        Debug.print("\n🧪 Starting Blockchains Canister Tests...\n");

        // Run tests and collect results
        let createBlockchainResult = await testCreateBlockchain();
        let getBlockchainResult = await testGetBlockchain();
        let getBlockchainByChainIdResult = await testGetBlockchainByChainId();
        let updateBlockchainResult = await testUpdateBlockchain();
        let deleteBlockchainResult = await testDeleteBlockchain();
        let getAllBlockchainsResult = await testGetAllBlockchains();
        let contractValidationResult = await testContractValidation();
        let knownNetworksResult = await testKnownNetworks();
        let errorHandlingResult = await testErrorHandling();

        let buffer = Buffer.Buffer<TestUtils.TestResult>(0);
        
        buffer.add({
            name = "Create Blockchain";
            passed = createBlockchainResult;
            error = if (createBlockchainResult) null else ?"Blockchain creation failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Get Blockchain";
            passed = getBlockchainResult;
            error = if (getBlockchainResult) null else ?"Get blockchain by ID failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Get Blockchain by Chain ID";
            passed = getBlockchainByChainIdResult;
            error = if (getBlockchainByChainIdResult) null else ?"Get blockchain by chain ID failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Update Blockchain";
            passed = updateBlockchainResult;
            error = if (updateBlockchainResult) null else ?"Blockchain update failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Delete Blockchain";
            passed = deleteBlockchainResult;
            error = if (deleteBlockchainResult) null else ?"Blockchain deletion failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Get All Blockchains";
            passed = getAllBlockchainsResult;
            error = if (getAllBlockchainsResult) null else ?"Get all blockchains failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Contract Validation";
            passed = contractValidationResult;
            error = if (contractValidationResult) null else ?"Contract validation failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Known Networks";
            passed = knownNetworksResult;
            error = if (knownNetworksResult) null else ?"Known networks test failed";
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

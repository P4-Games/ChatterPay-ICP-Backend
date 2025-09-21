/**
 * @fileoverview ChatterPay Tokens Canister Tests - Comprehensive token management testing suite
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
 * Tokens Canister Test Suite
 * 
 * Comprehensive testing for the TokenStorage canister including
 * CRUD operations, multi-chain support, and token management.
 */
persistent actor TokensTest {
    private transient var tokenStorage: ?TokenStorage = null;

    // Mock TokenStorage actor for testing
    private type TokenStorage = actor {
        createToken: shared (name: Text, chain_id: Nat, decimals: Nat, address: Text, logo: ?Text, symbol: Text) -> async Nat;
        getToken: shared query (id: Nat) -> async ?Types.Token;
        getTokenByAddress: shared query (address: Text) -> async ?Types.Token;
        getTokensByChainId: shared query (chainId: Nat) -> async [Types.Token];
        updateToken: shared (id: Nat, name: Text, decimals: Nat, logo: ?Text, symbol: Text) -> async Bool;
        deleteToken: shared (id: Nat) -> async Bool;
        getAllTokens: shared query () -> async [Types.Token];
    };

    public func setupTestCanister(canisterId: Text): async () {
        tokenStorage := ?(actor(canisterId): TokenStorage);
    };

    /**
     * Test token creation functionality
     */
    public func testCreateToken(): async Bool {
        try {
            switch (tokenStorage) {
                case (?storage) {
                    let tokenId = await storage.createToken(
                        "Test Token",
                        1, // Ethereum mainnet
                        18,
                        "0x1234567890123456789012345678901234567890",
                        ?"https://example.com/token-logo.png",
                        "TEST"
                    );
                    tokenId >= 0
                };
                case (null) {
                    Debug.print("Error: TokenStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testCreateToken: " # Error.message(e));
            false
        }
    };

    /**
     * Test token retrieval by ID
     */
    public func testGetToken(): async Bool {
        try {
            switch (tokenStorage) {
                case (?storage) {
                    let tokenId = await storage.createToken(
                        "Retrieve Test Token",
                        137, // Polygon
                        6,
                        "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
                        ?"https://example.com/wbtc-logo.png",
                        "WBTC"
                    );

                    let retrievedToken = await storage.getToken(tokenId);
                    switch (retrievedToken) {
                        case (?token) {
                            token.id == tokenId and 
                            token.name == "Retrieve Test Token" and
                            token.symbol == "WBTC" and
                            token.decimals == 6
                        };
                        case (null) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: TokenStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testGetToken: " # Error.message(e));
            false
        }
    };

    /**
     * Test token retrieval by contract address
     */
    public func testGetTokenByAddress(): async Bool {
        try {
            switch (tokenStorage) {
                case (?storage) {
                    let testAddress = "0xA0b86a33E6417c7c4d8A2e1d0B1f2Ac5B3C3B6F0";
                    let _tokenId = await storage.createToken(
                        "Address Test Token",
                        56, // BSC
                        18,
                        testAddress,
                        ?"https://example.com/bsc-token-logo.png",
                        "ADDR"
                    );

                    let retrievedToken = await storage.getTokenByAddress(testAddress);
                    switch (retrievedToken) {
                        case (?token) {
                            token.address == testAddress and 
                            token.name == "Address Test Token" and
                            token.chain_id == 56
                        };
                        case (null) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: TokenStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testGetTokenByAddress: " # Error.message(e));
            false
        }
    };

    /**
     * Test getting tokens by chain ID
     */
    public func testGetTokensByChainId(): async Bool {
        try {
            switch (tokenStorage) {
                case (?storage) {
                    let testChainId: Nat = 421614; // Arbitrum Sepolia
                    
                    // Create multiple tokens for the same chain
                    let tokenId1 = await storage.createToken(
                        "Chain Test Token 1",
                        testChainId,
                        18,
                        "0x1111111111111111111111111111111111111111",
                        null,
                        "CTT1"
                    );

                    let tokenId2 = await storage.createToken(
                        "Chain Test Token 2",
                        testChainId,
                        6,
                        "0x2222222222222222222222222222222222222222",
                        null,
                        "CTT2"
                    );

                    let chainTokens = await storage.getTokensByChainId(testChainId);
                    
                    // Should have at least 2 tokens for this chain
                    var foundToken1 = false;
                    var foundToken2 = false;
                    
                    for (token in chainTokens.vals()) {
                        if (token.id == tokenId1) { foundToken1 := true };
                        if (token.id == tokenId2) { foundToken2 := true };
                    };
                    
                    foundToken1 and foundToken2
                };
                case (null) {
                    Debug.print("Error: TokenStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testGetTokensByChainId: " # Error.message(e));
            false
        }
    };

    /**
     * Test token update functionality
     */
    public func testUpdateToken(): async Bool {
        try {
            switch (tokenStorage) {
                case (?storage) {
                    let tokenId = await storage.createToken(
                        "Update Test Token",
                        1,
                        18,
                        "0x3333333333333333333333333333333333333333",
                        ?"https://example.com/original-logo.png",
                        "UPD"
                    );

                    let updateResult = await storage.updateToken(
                        tokenId,
                        "Updated Test Token",
                        8, // Changed decimals
                        ?"https://example.com/updated-logo.png", // Changed logo
                        "UPDT" // Changed symbol
                    );

                    if (updateResult) {
                        // Verify the update
                        let updatedToken = await storage.getToken(tokenId);
                        switch (updatedToken) {
                            case (?token) {
                                token.name == "Updated Test Token" and
                                token.decimals == 8 and
                                token.symbol == "UPDT"
                            };
                            case (null) { false };
                        }
                    } else {
                        false
                    }
                };
                case (null) {
                    Debug.print("Error: TokenStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testUpdateToken: " # Error.message(e));
            false
        }
    };

    /**
     * Test token deletion functionality
     */
    public func testDeleteToken(): async Bool {
        try {
            switch (tokenStorage) {
                case (?storage) {
                    let tokenId = await storage.createToken(
                        "Delete Test Token",
                        1,
                        18,
                        "0x4444444444444444444444444444444444444444",
                        null,
                        "DEL"
                    );

                    // Verify token exists
                    let tokenExists = await storage.getToken(tokenId);
                    switch (tokenExists) {
                        case (?_) {
                            // Delete the token
                            let deleteResult = await storage.deleteToken(tokenId);
                            
                            if (deleteResult) {
                                // Verify token is deleted
                                let deletedToken = await storage.getToken(tokenId);
                                switch (deletedToken) {
                                    case (null) { true }; // Should be null after deletion
                                    case (?_) { false }; // Should not exist
                                }
                            } else {
                                false
                            }
                        };
                        case (null) { false }; // Token should exist before deletion
                    }
                };
                case (null) {
                    Debug.print("Error: TokenStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testDeleteToken: " # Error.message(e));
            false
        }
    };

    /**
     * Test getting all tokens
     */
    public func testGetAllTokens(): async Bool {
        try {
            switch (tokenStorage) {
                case (?storage) {
                    let initialTokens = await storage.getAllTokens();
                    let initialCount = initialTokens.size();

                    // Create a new token
                    let _tokenId = await storage.createToken(
                        "All Tokens Test",
                        1,
                        18,
                        "0x5555555555555555555555555555555555555555",
                        null,
                        "ALL"
                    );

                    let newTokens = await storage.getAllTokens();
                    newTokens.size() == initialCount + 1
                };
                case (null) {
                    Debug.print("Error: TokenStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testGetAllTokens: " # Error.message(e));
            false
        }
    };

    /**
     * Test token validation with edge cases
     */
    public func testTokenValidation(): async Bool {
        try {
            switch (tokenStorage) {
                case (?storage) {
                    // Test with different decimal values
                    let token1Id = await storage.createToken(
                        "High Decimals Token",
                        1,
                        18, // Standard ERC-20 decimals
                        "0x6666666666666666666666666666666666666666",
                        null,
                        "HD18"
                    );

                    let token2Id = await storage.createToken(
                        "Low Decimals Token",
                        1,
                        0, // No decimals
                        "0x7777777777777777777777777777777777777777",
                        null,
                        "LD0"
                    );

                    // Verify both tokens were created successfully
                    let highDecimalToken = await storage.getToken(token1Id);
                    let lowDecimalToken = await storage.getToken(token2Id);

                    switch (highDecimalToken, lowDecimalToken) {
                        case (?hdt, ?ldt) {
                            hdt.decimals == 18 and ldt.decimals == 0
                        };
                        case (_, _) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: TokenStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testTokenValidation: " # Error.message(e));
            false
        }
    };

    /**
     * Test error handling for invalid operations
     */
    public func testErrorHandling(): async Bool {
        try {
            switch (tokenStorage) {
                case (?storage) {
                    // Test getting non-existent token
                    let nonExistentToken = await storage.getToken(99999);
                    
                    // Test updating non-existent token
                    let updateResult = await storage.updateToken(
                        99999,
                        "Non-existent Token",
                        18,
                        null,
                        "NEX"
                    );
                    
                    // Test deleting non-existent token
                    let deleteResult = await storage.deleteToken(99999);

                    // All operations should handle non-existent tokens gracefully
                    switch (nonExistentToken) {
                        case (null) { not updateResult and not deleteResult };
                        case (?_) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: TokenStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testErrorHandling: " # Error.message(e));
            false
        }
    };

    /**
     * Run all token tests
     */
    public func runAllTests(canisterId: Text): async Text {
        await setupTestCanister(canisterId);

        Debug.print("\n🧪 Starting Tokens Canister Tests...\n");

        // Run tests and collect results
        let createTokenResult = await testCreateToken();
        let getTokenResult = await testGetToken();
        let getTokenByAddressResult = await testGetTokenByAddress();
        let getTokensByChainIdResult = await testGetTokensByChainId();
        let updateTokenResult = await testUpdateToken();
        let deleteTokenResult = await testDeleteToken();
        let getAllTokensResult = await testGetAllTokens();
        let tokenValidationResult = await testTokenValidation();
        let errorHandlingResult = await testErrorHandling();

        let buffer = Buffer.Buffer<TestUtils.TestResult>(0);
        
        buffer.add({
            name = "Create Token";
            passed = createTokenResult;
            error = if (createTokenResult) null else ?"Token creation failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Get Token";
            passed = getTokenResult;
            error = if (getTokenResult) null else ?"Get token by ID failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Get Token by Address";
            passed = getTokenByAddressResult;
            error = if (getTokenByAddressResult) null else ?"Get token by address failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Get Tokens by Chain ID";
            passed = getTokensByChainIdResult;
            error = if (getTokensByChainIdResult) null else ?"Get tokens by chain ID failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Update Token";
            passed = updateTokenResult;
            error = if (updateTokenResult) null else ?"Token update failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Delete Token";
            passed = deleteTokenResult;
            error = if (deleteTokenResult) null else ?"Token deletion failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Get All Tokens";
            passed = getAllTokensResult;
            error = if (getAllTokensResult) null else ?"Get all tokens failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Token Validation";
            passed = tokenValidationResult;
            error = if (tokenValidationResult) null else ?"Token validation failed";
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

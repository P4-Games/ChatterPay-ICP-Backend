/**
 * @fileoverview ChatterPay Main Test Runner - Comprehensive testing orchestration
 * @author ChatterPay Team
 */

import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import TestUtils "./test_utils";
import UsersTest "./users_test";
import TransactionsTest "./transactions_test";
import TokensTest "./tokens_test";
import BlockchainsTest "./blockchains_test";
import NFTsTest "./nfts_test";
import NFTServiceTest "./nft_service_test";
import LastProcessedBlocksTest "./last_processed_blocks_test";

/**
 * Main Test Runner
 * 
 * Orchestrates comprehensive testing across all ChatterPay canisters.
 * Provides centralized test execution, reporting, and result aggregation.
 */
actor MainTestRunner {
    private var usersCanisterId: ?Text = null;
    private var transactionsCanisterId: ?Text = null;
    private var tokensCanisterId: ?Text = null;
    private var blockchainsCanisterId: ?Text = null;
    private var nftsCanisterId: ?Text = null;
    private var nftServiceCanisterId: ?Text = null;
    private var lastProcessedBlocksCanisterId: ?Text = null;

    /**
     * Set up test configuration with canister IDs
     */
    public shared func setupTestConfig(
        usersId: Text,
        transactionsId: Text,
        tokensId: Text,
        blockchainsId: Text,
        nftsId: Text,
        nftServiceId: Text,
        lastProcessedBlocksId: Text
    ): async () {
        usersCanisterId := ?usersId;
        transactionsCanisterId := ?transactionsId;
        tokensCanisterId := ?tokensId;
        blockchainsCanisterId := ?blockchainsId;
        nftsCanisterId := ?nftsId;
        nftServiceCanisterId := ?nftServiceId;
        lastProcessedBlocksCanisterId := ?lastProcessedBlocksId;
        Debug.print("✅ Test configuration set up successfully for all canisters");
    };

    /**
     * Run all canister tests
     */
    public shared func runAllCanisterTests(): async Text {
        switch (
            usersCanisterId, 
            transactionsCanisterId, 
            tokensCanisterId, 
            blockchainsCanisterId, 
            nftsCanisterId, 
            lastProcessedBlocksCanisterId
        ) {
            case (?usersId, ?transactionsId, ?tokensId, ?blockchainsId, ?nftsId, ?lastProcessedBlocksId) {
                Debug.print("\n🧪 Starting ChatterPay Comprehensive Testing Suite...\n");
                Debug.print("=" # Text.repeat("=", 80) # "\n");
                
                let startTime = Time.now();
                let buffer = Buffer.Buffer<TestUtils.TestResult>(0);
                
                // Run users tests
                let usersTest = UsersTest.UsersTest();
                let usersReport = await usersTest.runAllTests(usersId);
                let usersResult: TestUtils.TestResult = {
                    name = "Users Canister Tests";
                    passed = not Text.contains(usersReport, #text "❌ FAIL");
                    error = if (not Text.contains(usersReport, #text "❌ FAIL")) null else ?"Some users tests failed";
                    duration = 0;
                };
                buffer.add(usersResult);
                
                // Run transactions tests
                let transactionsTest = TransactionsTest.TransactionsTest();
                let transactionsReport = await transactionsTest.runAllTests(transactionsId);
                let transactionsResult: TestUtils.TestResult = {
                    name = "Transactions Canister Tests";
                    passed = not Text.contains(transactionsReport, #text "❌ FAIL");
                    error = if (not Text.contains(transactionsReport, #text "❌ FAIL")) null else ?"Some transactions tests failed";
                    duration = 0;
                };
                buffer.add(transactionsResult);
                
                // Run tokens tests
                let tokensTest = TokensTest.TokensTest();
                let tokensReport = await tokensTest.runAllTests(tokensId);
                let tokensResult: TestUtils.TestResult = {
                    name = "Tokens Canister Tests";
                    passed = not Text.contains(tokensReport, #text "❌ FAIL");
                    error = if (not Text.contains(tokensReport, #text "❌ FAIL")) null else ?"Some tokens tests failed";
                    duration = 0;
                };
                buffer.add(tokensResult);
                
                // Run blockchains tests
                let blockchainsTest = BlockchainsTest.BlockchainsTest();
                let blockchainsReport = await blockchainsTest.runAllTests(blockchainsId);
                let blockchainsResult: TestUtils.TestResult = {
                    name = "Blockchains Canister Tests";
                    passed = not Text.contains(blockchainsReport, #text "❌ FAIL");
                    error = if (not Text.contains(blockchainsReport, #text "❌ FAIL")) null else ?"Some blockchains tests failed";
                    duration = 0;
                };
                buffer.add(blockchainsResult);
                
                // Run NFTs tests
                let nftsTest = NFTsTest.NFTsTest();
                let nftsReport = await nftsTest.runAllTests(nftsId);
                let nftsResult: TestUtils.TestResult = {
                    name = "NFTs Canister Tests";
                    passed = not Text.contains(nftsReport, #text "❌ FAIL");
                    error = if (not Text.contains(nftsReport, #text "❌ FAIL")) null else ?"Some NFTs tests failed";
                    duration = 0;
                };
                buffer.add(nftsResult);
                
                // Run NFT Service tests (TypeScript)
                let nftServiceTests = NFTServiceTest.runAllTests();
                var nftServicePassed = true;
                for (result in nftServiceTests.vals()) {
                    if (not result.success) {
                        nftServicePassed := false;
                    };
                };
                let nftServiceResult: TestUtils.TestResult = {
                    name = "NFT Service Tests (TypeScript)";
                    passed = nftServicePassed;
                    error = if (nftServicePassed) null else ?"Some NFT service tests failed";
                    duration = 0;
                };
                buffer.add(nftServiceResult);
                
                // Run last processed blocks tests
                let lastProcessedBlocksTest = LastProcessedBlocksTest.LastProcessedBlocksTest();
                let lastProcessedBlocksReport = await lastProcessedBlocksTest.runAllTests(lastProcessedBlocksId);
                let lastProcessedBlocksResult: TestUtils.TestResult = {
                    name = "Last Processed Blocks Canister Tests";
                    passed = not Text.contains(lastProcessedBlocksReport, #text "❌ FAIL");
                    error = if (not Text.contains(lastProcessedBlocksReport, #text "❌ FAIL")) null else ?"Some last processed blocks tests failed";
                    duration = 0;
                };
                buffer.add(lastProcessedBlocksResult);
                
                let endTime = Time.now();
                let totalDuration = (endTime - startTime) / 1_000_000;
                
                // Generate comprehensive report
                let results = Buffer.toArray(buffer);
                let totalTests = results.size();
                let passedTests = Buffer.toArray(Buffer.filter(results, func(r: TestUtils.TestResult): Bool { r.passed })).size();
                let failedTests = totalTests - passedTests;
                
                var report = "\n" # "=" # Text.repeat("=", 80) # "\n";
                report #= "🎯 CHATTERPAY COMPREHENSIVE TEST REPORT\n";
                report #= "=" # Text.repeat("=", 80) # "\n";
                report #= "Total Canisters Tested: " # Text.repeat(" ", 20) # Nat.toText(totalTests) # "\n";
                report #= "Passed: " # Text.repeat(" ", 32) # Nat.toText(passedTests) # "\n";
                report #= "Failed: " # Text.repeat(" ", 32) # Nat.toText(failedTests) # "\n";
                report #= "Success Rate: " # Text.repeat(" ", 27) # Nat.toText((passedTests * 100) / totalTests) # "%\n";
                report #= "Total Execution Time: " # Text.repeat(" ", 18) # Nat.toText(totalDuration) # "ms\n";
                report #= "\nDetailed Results:\n";
                report #= "-" # Text.repeat("-", 60) # "\n";
                
                for (result in results.vals()) {
                    let status = if (result.passed) "✅ PASS" else "❌ FAIL";
                    let nameLength = Text.size(result.name);
                    let padding = if (nameLength < 40) Text.repeat(" ", 40 - nameLength) else " ";
                    report #= status # " | " # result.name # padding # " (0ms)\n";
                    
                    if (not result.passed) {
                        switch (result.error) {
                            case (?error) {
                                report #= "    ⚠️  Error: " # error # "\n";
                            };
                            case (null) {};
                        };
                    };
                };
                
                report #= "\n" # "=" # Text.repeat("=", 80) # "\n";
                
                // Print summary
                if (passedTests == totalTests) {
                    report #= "🎉 ALL TESTS PASSED! ChatterPay system is ready for deployment.\n";
                } else {
                    report #= "⚠️  SOME TESTS FAILED. Please review the detailed reports above.\n";
                };
                
                report #= "=" # Text.repeat("=", 80) # "\n";
                
                Debug.print(report);
                report
            };
            case (_, _, _, _, _, _) {
                let errorMsg = "❌ Test configuration not set up completely. Please call setupTestConfig with all canister IDs first.";
                Debug.print(errorMsg);
                errorMsg
            };
        }
    };

    /**
     * Run users tests specifically
     */
    public shared func runUsersTests(): async Text {
        switch (usersCanisterId) {
            case (?usersId) {
                let usersTest = UsersTest.UsersTest();
                await usersTest.runAllTests(usersId)
            };
            case (null) {
                "❌ Users canister not configured. Please call setupTestConfig first."
            };
        }
    };

    /**
     * Run transactions tests specifically
     */
    public shared func runTransactionsTests(): async Text {
        switch (transactionsCanisterId) {
            case (?transactionsId) {
                let transactionsTest = TransactionsTest.TransactionsTest();
                await transactionsTest.runAllTests(transactionsId)
            };
            case (null) {
                "❌ Transactions canister not configured. Please call setupTestConfig first."
            };
        }
    };

    /**
     * Run tokens tests specifically
     */
    public shared func runTokensTests(): async Text {
        switch (tokensCanisterId) {
            case (?tokensId) {
                let tokensTest = TokensTest.TokensTest();
                await tokensTest.runAllTests(tokensId)
            };
            case (null) {
                "❌ Tokens canister not configured. Please call setupTestConfig first."
            };
        }
    };

    /**
     * Run blockchains tests specifically
     */
    public shared func runBlockchainsTests(): async Text {
        switch (blockchainsCanisterId) {
            case (?blockchainsId) {
                let blockchainsTest = BlockchainsTest.BlockchainsTest();
                await blockchainsTest.runAllTests(blockchainsId)
            };
            case (null) {
                "❌ Blockchains canister not configured. Please call setupTestConfig first."
            };
        }
    };

    /**
     * Run NFTs tests specifically
     */
    public shared func runNFTsTests(): async Text {
        switch (nftsCanisterId) {
            case (?nftsId) {
                let nftsTest = NFTsTest.NFTsTest();
                await nftsTest.runAllTests(nftsId)
            };
            case (null) {
                "❌ NFTs canister not configured. Please call setupTestConfig first."
            };
        }
    };

    /**
     * Run NFT Service tests specifically (TypeScript)
     */
    public shared func runNFTServiceTests(): async Text {
        Debug.print("🧪 Running NFT Service Tests (TypeScript)...\n");
        let results = NFTServiceTest.runAllTests();
        
        var report = "NFT Service Test Results:\n";
        report #= "-" # Text.repeat("-", 40) # "\n";
        
        var passed = 0;
        var failed = 0;
        
        for (result in results.vals()) {
            let status = if (result.success) "✅ PASS" else "❌ FAIL";
            report #= status # " | " # result.name # "\n";
            if (not result.success) {
                report #= "    ⚠️  " # result.message # "\n";
                failed += 1;
            } else {
                passed += 1;
            };
        };
        
        report #= "\nSummary: " # Nat.toText(passed) # " passed, " # Nat.toText(failed) # " failed\n";
        Debug.print(report);
        report
    };

    /**
     * Run last processed blocks tests specifically
     */
    public shared func runLastProcessedBlocksTests(): async Text {
        switch (lastProcessedBlocksCanisterId) {
            case (?lastProcessedBlocksId) {
                let lastProcessedBlocksTest = LastProcessedBlocksTest.LastProcessedBlocksTest();
                await lastProcessedBlocksTest.runAllTests(lastProcessedBlocksId)
            };
            case (null) {
                "❌ Last processed blocks canister not configured. Please call setupTestConfig first."
            };
        }
    };

    /**
     * Run specific canister tests by name
     */
    public shared func runSpecificCanisterTests(canisterName: Text): async Text {
        switch (canisterName) {
            case ("users") { await runUsersTests() };
            case ("transactions") { await runTransactionsTests() };
            case ("tokens") { await runTokensTests() };
            case ("blockchains") { await runBlockchainsTests() };
            case ("nfts") { await runNFTsTests() };
            case ("nft_service") { await runNFTServiceTests() };
            case ("last_processed_blocks") { await runLastProcessedBlocksTests() };
            case (_) { "❌ Unknown canister name: " # canisterName # ". Available: users, transactions, tokens, blockchains, nfts, nft_service, last_processed_blocks" };
        }
    };

    /**
     * Get test configuration status
     */
    public shared query func getTestConfigStatus(): async Text {
        let usersStatus = switch (usersCanisterId) {
            case (?id) { "✅ Users: " # id };
            case (null) { "❌ Users: Not configured" };
        };
        let transactionsStatus = switch (transactionsCanisterId) {
            case (?id) { "✅ Transactions: " # id };
            case (null) { "❌ Transactions: Not configured" };
        };
        let tokensStatus = switch (tokensCanisterId) {
            case (?id) { "✅ Tokens: " # id };
            case (null) { "❌ Tokens: Not configured" };
        };
        let blockchainsStatus = switch (blockchainsCanisterId) {
            case (?id) { "✅ Blockchains: " # id };
            case (null) { "❌ Blockchains: Not configured" };
        };
        let nftsStatus = switch (nftsCanisterId) {
            case (?id) { "✅ NFTs: " # id };
            case (null) { "❌ NFTs: Not configured" };
        };
        let lastProcessedBlocksStatus = switch (lastProcessedBlocksCanisterId) {
            case (?id) { "✅ Last Processed Blocks: " # id };
            case (null) { "❌ Last Processed Blocks: Not configured" };
        };

        "Test Configuration Status:\n" #
        usersStatus # "\n" #
        transactionsStatus # "\n" #
        tokensStatus # "\n" #
        blockchainsStatus # "\n" #
        nftsStatus # "\n" #
        lastProcessedBlocksStatus
    };

    /**
     * Reset test configuration
     */
    public shared func resetTestConfig(): async Text {
        usersCanisterId := null;
        transactionsCanisterId := null;
        tokensCanisterId := null;
        blockchainsCanisterId := null;
        nftsCanisterId := null;
        lastProcessedBlocksCanisterId := null;
        "✅ All test configurations have been reset."
    };
};
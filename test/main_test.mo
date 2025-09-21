/**
 * @fileoverview ChatterPay Main Test Runner - Comprehensive testing orchestration
 * @author ChatterPay Team
 */

import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import TestUtils "./test_utils";
import UsersTest "./users_test";

/**
 * Main Test Runner
 * 
 * Orchestrates comprehensive testing across all ChatterPay canisters.
 * Provides centralized test execution, reporting, and result aggregation.
 */
actor MainTestRunner {
    private var usersCanisterId: ?Text = null;

    /**
     * Set up test configuration with canister IDs
     */
    public shared func setupTestConfig(usersId: Text): async () {
        usersCanisterId := ?usersId;
        Debug.print("✅ Test configuration set up successfully");
    };

    /**
     * Run all canister tests
     */
    public shared func runAllCanisterTests(): async Text {
        switch (usersCanisterId) {
            case (?usersId) {
                Debug.print("\n🧪 Starting ChatterPay Testing Suite...\n");
                Debug.print("=" # Text.repeat("=", 60) # "\n");
                
                let startTime = Time.now();
                let buffer = Buffer.Buffer<TestUtils.TestResult>(0);
                
                // Run users tests
                let usersTest = UsersTest.UsersTest();
                let usersReport = await usersTest.runAllTests(usersId);
                
                // Create a summary result for users tests
                let usersResult: TestUtils.TestResult = {
                    name = "Users Canister Tests";
                    passed = not Text.contains(usersReport, #text "❌ FAIL");
                    error = if (not Text.contains(usersReport, #text "❌ FAIL")) null else ?"Some users tests failed";
                    duration = 0; // Duration is tracked internally
                };
                buffer.add(usersResult);
                
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
                report #= "-" # Text.repeat("-", 50) # "\n";
                
                for (result in results.vals()) {
                    let status = if (result.passed) "✅ PASS" else "❌ FAIL";
                    let duration = Nat.toText(result.duration);
                    report #= status # " | " # result.name # Text.repeat(" ", 30 - Text.size(result.name)) # " (" # duration # "ms)\n";
                    
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
            case (null) {
                let errorMsg = "❌ Test configuration not set up. Please call setupTestConfig first.";
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
                "❌ Test configuration not set up. Please call setupTestConfig first."
            };
        }
    };

    /**
     * Get test configuration status
     */
    public shared query func getTestConfigStatus(): async Text {
        switch (usersCanisterId) {
            case (?id) {
                "✅ Test configuration is set up with Users Canister ID: " # id
            };
            case (null) {
                "❌ Test configuration is not set up. Please call setupTestConfig first."
            };
        }
    };

    /**
     * Reset test configuration
     */
    public shared func resetTestConfig(): async Text {
        usersCanisterId := null;
        "✅ Test configuration has been reset."
    };
};
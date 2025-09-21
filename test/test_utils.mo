/**
 * @fileoverview ChatterPay Test Utilities - Clean and functional testing utilities
 * @author ChatterPay Team
 */

import Array "mo:base/Array";
import _Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Types "../src/types";

/**
 * Test utilities module for ChatterPay canister testing
 * 
 * Provides common testing functions, mock data generators, and assertion helpers
 * for comprehensive testing across all canisters.
 */
module {
    /** Test result type for tracking test outcomes */
    public type TestResult = {
        name: Text;
        passed: Bool;
        error: ?Text;
        duration: Nat; // in milliseconds
    };

    /** Simple test runner functions */
    public func runTest(name: Text, testFunc: () -> Bool): TestResult {
        let startTime = Time.now();
        let passed = testFunc();
        let endTime = Time.now();
        let duration = Int.abs(endTime - startTime) / 1_000_000; // Convert to milliseconds

        {
            name = name;
            passed = passed;
            error = if (passed) null else ?"Test failed";
            duration = duration;
        }
    };

    public func generateReport(results: [TestResult]): Text {
        let total = results.size();
        let passed = Array.filter(results, func(r: TestResult): Bool { r.passed }).size();
        let failed = total - passed;

        var report = "\n" # "=" # "==================================================\n";
        report #= "TEST REPORT\n";
        report #= "==================================================\n";
        report #= "Total Tests: " # Nat.toText(total) # "\n";
        report #= "Passed: " # Nat.toText(passed) # "\n";
        report #= "Failed: " # Nat.toText(failed) # "\n";
        
        if (total > 0) {
            let successRate = (passed * 100) / total;
            report #= "Success Rate: " # Nat.toText(successRate) # "%\n";
        } else {
            report #= "Success Rate: 0%\n";
        };
        
        report #= "\nDetailed Results:\n";
        report #= "------------------------------\n";

        for (result in results.vals()) {
            let status = if (result.passed) "✅ PASS" else "❌ FAIL";
            report #= status # " | " # result.name # " (" # Nat.toText(result.duration) # "ms)\n";
            if (not result.passed) {
                switch (result.error) {
                    case (?error) {
                        report #= "    Error: " # error # "\n";
                    };
                    case (null) {};
                };
            };
        };

        report #= "\n==================================================\n";
        report
    };

    /** Simple assertion functions */
    public func assertTrue(condition: Bool, message: Text): Bool {
        if (condition) {
            Debug.print("✅ PASS: " # message);
            true
        } else {
            Debug.print("❌ FAIL: " # message);
            false
        }
    };

    public func assertFalse(condition: Bool, message: Text): Bool {
        assertTrue(not condition, message)
    };

    public func assertEqual(actual: Text, expected: Text, message: Text): Bool {
        assertTrue(actual == expected, message # " - Expected: " # expected # ", Actual: " # actual)
    };

    public func assertNotEqual(actual: Text, expected: Text, message: Text): Bool {
        assertTrue(actual != expected, message # " - Values should not be equal")
    };

    public func assertEqualNat(actual: Nat, expected: Nat, message: Text): Bool {
        assertTrue(actual == expected, message # " - Expected: " # Nat.toText(expected) # ", Actual: " # Nat.toText(actual))
    };

    public func assertSome<T>(value: ?T, message: Text): Bool {
        switch (value) {
            case (?_v) {
                Debug.print("✅ PASS: " # message);
                true
            };
            case (null) {
                Debug.print("❌ FAIL: " # message # " - Expected Some, got None");
                false
            };
        }
    };

    public func assertNone<T>(value: ?T, message: Text): Bool {
        switch (value) {
            case (null) {
                Debug.print("✅ PASS: " # message);
                true
            };
            case (?_v) {
                Debug.print("❌ FAIL: " # message # " - Expected None, got Some");
                false
            };
        }
    };

    /** Simple mock data generators */
    public func generateMockUser(): Types.User {
        {
            id = 1;
            name = ?"Test User";
            email = ?"test@chatterpay.com";
            phone_number = "1234567890";
            photo = ?"https://test-image.example.com/image.jpg";
            wallet = "0x1234567890123456789012345678901234567890";
            code = ?123456;
            privateKey = "test_private_key_123";
        }
    };

    public func generateMockTransaction(): Types.Transaction {
        {
            id = 1;
            trx_hash = "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890";
            wallet_from = "0x1234567890123456789012345678901234567890";
            wallet_to = "0x0987654321098765432109876543210987654321";
            type_ = "transfer";
            date = Time.now();
            status = "pending";
            amount = 1.5;
            token = "ETH";
        }
    };

    public func generateMockToken(): Types.Token {
        {
            id = 1;
            name = "Test Token";
            chain_id = 1;
            decimals = 18;
            logo = ?"https://test-image.example.com/token.jpg";
            address = "0x1234567890123456789012345678901234567890";
            symbol = "TEST";
        }
    };
};
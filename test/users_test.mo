/**
 * @fileoverview ChatterPay Users Canister Tests - Clean and functional testing suite
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
 * Users Canister Test Suite
 * 
 * Clean and functional testing for the UserStorage canister.
 */
persistent actor UsersTest {
    private transient var userStorage: ?UserStorage = null;

    // Mock UserStorage actor for testing
    private type UserStorage = actor {
        createUser: shared (name: ?Text, email: ?Text, phone_number: Text, photo: ?Text, wallet: Text, code: ?Nat, privateKey: Text) -> async Nat;
        getUserById: shared query (id: Nat) -> async ?Types.User;
        getUserCount: shared query () -> async Nat;
    };

    public func setupTestCanister(canisterId: Text): async () {
        userStorage := ?(actor(canisterId): UserStorage);
    };

    /**
     * Test user creation functionality
     */
    public func testCreateUser(): async Bool {
        try {
            let user = TestUtils.generateMockUser();
            
            switch (userStorage) {
                case (?storage) {
                    let userId = await storage.createUser(
                        user.name,
                        user.email,
                        user.phone_number,
                        user.photo,
                        user.wallet,
                        user.code,
                        user.privateKey
                    );
                    userId > 0
                };
                case (null) {
                    Debug.print("Error: UserStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testCreateUser: " # Error.message(e));
            false
        }
    };

    /**
     * Test user retrieval by ID
     */
    public func testGetUserById(): async Bool {
        try {
            let user = TestUtils.generateMockUser();
            
            switch (userStorage) {
                case (?storage) {
                    let userId = await storage.createUser(
                        user.name,
                        user.email,
                        user.phone_number,
                        user.photo,
                        user.wallet,
                        user.code,
                        user.privateKey
                    );

                    let retrievedUser = await storage.getUserById(userId);
                    switch (retrievedUser) {
                        case (?u) {
                            u.id == userId and u.phone_number == user.phone_number
                        };
                        case (null) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: UserStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testGetUserById: " # Error.message(e));
            false
        }
    };

    /**
     * Test user count functionality
     */
    public func testGetUserCount(): async Bool {
        try {
            switch (userStorage) {
                case (?storage) {
                    let initialCount = await storage.getUserCount();
                    
                    let user = TestUtils.generateMockUser();
                    let userId = await storage.createUser(
                        user.name,
                        user.email,
                        user.phone_number,
                        user.photo,
                        user.wallet,
                        user.code,
                        user.privateKey
                    );

                    let newCount = await storage.getUserCount();
                    newCount == initialCount + 1
                };
                case (null) {
                    Debug.print("Error: UserStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testGetUserCount: " # Error.message(e));
            false
        }
    };

    /**
     * Test error handling for invalid operations
     */
    public func testErrorHandling(): async Bool {
        try {
            switch (userStorage) {
                case (?storage) {
                    // Test getting non-existent user
                    let nonExistentUser = await storage.getUserById(99999);
                    switch (nonExistentUser) {
                        case (null) { true };
                        case (?_u) { false };
                    }
                };
                case (null) {
                    Debug.print("Error: UserStorage not initialized");
                    false
                };
            }
        } catch (e) {
            Debug.print("Error in testErrorHandling: " # Error.message(e));
            false
        }
    };

    /**
     * Run all user tests
     */
    public func runAllTests(canisterId: Text): async Text {
        await setupTestCanister(canisterId);

        Debug.print("\n🧪 Starting Users Canister Tests...\n");

        // Run tests and collect results
        let createUserResult = await testCreateUser();
        let getUserByIdResult = await testGetUserById();
        let getUserCountResult = await testGetUserCount();
        let errorHandlingResult = await testErrorHandling();

        let buffer = Buffer.Buffer<TestUtils.TestResult>(0);
        
        buffer.add({
            name = "Create User";
            passed = createUserResult;
            error = if (createUserResult) null else ?"User creation failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Get User by ID";
            passed = getUserByIdResult;
            error = if (getUserByIdResult) null else ?"Get user by ID failed";
            duration = 0;
        });
        
        buffer.add({
            name = "Get User Count";
            passed = getUserCountResult;
            error = if (getUserCountResult) null else ?"Get user count failed";
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
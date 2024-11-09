import Array "mo:base/Array";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Types "../types";

actor UserStorage {
    type User = Types.User;

    private stable var nextId: Nat = 0;
    private var users = HashMap.HashMap<Nat, User>(0, Nat.equal, Hash.hash);
    private var phoneToId = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);

    // Create a new user
    public shared func createUser(
        name: ?Text,
        email: ?Text,
        phone_number: Text,
        photo: ?Text,
        wallet: Text,
        code: ?Nat,
        privateKey: Text
    ) : async Nat {
        let user: User = {
            id = nextId;
            name = name;
            email = email;
            phone_number = phone_number;
            photo = photo;
            wallet = wallet;
            code = code;
            privateKey = privateKey;
        };

        users.put(nextId, user);
        phoneToId.put(phone_number, nextId);
        nextId += 1;
        nextId - 1
    };

    // Get user by ID
    public query func getUser(id: Nat) : async ?User {
        users.get(id)
    };

    // Implementation of getWalletByPhoneNumber
    public query func getWalletByPhoneNumber(phoneNumber: Text) : async ?Text {
        switch (phoneToId.get(phoneNumber)) {
            case (null) { null };
            case (?userId) {
                switch (users.get(userId)) {
                    case (null) { null };
                    case (?user) { ?user.wallet };
                };
            };
        }
    };

    // Update user
    public shared func updateUser(
        id: Nat,
        name: ?Text,
        email: ?Text,
        photo: ?Text,
        code: ?Nat
    ) : async Bool {
        switch (users.get(id)) {
            case (null) { false };
            case (?existingUser) {
                let updatedUser: User = {
                    id = existingUser.id;
                    name = name;
                    email = email;
                    phone_number = existingUser.phone_number;
                    photo = photo;
                    wallet = existingUser.wallet;
                    code = code;
                    privateKey = existingUser.privateKey;
                };
                users.put(id, updatedUser);
                true
            };
        }
    };

    // Delete user
    public shared func deleteUser(id: Nat) : async Bool {
        switch (users.get(id)) {
            case (null) { false };
            case (?user) {
                users.delete(id);
                phoneToId.delete(user.phone_number);
                true
            };
        }
    };

    // Get all users
    public query func getAllUsers() : async [User] {
        var userArray: [User] = [];
        for ((id, user) in users.entries()) {
            userArray := Array.append(userArray, [user]);
        };
        userArray
    };
}
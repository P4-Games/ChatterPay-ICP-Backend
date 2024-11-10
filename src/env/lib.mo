import Text "mo:base/Text";
import Constants "constants";

module {
    // Get all canister IDs as a string
    public func getCanisterIds() : Text {
        if (Constants.CURRENT_NETWORK == "ic") {
            Constants.IC_CANISTER_IDS;
        } else {
            Constants.LOCAL_CANISTER_IDS;
        };
    };

    // Get a specific canister ID by name
    public func getCanisterId(name: Text) : Text {
        let ids = if (Constants.CURRENT_NETWORK == "ic") {
            Constants.IC_CANISTER_IDS;
        } else {
            Constants.LOCAL_CANISTER_IDS;
        };

        // Split into key-value pairs
        for (entry in Text.split(ids, #text ";")) {
            switch (Text.split(entry, #text "=")) {
                case (keyValue) {
                    switch(keyValue.next()) {
                        case (?key) {
                            if (key == name) {
                                switch(keyValue.next()) {
                                    case (?value) { return value; };
                                    case (null) {};
                                };
                            };
                        };
                        case (null) {};
                    };
                };
            };
        };
        // Return empty string if not found
        ""
    };

    public func getCurrentNetwork() : Text {
        Constants.CURRENT_NETWORK;
    };
};
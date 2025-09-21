/**
 * @fileoverview ChatterPay Environment Library - Environment management utilities
 * @author ChatterPay Team
 */

import Text "mo:base/Text";
import Constants "constants";

/**
 * Environment management module for ChatterPay
 * 
 * Provides utilities for managing environment-specific configurations
 * including canister IDs and network settings.
 */
module {
    /**
     * Get all canister IDs as a string based on current network
     * @returns String containing all canister IDs for the current network
     */
    public func getCanisterIds() : Text {
        if (Constants.CURRENT_NETWORK == "ic") {
            Constants.IC_CANISTER_IDS;
        } else {
            Constants.LOCAL_CANISTER_IDS;
        };
    };

    /**
     * Get a specific canister ID by name from the current network configuration
     * @param name - Name of the canister to get ID for
     * @returns Canister ID string or default fallback if not found
     */
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
                                    case (?value) { 
                                        if (value != "") {
                                            return value;
                                        };
                                    };
                                    case (null) {};
                                };
                            };
                        };
                        case (null) {};
                    };
                };
            };
        };
        
        // Return fallback canister IDs if not found in constants
        switch (name) {
            case ("evm_service") { "umnn5-yyaaa-aaaak-qtpzq-cai" };
            case ("users") { "u6l2e-uiaaa-aaaak-qtp2q-cai" };
            case ("transactions") { "uzk4q-zqaaa-aaaak-qtp2a-cai" };
            case ("blockchains") { "br5f7-7uaaa-aaaaa-qaaca-cai" };
            case (_) { 
                // This should not happen in production, but provides a safe fallback
                "rdmx6-jaaaa-aaaaa-aaadq-cai" // Anonymous canister ID
            };
        }
    };

    /**
     * Get the current network environment
     * @returns Current network string (ic or local)
     */
    public func getCurrentNetwork() : Text {
        Constants.CURRENT_NETWORK;
    };
};
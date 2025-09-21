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
     * @returns Canister ID string or empty string if not found
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

    /**
     * Get the current network environment
     * @returns Current network string (ic or local)
     */
    public func getCurrentNetwork() : Text {
        Constants.CURRENT_NETWORK;
    };
};
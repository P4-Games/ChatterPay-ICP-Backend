/**
 * @fileoverview ChatterPay Environment Constants - Network and canister configuration
 * @author ChatterPay Team
 */

module {
    /** Current network environment (ic for mainnet, local for development) */
    public let CURRENT_NETWORK = "{{network}}";

    /** Canister IDs for local development environment */
    public let LOCAL_CANISTER_IDS = "{{local_canister_ids}}";
    /** Canister IDs for Internet Computer mainnet */
    public let IC_CANISTER_IDS = "{{ic_canister_ids}}";
};
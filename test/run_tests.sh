#!/bin/bash

# ChatterPay Test Runner Script
# Comprehensive testing suite for all ChatterPay canisters

set -e

echo "🧪 ChatterPay Test Suite Runner"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if dfx is installed
check_dfx() {
    if ! command -v dfx &> /dev/null; then
        print_error "dfx is not installed. Please install dfx first."
        exit 1
    fi
    print_success "dfx is installed"
}

# Check if mops is installed
check_mops() {
    if ! command -v mops &> /dev/null; then
        print_warning "mops is not installed. Installing mops..."
        npm install -g ic-mops
    fi
    print_success "mops is installed"
}

# Deploy main canisters
deploy_main_canisters() {
    print_status "Deploying main ChatterPay canisters..."
    
    # Deploy users canister
    print_status "Deploying users canister..."
    dfx deploy users --argument '()'
    
    # Deploy transactions canister
    print_status "Deploying transactions canister..."
    dfx deploy transactions --argument '()'
    
    # Deploy tokens canister
    print_status "Deploying tokens canister..."
    dfx deploy tokens --argument '()'
    
    # Deploy blockchains canister
    print_status "Deploying blockchains canister..."
    dfx deploy blockchains --argument '()'
    
    # Deploy nfts canister
    print_status "Deploying nfts canister..."
    dfx deploy nfts --argument '()'
    
    # Deploy last_processed_blocks canister
    print_status "Deploying last_processed_blocks canister..."
    dfx deploy last_processed_blocks --argument '()'
    
    print_success "All main canisters deployed successfully"
}

# Deploy test canisters
deploy_test_canisters() {
    print_status "Deploying test canisters..."
    
    # Use test configuration
    dfx deploy --config-file test/dfx_test.json main_test_runner
    dfx deploy --config-file test/dfx_test.json users_test
    dfx deploy --config-file test/dfx_test.json transactions_test
    dfx deploy --config-file test/dfx_test.json tokens_test
    dfx deploy --config-file test/dfx_test.json blockchains_test
    dfx deploy --config-file test/dfx_test.json nfts_test
    dfx deploy --config-file test/dfx_test.json last_processed_blocks_test
    
    print_success "All test canisters deployed successfully"
}

# Get canister IDs
get_canister_ids() {
    print_status "Getting canister IDs..."
    
    USERS_ID=$(dfx canister id users)
    TRANSACTIONS_ID=$(dfx canister id transactions)
    TOKENS_ID=$(dfx canister id tokens)
    BLOCKCHAINS_ID=$(dfx canister id blockchains)
    NFTS_ID=$(dfx canister id nfts)
    LAST_PROCESSED_BLOCKS_ID=$(dfx canister id last_processed_blocks)
    
    print_success "Canister IDs retrieved:"
    echo "  - Users: $USERS_ID"
    echo "  - Transactions: $TRANSACTIONS_ID"
    echo "  - Tokens: $TOKENS_ID"
    echo "  - Blockchains: $BLOCKCHAINS_ID"
    echo "  - NFTs: $NFTS_ID"
    echo "  - Last Processed Blocks: $LAST_PROCESSED_BLOCKS_ID"
}

# Run comprehensive tests
run_tests() {
    print_status "Running comprehensive test suite..."
    
    MAIN_TEST_RUNNER_ID=$(dfx canister --config-file test/dfx_test.json id main_test_runner)
    
    # Setup test configuration
    print_status "Setting up test configuration..."
    dfx canister --config-file test/dfx_test.json call main_test_runner setupTestConfig \
        "(\"$USERS_ID\", \"$TRANSACTIONS_ID\", \"$TOKENS_ID\", \"$BLOCKCHAINS_ID\", \"$NFTS_ID\", \"$LAST_PROCESSED_BLOCKS_ID\")"
    
    # Run all tests
    print_status "Executing comprehensive test suite..."
    dfx canister --config-file test/dfx_test.json call main_test_runner runAllCanisterTests
}

# Run specific canister tests
run_specific_tests() {
    local canister_type=$1
    print_status "Running tests for $canister_type canister..."
    
    MAIN_TEST_RUNNER_ID=$(dfx canister --config-file test/dfx_test.json id main_test_runner)
    
    # Setup test configuration if not already set
    dfx canister --config-file test/dfx_test.json call main_test_runner setupTestConfig \
        "(\"$USERS_ID\", \"$TRANSACTIONS_ID\", \"$TOKENS_ID\", \"$BLOCKCHAINS_ID\", \"$NFTS_ID\", \"$LAST_PROCESSED_BLOCKS_ID\")"
    
    # Run specific tests
    dfx canister --config-file test/dfx_test.json call main_test_runner runSpecificCanisterTests \
        "(\"$canister_type\")"
}

# Clean up test environment
cleanup() {
    print_status "Cleaning up test environment..."
    
    # Stop local replica
    dfx stop
    
    print_success "Test environment cleaned up"
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  all                    Run all tests (default)"
    echo "  users                  Run users canister tests only"
    echo "  transactions           Run transactions canister tests only"
    echo "  tokens                 Run tokens canister tests only"
    echo "  blockchains            Run blockchains canister tests only"
    echo "  nfts                   Run NFTs canister tests only"
    echo "  last_processed_blocks  Run last processed blocks canister tests only"
    echo "  deploy                 Deploy canisters without running tests"
    echo "  cleanup                Clean up test environment"
    echo "  help                   Show this help message"
    echo ""
    echo "Options:"
    echo "  --local            Use local replica (default)"
    echo "  --ic               Use Internet Computer mainnet"
    echo "  --clean            Clean up before running tests"
    echo "  --no-start         Skip starting dfx (assume already running)"
    echo ""
    echo "Examples:"
    echo "  $0                      # Run all tests"
    echo "  $0 users                # Run users tests only"
    echo "  $0 transactions         # Run transactions tests only"
    echo "  $0 tokens               # Run tokens tests only"
    echo "  $0 nfts                 # Run NFTs tests only"
    echo "  $0 --clean all          # Clean up and run all tests"
    echo "  $0 deploy               # Deploy canisters only"
}

# Main execution
main() {
    local command="all"
    local use_local=true
    local clean_first=false
    local skip_start=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --local)
                use_local=true
                shift
                ;;
            --ic)
                use_local=false
                shift
                ;;
            --clean)
                clean_first=true
                shift
                ;;
            --no-start)
                skip_start=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                command=$1
                shift
                ;;
        esac
    done
    
    # Check prerequisites
    check_dfx
    check_mops
    
    # Clean up if requested
    if [ "$clean_first" = true ]; then
        cleanup
    fi
    
    # Start local replica if using local and not skipping
    if [ "$use_local" = true ] && [ "$skip_start" = false ]; then
        print_status "Starting local replica..."
        # Stop any existing dfx instance first
        dfx stop 2>/dev/null || true
        # Wait a moment for cleanup
        sleep 2
        # Start fresh replica
        dfx start --background --clean
        # Wait for replica to be ready
        sleep 10
    elif [ "$skip_start" = true ]; then
        print_status "Skipping dfx start (assuming already running)..."
        # Just verify dfx is running
        if ! dfx ping 2>/dev/null; then
            print_error "dfx is not running! Either start dfx manually or remove --no-start flag"
            exit 1
        fi
        print_success "dfx is running"
    fi
    
    # Deploy main canisters
    deploy_main_canisters
    
    # Deploy test canisters
    deploy_test_canisters
    
    # Get canister IDs
    get_canister_ids
    
    # Execute tests based on command
    case $command in
        all)
            run_tests
            ;;
        users|transactions|tokens|blockchains|nfts|last_processed_blocks)
            run_specific_tests $command
            ;;
        deploy)
            print_success "Canisters deployed successfully. Run tests manually if needed."
            ;;
        cleanup)
            cleanup
            ;;
        help)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
    
    print_success "Test execution completed!"
}

# Run main function with all arguments
main "$@"

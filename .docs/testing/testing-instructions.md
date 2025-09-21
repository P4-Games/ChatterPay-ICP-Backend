# ChatterPay Test Suite

## Description

This is a comprehensive test suite for all ChatterPay ICP Backend canisters. The test suite includes unit tests, integration tests, and regression tests to ensure system quality and reliability.

## Tested Canisters

### 1. Users Canister (`users_test.mo`)
- **Functionality**: User management with security and audit features
- **Tests**:
  - CRUD operations (Create, Read, Update, Delete)
  - Data validation and error handling
  - Security features (rate limiting, audit logs)
  - Search functionality by phone, wallet, and ID

### 2. Transactions Canister (Planned)
- **Functionality**: Multi-chain transaction management
- **Tests** (To be implemented):
  - Transaction creation and management
  - EVM service integration
  - Transaction analytics
  - Transaction state management

### 3. Tokens Canister (Planned)
- **Functionality**: ERC-20 token management
- **Tests** (To be implemented):
  - Token CRUD operations
  - Token metadata management
  - Multi-chain support
  - Contract address validation

### 4. Blockchains Canister (Planned)
- **Functionality**: Blockchain network configuration
- **Tests** (To be implemented):
  - Network configuration management
  - Contract address management
  - Chain ID validation
  - Multiple network support

### 5. NFTs Canister (Planned)
- **Functionality**: NFT and metadata management
- **Tests** (To be implemented):
  - NFT creation and management
  - Metadata handling
  - Copy and original tracking
  - Ownership management

### 6. Last Processed Blocks Canister (Planned)
- **Functionality**: Blockchain synchronization tracking
- **Tests** (To be implemented):
  - Processed block tracking
  - Network-specific management
  - Block number updates
  - Timestamp handling

## File Structure

```
test/
├── dfx_test.json                      # DFX configuration for tests
├── run_tests.sh                       # Execution script (Linux/Mac/WSL)
├── main_test.mo                       # Main test runner
├── test_utils.mo                      # Test utilities and helper functions
├── users_test.mo                      # Users canister tests
├── transactions_test.mo               # Transactions tests (planned)
├── tokens_test.mo                     # Tokens tests (planned)
├── blockchains_test.mo                # Blockchains tests (planned)
├── nfts_test.mo                       # NFTs tests (planned)
└── last_processed_blocks_test.mo      # Last processed blocks tests (planned)
```

**Note**: Currently only `users_test.mo` is implemented. Other test files are planned for future development.

## Installation and Setup

### Prerequisites

1. **Operating System Requirements**:
   - **Linux/Mac**: Native support for DFX
   - **Windows**: Use WSL (Windows Subsystem for Linux) with Ubuntu distribution
     ```powershell
     # Install WSL with Ubuntu
     wsl --install -d Ubuntu
     # Then run all commands inside WSL
     wsl -d Ubuntu
     ```

2. **DFX**: Internet Computer development framework
   ```bash
   # Install DFX (Linux/Mac/WSL only)
   sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh)"
   ```

3. **MOPS**: Motoko package manager
   ```bash
   # Install MOPS
   npm install -g ic-mops
   ```

4. **Node.js**: For development dependencies
   ```bash
   # Check version
   node --version  # >= 16.0.0
   ```

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd ChatterPay-ICP-Backend
   ```

2. **Install dependencies**
   ```bash
   npm install
   mops install
   ```

3. **Set up environment variables**
   ```bash
   cp src/env/constants.mo.template src/env/constants.mo
   # Edit constants.mo with your configurations
   ```

## Running Tests

### Option 1: Automated Script (Recommended)

**Note**: For Windows users, all commands must be run inside WSL (Windows Subsystem for Linux).

#### Using the Test Script (Linux/Mac/WSL)
```bash
# Make script executable
chmod +x test/run_tests.sh

# Run all tests
./test/run_tests.sh

# Run specific canister tests
./test/run_tests.sh users
./test/run_tests.sh transactions    # (when implemented)
./test/run_tests.sh tokens         # (when implemented)

# Clean environment and run all tests
./test/run_tests.sh --clean all

# Deploy canisters only (without running tests)
./test/run_tests.sh deploy

# Show help
./test/run_tests.sh --help
```

### Option 2: Manual Execution

1. **Start local replica**
   ```bash
   dfx start --background
   ```

2. **Deploy main canisters**
   ```bash
   dfx deploy users
   dfx deploy transactions
   dfx deploy tokens
   dfx deploy blockchains
   dfx deploy nfts
   dfx deploy last_processed_blocks
   ```

3. **Deploy test canisters**
   ```bash
   dfx deploy --config-file test/dfx_test.json main_test_runner
   dfx deploy --config-file test/dfx_test.json users_test
   ```

4. **Configure and run tests**
   ```bash
   # Get canister IDs
   USERS_ID=$(dfx canister id users)

   # Setup test configuration (currently only supports users canister)
   dfx canister --config-file test/dfx_test.json call main_test_runner setupTestConfig \
     "\"$USERS_ID\""

   # Run all implemented tests
   dfx canister --config-file test/dfx_test.json call main_test_runner runAllCanisterTests

   # Run only users tests
   dfx canister --config-file test/dfx_test.json call main_test_runner runUsersTests
   ```

## Test Types

### 1. Unit Tests
- Test individual functions and methods
- Input/output validation
- Edge case handling
- Data validation and error handling

### 2. Integration Tests
- Test interactions between canisters
- Complete workflow testing
- Cross-system data validation
- End-to-end functionality

### 3. Regression Tests
- Verify changes don't break existing functionality
- Compatibility testing
- Backward compatibility validation

### 4. Performance Tests (Planned)
- Response time measurement
- Load handling capabilities
- Memory optimization validation

## Test Utilities

The test framework includes several utility modules to support comprehensive testing:

### TestUtils Module (`test_utils.mo`)
- **Mock Data Generators**: Create consistent test data for all canisters
- **Assertion Functions**: Provide validation functions for test results
  - `assertTrue()` - Validate boolean conditions
  - `assertEqual()` - Compare text values
  - `assertEqualNat()` - Compare numeric values
  - `assertSome()` / `assertNone()` - Validate optional values
- **Test Runner**: Handle test execution and report generation
- **Report Generation**: Create formatted test reports with statistics

### Main Test Runner (`main_test.mo`)
- **Test Orchestration**: Coordinate testing across all canisters
- **Configuration Management**: Handle canister ID setup
- **Result Aggregation**: Combine results from multiple test suites
- **Comprehensive Reporting**: Generate detailed test reports

## Interpreting Results

### Test Reports
Test reports include:
- Total number of tests executed
- Number of passed tests
- Number of failed tests
- Success rate percentage
- Execution time in milliseconds
- Detailed results for each test

### Status Codes
- ✅ **PASS**: Test executed successfully
- ❌ **FAIL**: Test failed with errors
- ⚠️ **WARNING**: Test completed with warnings
- 🚀 **INFO**: Informational messages

## Current Test Configuration

The test suite currently uses the following DFX configuration (`test/dfx_test.json`):

## Troubleshooting

### Common Issues

1. **DFX Not Found**
   - **Problem**: `dfx: command not found`
   - **Solution**: Install DFX or use WSL on Windows
   ```bash
   sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh)"
   ```

2. **MOPS Package Issues**
   - **Problem**: Package resolution failures
   - **Solution**: Reinstall MOPS packages
   ```bash
   mops install --force
   ```

3. **Canister Deployment Failures**
   - **Problem**: Canister fails to deploy
   - **Solution**: Clean and restart
   ```bash
   dfx stop
   dfx start --clean --background
   ```

4. **Test Configuration Errors**
   - **Problem**: Test configuration not set up
   - **Solution**: Ensure canister IDs are correctly passed to test runner

### Windows-Specific Issues

1. **WSL Not Working**
   - Enable WSL feature in Windows Features
   - Install Ubuntu distribution: `wsl --install -d Ubuntu`
   - Restart computer if required

2. **File Permissions in WSL**
   ```bash
   chmod +x test/run_tests.sh
   ```

## Development Guidelines

### Adding New Tests

1. **Create Test File**: Create `<canister_name>_test.mo` in the `test/` directory
2. **Update dfx_test.json**: Add the new test canister configuration
3. **Update Main Test Runner**: Import and integrate the new test module
4. **Update Run Script**: Add support for the new test in `run_tests.sh`

### Test Structure Best Practices

- Use descriptive test names
- Include both positive and negative test cases
- Test edge cases and error conditions
- Use mock data generators from `test_utils.mo`
- Follow the existing assertion patterns

## Contributing

When contributing to the test suite:

1. Ensure all tests pass before submitting
2. Add comprehensive tests for new functionality
3. Update documentation when adding new test modules
4. Follow the existing code style and patterns
5. Test on both local replica and testnet when possible
# Contributing to Roundglass

Thank you for your interest in contributing to Roundglass! This document provides guidelines and instructions for contributing to this Chainlink Price Feed utility project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Style Guidelines](#style-guidelines)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)

## Code of Conduct

This project adheres to a standard of respectful and constructive collaboration:

- Be respectful and inclusive in all interactions
- Provide constructive feedback and receive it gracefully
- Focus on what's best for the project and its users
- Show empathy towards other contributors

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Git installed
- Basic understanding of Solidity and Chainlink Price Feeds

### Repository Structure

```
roundglass/
├── src/
│   ├── CPFG.sol           # Main price feed contract
│   └── FeedRegistry.sol   # On-chain feed registry
├── script/                # Deployment scripts
├── test/                  # Test files
├── .github/workflows/     # CI/CD configuration
└── PROJECT_SUMMARY.md     # Project documentation
```

## Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/mxzyy/roundglass.git
   cd roundglass
   ```

2. **Install dependencies**
   ```bash
   forge install
   ```

3. **Build the project**
   ```bash
   forge build
   ```

4. **Run tests**
   ```bash
   forge test
   ```

## How to Contribute

### Reporting Bugs

Before creating a bug report:

1. Check if the issue already exists in the [Issues](https://github.com/mxzyy/roundglass/issues) section
2. Ensure the bug is reproducible with the latest version

When reporting bugs, include:
- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Solidity version and environment details
- Relevant code snippets or transaction hashes

### Suggesting Enhancements

Enhancement suggestions are welcome! Please:
- Use a clear, descriptive title
- Provide detailed explanation of the proposed feature
- Explain why this enhancement would be useful
- Include examples of how it would be used

### Areas for Contribution

We welcome contributions in the following areas:

- **Documentation**: Improve README, add inline comments, create tutorials
- **Testing**: Add test coverage for edge cases and different price feed scenarios
- **Features**: Implement planned modularization (PriceDerivator, StalenessChecker, etc.)
- **Optimization**: Gas optimization for view functions
- **Bug Fixes**: Fix issues in price calculations or feed handling
- **Deployment Scripts**: Create proper deployment scripts for different networks

## Style Guidelines

### Solidity Code Style

- Follow [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- Use `camelCase` for functions and variables
- Use `PascalCase` for contracts and structs
- Use `UPPER_CASE` for constants
- Maximum line length: 120 characters
- Use 4 spaces for indentation

### Documentation

- Use [NatSpec](https://docs.soliditylang.org/en/latest/natspec-format.html) for all public functions
- Document parameters with `@param`
- Document return values with `@return`
- Include `@notice` for user-facing documentation

Example:
```solidity
/// @notice Retrieves the latest price for a given feed
/// @param feedKey The identifier for the price feed (e.g., "ETH/USD")
/// @return price The latest price value
/// @return decimals The number of decimals for the price
function getLatestPrice(string calldata feedKey) 
    external 
    view 
    returns (int256 price, uint8 decimals);
```

### Commit Messages

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit first line to 72 characters
- Reference issues and pull requests where appropriate

## Testing

All contributions must include appropriate tests:

1. **Unit Tests**: Test individual functions in isolation
2. **Integration Tests**: Test interaction between contracts
3. **Fork Tests**: Test against live price feeds (when applicable)

Run tests before submitting:
```bash
forge test -vvv
```

Check test coverage:
```bash
forge coverage
```

## Pull Request Process

1. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Write clear, documented code
   - Add tests for new functionality
   - Update documentation as needed

3. **Commit your changes**
   ```bash
   git add .
   git commit -m "Add feature: description"
   ```

4. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

5. **Submit a Pull Request**
   - Provide a clear description of changes
   - Reference any related issues
   - Ensure all CI checks pass
   - Request review from maintainers

### PR Review Criteria

Pull requests will be reviewed based on:
- Code quality and adherence to style guidelines
- Test coverage and quality
- Documentation completeness
- Security considerations
- Gas efficiency (for on-chain code)

## Questions?

If you have questions about contributing:
- Open a [Discussion](https://github.com/mxzyy/roundglass/discussions) for general questions
- Comment on relevant issues for specific questions
- Tag maintainers if clarification is needed

## Recognition

Contributors will be recognized in our release notes and project documentation.

Thank you for helping make Roundglass better!

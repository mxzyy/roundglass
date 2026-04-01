# Roundglass

A Foundry-based Solidity utility for accessing Chainlink Oracle price feed data. Provides a single entry point (CPFG) to fetch latest prices, batch prices, derived cross-prices, historical data, TWAP, staleness checks, deviation detection, and aggregated dashboard data — all through read-only (`view`) functions.

## Contracts

| Contract | Description |
|---|---|
| `CPFG.sol` | Main utility contract — facade over Chainlink AggregatorV3Interface with 13+ view functions |
| `FeedRegistry.sol` | On-chain registry mapping human-readable pair names (e.g. `"BTC/USD"`) to Chainlink feed addresses |

### CPFG Functions

- `getLatestPrice()` — Fetch latest price from a single feed
- `getBatchPrices()` — Fetch prices from multiple feeds in one call
- `getDerivedPrice()` — Compute cross-prices (e.g. BTC/ETH from BTC/USD and ETH/USD)
- `getHistoricalPrices()` — Fetch last N rounds of historical data
- `getPriceChanges()` — Estimate ~1h, ~24h, ~7d price changes in basis points
- `getTWAP()` — Calculate time-weighted average price over a time window
- `checkStaleness()` — Check if feed data exceeds a max age
- `checkDeviation()` — Check if price deviation exceeds a threshold in bps
- `getDashboardData()` — One-call aggregation for frontend consumption
- `registerFeed()` / `removeFeed()` — Feed registration via FeedRegistry
- `getFeedInfo()` — Resolve pair name to feed address + metadata

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

## Setup

```bash
git clone <repo-url> roundglass
cd roundglass
forge install
```

## Build

```bash
forge build
```

## Test

```bash
forge test
```

Run with verbosity for detailed traces:

```bash
forge test -vvv
```

## Deploy

### Local (Anvil)

Automatically deploys MockPriceFeed contracts with preset BTC/USD, ETH/USD, and LINK/USD data.

```bash
# Start local node
anvil

# Deploy (in another terminal)
forge script script/Deploy.s.sol:DeployCPFG --broadcast --rpc-url http://localhost:8545
```

### Sepolia

Uses real Chainlink price feed addresses on Sepolia testnet.

```bash
forge script script/Deploy.s.sol:DeployCPFG --broadcast --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### Mainnet

```bash
forge script script/Deploy.s.sol:DeployCPFG --broadcast --rpc-url $MAINNET_RPC_URL --private-key $PRIVATE_KEY
```

### Network Configuration

The deploy script uses `HelperConfig.s.sol` to auto-detect the target network:

| Network | Chain ID | Behavior |
|---|---|---|
| Anvil | 31337 | Deploys MockPriceFeed contracts with 10 rounds of historical data |
| Sepolia | 11155111 | Uses Chainlink Sepolia feed addresses |
| Mainnet | 1 | Uses Chainlink Mainnet feed addresses |

## Project Structure

```
roundglass/
├── src/
│   ├── CPFG.sol                  # Main utility contract
│   └── FeedRegistry.sol          # Pair-to-feed registry
├── test/
│   ├── CPFG.t.sol                # Test suite (29 tests)
│   └── mocks/
│       └── MockPriceFeed.sol     # Mock AggregatorV3Interface
├── script/
│   ├── Deploy.s.sol              # Deployment script
│   └── HelperConfig.s.sol        # Network-aware config
├── lib/                          # Dependencies (forge-std, chainlink, openzeppelin)
└── foundry.toml                  # Foundry configuration
```

## Dependencies

- [forge-std](https://github.com/foundry-rs/forge-std) — Foundry testing framework
- [chainlink-brownie-contracts](https://github.com/smartcontractkit/chainlink-brownie-contracts) — Chainlink AggregatorV3Interface
- [openzeppelin-contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) — Ownable access control

## License

MIT

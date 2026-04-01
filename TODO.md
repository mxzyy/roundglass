# TODO - Roundglass (Chainlink Price Feed Getter)

## Project Summary

Foundry-based Solidity project providing a utility contract for fetching prices from Chainlink AggregatorV3.
Consists of 2 contracts: `CPFG.sol` (main logic) and `FeedRegistry.sol` (pair-to-feed registry).

---

## Completed

- [x] **CPFG.sol** — Main contract with features:
  - `getLatestPrice()` — fetch latest price from a single feed
  - `getBatchPrices()` — fetch prices from multiple feeds at once
  - `getDerivedPrice()` — compute cross price (e.g. BTC/ETH from BTC/USD & ETH/USD)
  - `getHistoricalPrices()` — fetch last N rounds from a feed
  - `getPriceChanges()` — estimate price changes 1h/24h/7d (bps)
  - `getTWAP()` — Time-Weighted Average Price
  - `checkStaleness()` — check if feed data is stale
  - `checkDeviation()` — check price deviation from a reference price
  - `getDashboardData()` — bundle all data in one call
  - `registerFeed()` / `removeFeed()` — wrapper to FeedRegistry
  - `getFeedInfo()` — resolve pair name to feed address + metadata
- [x] **FeedRegistry.sol** — On-chain registry with register/update/remove, reverse lookup, enumeration, custom errors & events
- [x] **Dependencies** — forge-std, chainlink-brownie-contracts, openzeppelin-contracts
- [x] **Foundry config** — `foundry.toml` with remappings
- [x] **CI pipeline** — GitHub Actions (fmt, build, test)
- [x] **Test suite** — `test/CPFG.t.sol` with 29 test cases covering all CPFG functions
- [x] **MockPriceFeed** — `test/mocks/MockPriceFeed.sol` implements AggregatorV3Interface, supports multi-round historical data
- [x] **Deploy script** — `script/Deploy.s.sol` deploys FeedRegistry + CPFG + transfers ownership + registers feeds
- [x] **HelperConfig** — `script/HelperConfig.s.sol` network-aware config: auto-deploys MockPriceFeed on Anvil, real Chainlink addresses on Sepolia/Mainnet (BTC/USD, ETH/USD, LINK/USD)
- [x] **README.md** — Full project documentation with setup, deploy, and structure
- [x] **Ownership model** — Deploy script handles `feedRegistry.transferOwnership(address(cpfg))`
- [x] **getFeedInfo() bug** — Fixed, now returns correct feed address

---

## Remaining

### High Priority

- [x] **FeedRegistry unit tests** — `test/FeedRegistry.sol` with 43 test cases covering all functions, access control, events, custom errors, edge cases (shared feed address, case sensitivity, empty string, ownership transfer, full lifecycle)

### Medium Priority

- [ ] **`.env.example`** — Template file for `RPC_URL`, `PRIVATE_KEY`, `ETHERSCAN_API_KEY` so new contributors can onboard quickly
- [ ] **Etherscan verification config** — `foundry.toml` missing `[etherscan]` section, deploy script doesn't support `--verify`
- [ ] **Interaction scripts** — Separate scripts for post-deploy operations (e.g. `RegisterFeed.s.sol` to add feeds without redeploying)
- [ ] **`calldata` optimization** — `CPFG.registerFeed()` and `removeFeed()` use `memory` for string params, could use `calldata` to save gas

### Low Priority

- [ ] **Gas optimization** — `removeFeed` in FeedRegistry iterates entire array (O(n)), expensive with many pairs
- [ ] **Natspec** — `getDashboardData()` missing natspec documentation
- [ ] **Events in CPFG.sol** — `registerFeed()`/`removeFeed()` wrappers don't emit their own events (only rely on registry events)
- [ ] **Interface contract** — No `ICPFG.sol` for external integration
- [ ] **Fork tests** — Tests against mainnet fork to validate real Chainlink feed behavior

chainlink-pricefeed-getter/
├── foundry.toml
├── .env.example
├── remappings.txt
│
├── src/
│   ├── CPFG.sol      ← Main contract (entry point)
│   ├── FeedRegistry.sol                   ← On-chain pair registry (owner-managed)
│   ├── PriceDerivator.sol                 ← Derived price calculation logic
│   ├── StalenessChecker.sol               ← Staleness validation logic
│   ├── HistoricalSampler.sol              ← Historical round sampling + % change calc
│   ├── TWAPCalculator.sol                 ← Time-weighted average price logic
│   └── interfaces/
│       └── ICPFG.sol  ← Interface for main contract
│
├── test/
│   ├── CPFG.t.sol     ← Main integration tests
│   ├── FeedRegistry.t.sol
│   ├── PriceDerivator.t.sol
│   ├── StalenessChecker.t.sol
│   ├── HistoricalSampler.t.sol
│   ├── TWAPCalculator.t.sol
│   └── mocks/
│       └── MockAggregatorV3.sol           ← Mock Chainlink feed untuk unit test
│
├── script/
│   ├── Deploy.s.sol                        ← Deploy main contract + registry
│   └── RegisterFeeds.s.sol                 ← Script buat populate feed registry
│
└── config/
    └── feeds.json                          ← Off-chain reference: pair → address per network
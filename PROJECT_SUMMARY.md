---
## Project Summary (Auto-generated: 2026-03-23)
---

### 1. Overview

**Chainlink Price Feed Getter (CPFG)** adalah utility smart contract project yang menyediakan antarmuka terpusat untuk mengakses data harga dari Chainlink Oracle (AggregatorV3Interface). Project ini dirancang sebagai **read-layer** untuk price feed — semua fungsi utama bersifat `view`, tanpa menyimpan state harga.

| Item | Detail |
|------|--------|
| **Framework** | Foundry (Forge, Cast, Anvil) |
| **Solidity Version** | `^0.8.20` |
| **Dependencies** | `chainlink-brownie-contracts` (AggregatorV3Interface), `openzeppelin-contracts` (Ownable) |
| **License** | MIT |

> [!info] Project Status
> Berdasarkan TREE.md, arsitektur akhir merencanakan modularisasi ke file terpisah (PriceDerivator, StalenessChecker, HistoricalSampler, TWAPCalculator). Saat ini, **semua logic masih terpusat di `CPFG.sol`** sebagai monolith. Deploy script dan test file masih menggunakan template default Foundry (`Counter`).

---

### 2. Architecture

```
┌─────────────────────────────────────────────┐
│                   CPFG.sol                  │
│         (Main Entry Point - Ownable)        │
│                                             │
│  • getLatestPrice()    • getTWAP()          │
│  • getBatchPrices()    • checkDeviation()   │
│  • getDerivedPrice()   • getDashboardData() │
│  • getHistoricalPrices()                    │
│  • getPriceChanges()   • checkStaleness()   │
│  • registerFeed()      • removeFeed()       │
│  • getFeedInfo()                            │
└──────────────┬──────────────────────────────┘
               │ delegates feed lookup
               ▼
┌─────────────────────────────────────────────┐
│            FeedRegistry.sol                 │
│      (On-chain Registry - Ownable)          │
│                                             │
│  mapping(string => address) s_feeds         │
│  • registerFeed()  • updateFeed()           │
│  • removeFeed()    • getFeedAddress()       │
│  • isRegisteredFeed() • getAllRegisteredPairs│
└──────────────┬──────────────────────────────┘
               │ calls
               ▼
      Chainlink AggregatorV3Interface
        (latestRoundData, getRoundData)
```

**Design Patterns:**
- **Ownable (OpenZeppelin)** — Access control pada CPFG dan FeedRegistry, hanya owner yang bisa register/remove feed
- **Registry Pattern** — FeedRegistry memetakan pair name → feed address dengan reverse lookup dan enumeration
- **Immutable Reference** — CPFG menyimpan `FeedRegistry` sebagai `immutable`, di-set saat constructor
- **Facade Pattern** — CPFG bertindak sebagai single entry point yang menggabungkan semua price feed operations

---

### 3. Contract Breakdown

#### 3.1 CPFG.sol (Main Contract)

**State Variables:**
```solidity
FeedRegistry private immutable i_registry;  // Reference ke on-chain registry
uint256 public constant DEFAULT_MAX_AGE = 1 hours;
uint256 public constant MAX_ROUNDS = 100;   // Batas iterasi historical
```

**Structs:**

| Struct | Fields | Purpose |
|--------|--------|---------|
| `PriceData` | `price`, `decimals`, `updatedAt`, `roundId` | Snapshot lengkap satu feed |
| `HistoricalPoint` | `roundId`, `price`, `timestamp` | Satu data point historis |
| `DashboardData` | `latest`, `isStale`, `timeSinceUpdate`, `history`, `change1h/24h/7d` | Bundle data untuk frontend |

**Fungsi Utama:**

| Function | Visibility | Purpose |
|----------|-----------|---------|
| `getLatestPrice(address)` | `public view` | Ambil harga terbaru dari satu feed |
| `getBatchPrices(address[])` | `public view` | Ambil harga dari multiple feeds sekaligus |
| `getDerivedPrice(feedA, feedB, decimals)` | `public view` | Hitung cross-price (e.g. BTC/ETH dari BTC/USD ÷ ETH/USD) |
| `getHistoricalPrices(address, numRounds)` | `public view` | Ambil N round terakhir dari feed |
| `getPriceChanges(address)` | `public view` | Estimasi perubahan harga ~1h, ~24h, ~7d dalam bps |
| `getTWAP(address, timeWindow)` | `public view` | Hitung rata-rata harga tertimbang waktu |
| `checkStaleness(address, maxAge)` | `public view` | Cek apakah feed sudah stale |
| `checkDeviation(address, lastPrice, threshold)` | `public view` | Cek deviasi harga dari reference dalam bps |
| `getDashboardData(address, maxAge, numRounds)` | `public view` | One-call aggregation untuk frontend dashboard |
| `registerFeed(pair, feed)` | `external onlyOwner` | Daftarkan feed baru via registry |
| `removeFeed(pair)` | `external onlyOwner` | Hapus feed dari registry |
| `getFeedInfo(pair)` | `public view` | Resolve pair name → address + metadata |

**Custom Errors:**
```solidity
CPFG__InvalidFeedAddress()
CPFG__InvalidPrice()
CPFG__StalePriceFeed(address feed, uint256 updatedAt, uint256 maxAge)
CPFG__EmptyFeedsArray()
CPFG__ExceedsMaxRounds(uint256 requested, uint256 max)
CPFG__InvalidThreshold()
CPFG__PairNotRegistered(string pair)
CPFG__FeedCallFailed(string pair)
```

#### 3.2 FeedRegistry.sol (Registry Contract)

**State Variables:**
```solidity
mapping(string => address) private s_feeds;          // pair → feed address
mapping(address => bool) private s_registeredFeeds;   // reverse lookup
string[] private s_registeredPairs;                   // enumeration array
```

**Events:**
```solidity
event FeedRegistered(string indexed pair, address indexed feed);
event FeedUpdated(string indexed pair, address indexed oldFeed, address indexed newFeed);
event FeedRemoved(string indexed pair, address indexed feed);
```

**Fungsi Utama:**

| Function | Purpose |
|----------|---------|
| `registerFeed(pair, feed)` | Register pair baru, revert jika sudah ada |
| `updateFeed(pair, newFeed)` | Update feed address untuk pair yang sudah ada |
| `removeFeed(pair)` | Hapus pair (swap-and-pop pada array) |
| `getFeedAddress(pair)` | Lookup pair → address |
| `isRegisteredFeed(pair)` | Cek apakah pair terdaftar |
| `isRegisteredFeedAddress(feed)` | Cek apakah address terdaftar (reverse lookup) |
| `getAllRegisteredPairs()` | Return semua pair names |

---

### 4. Deploy Script

> [!warning] Placeholder
> `script/Deploy.s.sol` masih menggunakan **template default Foundry** yang men-deploy `Counter.sol`. Belum di-update untuk deploy `FeedRegistry` dan `CPFG`.

Berdasarkan TREE.md, flow deploy yang direncanakan:
1. `Deploy.s.sol` — Deploy `FeedRegistry` lalu `CPFG(registry)`
2. `RegisterFeeds.s.sol` — Populate registry dengan feed addresses dari `config/feeds.json`

---

### 5. Test Coverage

> [!warning] Placeholder
> `test/CPFG.t.sol` masih menggunakan **template default Foundry** yang mentest `Counter.sol` (increment, fuzz setNumber). Belum ada test untuk CPFG atau FeedRegistry.

Berdasarkan TREE.md, test suite yang direncanakan:

| Test File | Scope |
|-----------|-------|
| `CPFG.t.sol` | Integration tests untuk main contract |
| `FeedRegistry.t.sol` | Registry CRUD operations |
| `PriceDerivator.t.sol` | Cross-price derivation |
| `StalenessChecker.t.sol` | Staleness validation |
| `HistoricalSampler.t.sol` | Historical round sampling |
| `TWAPCalculator.t.sol` | TWAP calculation |
| `mocks/MockAggregatorV3.sol` | Mock Chainlink feed untuk unit test |

---

### 6. Key Decisions & Notes

#### TWAP Implementation
- `getTWAP()` saat ini menggunakan **simple average** (semua round bobotnya sama), **bukan** true time-weighted average berdasarkan durasi antar round
- Iterasi dibatasi `MAX_ROUNDS = 100` — jika time window sangat panjang dan round frequency rendah, TWAP mungkin tidak mencakup seluruh window
- Fallback: jika tidak ada round dalam window, return `latestPrice` dengan `roundsSampled = 1`

#### Staleness Check
- `checkStaleness()` membandingkan `block.timestamp - updatedAt` terhadap `_maxAge`
- `DEFAULT_MAX_AGE = 1 hours` — sesuai untuk feed major pairs yang update tiap ~1 jam
- Staleness check **tidak otomatis di-enforce** pada `getLatestPrice()` — caller harus explicitly memanggil `checkStaleness()` atau menggunakan `getDashboardData()`

> [!note] Design Choice
> Tidak auto-revert pada stale data memberikan fleksibilitas — caller bisa memutuskan sendiri threshold staleness sesuai use case mereka.

#### Price Change Calculation
- `getPriceChanges()` mengembalikan perubahan dalam **basis points (bps)** — 100 bps = 1%
- Menggunakan pendekatan **closest-match**: walk backward melalui round sampai menemukan timestamp ≤ target
- Jika tidak ditemukan round dalam MAX_ROUNDS iterasi, fallback ke `currentPrice` (change = 0 bps)

#### Derived Price
- `getDerivedPrice()` mengasumsikan kedua feed memiliki **quote currency yang sama** (e.g. keduanya /USD)
- Scaling dilakukan dengan formula: `(priceA × 10^decimalsResult × 10^decimalsB) / (10^decimalsA × priceB)`

#### Registry Architecture
- FeedRegistry menggunakan **swap-and-pop** untuk `removeFeed()` — urutan `s_registeredPairs` tidak preserved
- Ownership FeedRegistry di-set ke deployer, lalu CPFG memanggil registry via `onlyOwner` — artinya **CPFG harus menjadi owner dari FeedRegistry** agar `registerFeed`/`removeFeed` via CPFG bisa berjalan

> [!important] Ownership Consideration
> Constructor FeedRegistry menerima `initialOwner`. Agar CPFG bisa memanage feeds, FeedRegistry harus di-deploy dengan `address(CPFG)` sebagai owner, atau ownership di-transfer setelah deploy.

#### Planned Modularization (dari TREE.md)
Project direncanakan untuk dipecah menjadi modul terpisah:
- `PriceDerivator.sol` — Derived price calculation
- `StalenessChecker.sol` — Staleness validation
- `HistoricalSampler.sol` — Historical sampling + % change
- `TWAPCalculator.sol` — TWAP logic
- `interfaces/ICPFG.sol` — Interface untuk main contract

Ini belum diimplementasi — semua logic masih monolith di `CPFG.sol`.

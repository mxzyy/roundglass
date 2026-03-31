# TODO - Chainlink Price Feed Getter (CPFG)

## Ringkasan Project

Foundry-based Solidity project yang menyediakan utility contract untuk fetch harga dari Chainlink AggregatorV3.
Terdiri dari 2 contract: `CPFG.sol` (logic utama) dan `FeedRegistry.sol` (registry pair-to-feed).

---

## Yang Sudah Selesai

- [x] **CPFG.sol** — Contract utama dengan fitur:
  - `getLatestPrice()` — fetch harga terbaru dari satu feed
  - `getBatchPrices()` — fetch harga dari multiple feeds sekaligus
  - `getDerivedPrice()` — hitung cross price (e.g. BTC/ETH dari BTC/USD & ETH/USD)
  - `getHistoricalPrices()` — ambil N round terakhir dari feed
  - `getPriceChanges()` — estimasi perubahan harga 1h/24h/7d (bps)
  - `getTWAP()` — Time-Weighted Average Price
  - `checkStaleness()` — cek apakah feed sudah stale
  - `checkDeviation()` — cek deviasi harga dari reference price
  - `getDashboardData()` — bundle semua data dalam satu call
  - `registerFeed()` / `removeFeed()` — wrapper ke FeedRegistry
  - `getFeedInfo()` — resolve pair name ke feed address + metadata
- [x] **FeedRegistry.sol** — On-chain registry dengan:
  - Register / update / remove feed
  - Reverse lookup (address -> bool)
  - Enumeration (`getAllRegisteredPairs`)
  - Custom errors & events
- [x] **Dependencies** — forge-std, chainlink-brownie-contracts, openzeppelin-contracts
- [x] **Foundry config** — `foundry.toml` dengan remappings
- [x] **CI pipeline** — GitHub Actions (fmt, build, test)

---

## Yang Belum / Kurang

### Prioritas Tinggi

- [ ] **Test file masih boilerplate Counter** — `test/CPFG.t.sol` masih isi dari template Foundry (`CounterTest`), belum ada test untuk CPFG sama sekali
- [ ] **Deploy script masih boilerplate Counter** — `script/Deploy.s.sol` masih deploy `Counter`, bukan CPFG + FeedRegistry
- [ ] **Bug di `getFeedInfo()`** — return `feedAddress` tapi variabel `feedAddress` tidak pernah di-assign (selalu return `address(0)`). Seharusnya `feedAddress = feed;`

### Prioritas Sedang

- [ ] **Tidak ada test untuk FeedRegistry.sol** — perlu unit test untuk register/update/remove/getter
- [ ] **README.md masih default Foundry** — belum ada penjelasan project, cara setup, cara deploy, dsb.
- [ ] **CPFG.registerFeed() pakai `memory` bukan `calldata`** — parameter string bisa dioptimasi ke `calldata` untuk hemat gas
- [ ] **Ownership model CPFG vs FeedRegistry** — CPFG memanggil `i_registry.registerFeed()` yang `onlyOwner`, tapi owner FeedRegistry bisa berbeda dari CPFG contract. Perlu pastikan CPFG adalah owner dari FeedRegistry, atau registry ownership di-transfer ke CPFG saat deploy.

### Prioritas Rendah

- [ ] **Gas optimization** — `removeFeed` di FeedRegistry iterasi seluruh array (O(n)), bisa mahal kalau banyak pair
- [ ] **Natspec belum lengkap** — `getDashboardData()` belum ada natspec
- [ ] **Tidak ada event di CPFG.sol** — `registerFeed`/`removeFeed` wrapper tidak emit event sendiri (hanya rely on registry events)
- [ ] **Tidak ada interface/abstract contract** — belum ada `ICPFG.sol` untuk integrasi external
- [ ] **Belum ada fork test** — test dengan fork mainnet untuk validasi terhadap feed Chainlink asli

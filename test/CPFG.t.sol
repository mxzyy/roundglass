// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/CPFG.sol";
import "../src/FeedRegistry.sol";
import "./mocks/MockPriceFeed.sol";

contract CPFGTest is Test {
    CPFG public cpfg;
    FeedRegistry public feedRegistry;

    function setUp() public {
        feedRegistry = new FeedRegistry(address(this));
        cpfg = new CPFG(feedRegistry);
        feedRegistry.transferOwnership(address(cpfg));
    }

    // ============ CRUD & Access Control ============

    /// @notice Verifies that a feed can be registered and stored correctly in the registry
    function testRegisterFeed() public {
        address feed = makeAddr("testFeed");
        cpfg.registerFeed("BTC/USD", feed);
        assertEq(feedRegistry.getFeedAddress("BTC/USD"), feed);
    }

    /// @notice Verifies that a registered feed can be removed and returns address(0) after removal
    function testRemoveFeed() public {
        address feed = makeAddr("testFeed");
        cpfg.registerFeed("ETH/USD", feed);
        cpfg.removeFeed("ETH/USD");
        assertEq(feedRegistry.getFeedAddress("ETH/USD"), address(0));
    }

    /// @notice Ensures registerFeed reverts with CPFG__InvalidFeedAddress when given address(0)
    function testRegisterFeedRevertsOnZeroAddress() public {}

    /// @notice Ensures removeFeed reverts with CPFG__PairNotRegistered for an unregistered pair
    function testRemoveFeedRevertsIfNotRegistered() public {}

    /// @notice Ensures registerFeed reverts with OwnableUnauthorizedAccount when called by non-owner
    function testOnlyOwnerCanRegisterFeed() public {}

    /// @notice Ensures removeFeed reverts with OwnableUnauthorizedAccount when called by non-owner
    function testOnlyOwnerCanRemoveFeed() public {}

    // ============ getLatestPrice ============

    /// @notice Verifies getLatestPrice returns correct price, decimals, updatedAt, and roundId from a mock feed
    function testGetLatestPrice() public {
        // 1. Deploy mock dengan 8 decimals (standar Chainlink)
        MockPriceFeed mock = new MockPriceFeed(8, "BTC / USD");

        // 2. Set round data — roundId 1, harga $50,000, timestamp sekarang
        mock.setLatestRoundData(1, 50000e8, block.timestamp);

        // 3. Panggil getLatestPrice pake address mock
        (int256 price, uint8 decimals, uint256 updatedAt, uint80 roundId) = cpfg.getLatestPrice(address(mock));

        // 4. Assert semua return value
        assertEq(price, 50000e8);
        assertEq(decimals, 8);
        assertEq(updatedAt, block.timestamp);
        assertEq(roundId, 1);
    }

    /// @notice Ensures getLatestPrice reverts with CPFG__InvalidFeedAddress when given address(0)
    function testGetLatestPriceRevertsOnZeroAddress() public {}

    // ============ checkStaleness ============

    /// @notice Verifies checkStaleness returns isStale=true when elapsed time exceeds maxAge
    function testCheckStalenessIsStale() public {
        vm.warp(10000); // Set block timestamp to a known value
        
        MockPriceFeed mock = new MockPriceFeed(8, "ETH / USD");
        uint256 maxAge = 1 hours;
        uint256 staleTimestamp = block.timestamp - 2 hours;
        // Set round data dengan timestamp 2 jam yang lalu
        mock.setLatestRoundData(1, 3000e8, staleTimestamp);
        (bool isStale, uint256 age) = cpfg.checkStaleness(address(mock), maxAge);
        assertTrue(isStale);
        assertEq(age, 2 hours);
    }

    /// @notice Verifies checkStaleness returns isStale=false when feed was updated within maxAge
    function testCheckStalenessNotStale() public {
        vm.warp(20000); // Set block timestamp to a known value
        
        MockPriceFeed mock = new MockPriceFeed(8, "ETH / USD");
        uint256 maxAge = 1 hours;
        uint256 recentTimestamp = block.timestamp - 30 minutes;
        // Set round data dengan timestamp 30 menit yang lalu
        mock.setLatestRoundData(1, 3000e8, recentTimestamp);
        (bool isStale, uint256 age) = cpfg.checkStaleness(address(mock), maxAge);
        assertFalse(isStale);
        assertEq(age, 30 minutes);
    }

    /// @notice Ensures checkStaleness reverts with CPFG__InvalidFeedAddress when given address(0)
    function testCheckStalenessRevertsOnZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(CPFG.CPFG__InvalidFeedAddress.selector, address(0)));
        cpfg.checkStaleness(address(0), 1 hours);
    }

    // ============ getFeedInfo ============

    /// @notice Verifies getFeedInfo returns correct feedAddress, decimals, and description for a registered pair
    function testGetFeedInfo() public {
        // Register mock feed (harus contract, bukan EOA, karena getFeedInfo panggil decimals()/description())
        MockPriceFeed mock = new MockPriceFeed(8, "BTC / USD");
        cpfg.registerFeed("BTC/USD", address(mock));

        (address feedAddress, uint8 decimals, string memory description) = cpfg.getFeedInfo("BTC/USD");

        assertEq(feedAddress, address(mock));
        assertEq(decimals, 8);
        assertEq(description, "BTC / USD");
    }

    /// @notice Ensures getFeedInfo reverts with CPFG__PairNotRegistered for an unregistered pair
    function testGetFeedInfoRevertsIfNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(CPFG.CPFG__PairNotRegistered.selector, "BTC/USD"));
        cpfg.getFeedInfo("BTC/USD");
    }

    // ============ getBatchPrices ============

    /// @notice Verifies getBatchPrices returns correct PriceData array for multiple mock feeds
    function testGetBatchPrices() public {
        // Set up mock feeds with different data
        MockPriceFeed mock1 = new MockPriceFeed(8, "BTC / USD");
        MockPriceFeed mock2 = new MockPriceFeed(8, "ETH / USD");
        mock1.setLatestRoundData(1, 50000e8, block.timestamp);
        mock2.setLatestRoundData(1, 3000e8, block.timestamp);

        // Call getBatchPrices with address array
        address[] memory feeds = new address[](2);
        feeds[0] = address(mock1);
        feeds[1] = address(mock2);
        CPFG.PriceData[] memory prices = cpfg.getBatchPrices(feeds);

        // Assert results
        assertEq(prices.length, 2);
        assertEq(prices[0].price, 50000e8);
        assertEq(prices[0].decimals, 8);
        assertEq(prices[0].updatedAt, block.timestamp);
        assertEq(prices[0].roundId, 1);

        assertEq(prices[1].price, 3000e8);
        assertEq(prices[1].decimals, 8);
        assertEq(prices[1].updatedAt, block.timestamp);
        assertEq(prices[1].roundId, 1);
    }

    /// @notice Ensures getBatchPrices reverts with CPFG__EmptyFeedsArray when given an empty array
    function testGetBatchPricesRevertsOnEmptyArray() public {
        vm.expectRevert(abi.encodeWithSelector(CPFG.CPFG__EmptyFeedsArray.selector));
        cpfg.getBatchPrices(new address[](0));
    }

    // ============ getDerivedPrice ============

    /// @notice Verifies getDerivedPrice correctly computes cross-price (e.g. BTC/ETH from BTC/USD and ETH/USD)
    function testGetDerivedPrice() public {
        // Set up mock feeds with specific prices
        MockPriceFeed mockBTCUSD = new MockPriceFeed(8, "BTC / USD");
        MockPriceFeed mockETHUSD = new MockPriceFeed(8, "ETH / USD");
        mockBTCUSD.setLatestRoundData(1, 50000e8, block.timestamp); // $50,000
        mockETHUSD.setLatestRoundData(1, 2500e8, block.timestamp);  // $2,500

        // Call getDerivedPrice to compute BTC/ETH
        int256 derivedPrice = cpfg.getDerivedPrice(address(mockBTCUSD), address(mockETHUSD), 8);

        // Expected derived price = (50000 / 2500) * 10^8
        int256 expectedPrice = (50000e8 * 1e8) / 2500e8;
        assertEq(derivedPrice, expectedPrice);
    }

    /// @notice Ensures getDerivedPrice reverts with CPFG__InvalidPrice when either feed returns price <= 0
    function testGetDerivedPriceRevertsOnZeroPrice() public {
        // Set up mock feeds with specific prices
        MockPriceFeed mockBTCUSD = new MockPriceFeed(8, "BTC / USD");
        MockPriceFeed mockETHUSD = new MockPriceFeed(8, "ETH / USD");
        mockBTCUSD.setLatestRoundData(1, 0, block.timestamp); // Invalid price
        mockETHUSD.setLatestRoundData(1, 2500e8, block.timestamp);  // $2,500

        // Call getDerivedPrice to compute BTC/ETH
        vm.expectRevert(abi.encodeWithSelector(CPFG.CPFG__InvalidPrice.selector));
        cpfg.getDerivedPrice(address(mockBTCUSD), address(mockETHUSD), 8);
    }

    // ============ getHistoricalPrices ============

    /// @notice Verifies getHistoricalPrices returns correct array of HistoricalPoint from mock multi-round feed
    function testGetHistoricalPrices() public {
        vm.warp(1_000_000); // Harus cukup besar supaya block.timestamp - 3 days tidak underflow

        // Set up mock feed with multiple rounds of data
        MockPriceFeed mockBTCUSD = new MockPriceFeed(8, "BTC / USD");
        mockBTCUSD.setRoundData(1, 50000e8, block.timestamp - 3 days);
        mockBTCUSD.setRoundData(2, 51000e8, block.timestamp - 2 days);
        mockBTCUSD.setRoundData(3, 52000e8, block.timestamp - 1 days);
        mockBTCUSD.setRoundData(4, 53000e8, block.timestamp); // Latest

        // Call getHistoricalPrices to retrieve last 3 rounds
        CPFG.HistoricalPoint[] memory history = cpfg.getHistoricalPrices(address(mockBTCUSD), 3);

        // Assert results — contract returns descending order (latest first)
        assertEq(history.length, 3);
        assertEq(history[0].price, 53000e8);        // Round 4 (latest)
        assertEq(history[0].timestamp, block.timestamp);

        assertEq(history[1].price, 52000e8);        // Round 3
        assertEq(history[1].timestamp, block.timestamp - 1 days);

        assertEq(history[2].price, 51000e8);        // Round 2
        assertEq(history[2].timestamp, block.timestamp - 2 days);
    }

    /// @notice Ensures getHistoricalPrices reverts with CPFG__ExceedsMaxRounds when _numRounds is 0
    function testGetHistoricalPricesRevertsOnZeroRounds() public {
        MockPriceFeed mock = new MockPriceFeed(8, "BTC / USD");
        mock.setLatestRoundData(1, 50000e8, block.timestamp);

        // Error punya 2 params: (uint80 _numRounds, uint256 MAX_ROUNDS)
        vm.expectRevert(abi.encodeWithSelector(CPFG.CPFG__ExceedsMaxRounds.selector, uint80(0), cpfg.MAX_ROUNDS()));
        cpfg.getHistoricalPrices(address(mock), 0);
    }

    /// @notice Ensures getHistoricalPrices reverts with CPFG__ExceedsMaxRounds when _numRounds > MAX_ROUNDS
    function testGetHistoricalPricesRevertsExceedsMaxRounds() public {
        MockPriceFeed mock = new MockPriceFeed(8, "BTC / USD");
        mock.setLatestRoundData(1, 50000e8, block.timestamp);

        uint80 tooMany = uint80(cpfg.MAX_ROUNDS() + 1);
        vm.expectRevert(abi.encodeWithSelector(CPFG.CPFG__ExceedsMaxRounds.selector, tooMany, cpfg.MAX_ROUNDS()));
        cpfg.getHistoricalPrices(address(mock), tooMany);
    }

    // ============ getTWAP ============

    /// @notice Verifies getTWAP returns correct average price, roundsSampled, and actualTimeRange over a time window
    function testGetTWAP() public {
        // 1. Set waktu base supaya timestamp konsisten
        vm.warp(100_000);

        // 2. Deploy mock feed dengan 4 round data
        //    Round 1: $48,000 — 3 jam lalu (di luar window)
        //    Round 2: $50,000 — 2 jam lalu (dalam window)
        //    Round 3: $51,000 — 1 jam lalu (dalam window)
        //    Round 4: $52,000 — sekarang / latest (dalam window)
        MockPriceFeed mock = new MockPriceFeed(8, "BTC / USD");
        mock.setRoundData(1, 48000e8, block.timestamp - 3 hours);
        mock.setRoundData(2, 50000e8, block.timestamp - 2 hours);
        mock.setRoundData(3, 51000e8, block.timestamp - 1 hours);
        mock.setRoundData(4, 52000e8, block.timestamp); // latest

        // 3. Panggil getTWAP dengan time window 2.5 jam
        //    cutoffTime = block.timestamp - 2.5 hours
        //    Round 2, 3, 4 masuk window (updatedAt >= cutoffTime)
        //    Round 1 di luar window (3 jam lalu > 2.5 jam)
        uint256 timeWindow = 2.5 hours;
        (int256 twapPrice, uint256 roundsSampled, uint256 actualTimeRange) = cpfg.getTWAP(address(mock), timeWindow);

        // 4. Assert hasil
        //    twapPrice = (50000e8 + 51000e8 + 52000e8) / 3 = 51000e8
        //    roundsSampled = 3
        //    actualTimeRange = block.timestamp - (block.timestamp - 2 hours) = 2 hours
        assertEq(twapPrice, 51000e8, "TWAP price should be average of 3 rounds");
        assertEq(roundsSampled, 3, "Should sample 3 rounds within window");
        assertEq(actualTimeRange, 2 hours, "Time range should span from oldest sampled to latest");
    }

    /// @notice Verifies getTWAP returns latestPrice with roundsSampled=1 when no rounds fall within the time window
    function testGetTWAPNoRoundsInWindow() public {
        // 1. Set waktu base supaya timestamp konsisten
        vm.warp(100_000);

        // 2. Deploy mock feed dengan 1 round data
        MockPriceFeed mock = new MockPriceFeed(8, "BTC / USD");
        mock.setLatestRoundData(1, 50000e8, block.timestamp);

        // 3. Panggil getTWAP dengan time window 1 jam
        //    cutoffTime = block.timestamp - 1 hour
        //    Round 1 di luar window (sekarang < cutoffTime)
        uint256 timeWindow = 1 hours;
        (int256 twapPrice, uint256 roundsSampled, uint256 actualTimeRange) = cpfg.getTWAP(address(mock), timeWindow);

        // 4. Assert hasil
        //    twapPrice = 50000e8 (latest price)
        //    roundsSampled = 1
        //    actualTimeRange = 0
        assertEq(twapPrice, 50000e8, "TWAP price should be latest price");
        assertEq(roundsSampled, 1, "Should sample 1 round within window");
        assertEq(actualTimeRange, 0, "Time range should be 0 when no rounds in window");
    }

    // ============ getPriceChanges ============

    /// @notice Verifies getPriceChanges returns correct bps changes for ~1h, ~24h, and ~7d intervals
    function testGetPriceChanges() public {
        // 1. Set waktu base — harus > 7 days (604800s) supaya tidak underflow
        vm.warp(1_000_000);

        // 2. Deploy mock feed dengan 4 round data
        //    Round 1: $48,000 — 7 hari lalu
        //    Round 2: $50,000 — 1 hari lalu
        //    Round 3: $51,000 — 1 jam lalu
        //    Round 4: $52,000 — sekarang / latest
        MockPriceFeed mock = new MockPriceFeed(8, "BTC / USD");
        mock.setRoundData(1, 48000e8, block.timestamp - 7 days);
        mock.setRoundData(2, 50000e8, block.timestamp - 1 days);
        mock.setRoundData(3, 51000e8, block.timestamp - 1 hours);
        mock.setRoundData(4, 52000e8, block.timestamp); // latest

        // 3. Panggil getPriceChanges
        (int256 change1hBps, int256 change24hBps, int256 change7dBps) = cpfg.getPriceChanges(address(mock));

        // 4. Assert hasil
        //    change1hBps = ((52000 - 51000) / 51000) * 10,000 = ~196 bps
        //    change24hBps = ((52000 - 50000) / 50000) * 10,000 = ~400 bps
        //    change7dBps = ((52000 - 48000) / 48000) * 10,000 = ~833 bps

        int256 expected1h = ((int256(52000e8) - int256(51000e8)) * 10000) / int256(51000e8);
        int256 expected24h = ((int256(52000e8) - int256(50000e8)) * 10000) / int256(50000e8);
        int256 expected7d = ((int256(52000e8) - int256(48000e8)) * 10000) / int256(48000e8);

        assertEq(change1hBps, expected1h, "1h change should be correct");
        assertEq(change24hBps, expected24h, "24h change should be correct");
        assertEq(change7dBps, expected7d, "7d change should be correct");
    }

    /// @notice Verifies getPriceChanges returns 0 bps when price is constant across all intervals
    function testGetPriceChangesNoHistoricalData() public {
        vm.warp(1_000_000);

        // Semua round harga sama → bps change = 0
        // Perlu cukup round supaya semua interval (1h, 24h, 7d) ke-cover
        MockPriceFeed mock = new MockPriceFeed(8, "BTC / USD");
        mock.setRoundData(1, 50000e8, block.timestamp - 8 days);
        mock.setRoundData(2, 50000e8, block.timestamp - 7 days);
        mock.setRoundData(3, 50000e8, block.timestamp - 1 days);
        mock.setRoundData(4, 50000e8, block.timestamp - 1 hours);
        mock.setRoundData(5, 50000e8, block.timestamp); // latest

        (int256 change1hBps, int256 change24hBps, int256 change7dBps) = cpfg.getPriceChanges(address(mock));

        assertEq(change1hBps, 0, "1h change should be 0 bps");
        assertEq(change24hBps, 0, "24h change should be 0 bps");
        assertEq(change7dBps, 0, "7d change should be 0 bps");
    }

    // ============ checkDeviation ============

    /// @notice Verifies checkDeviation returns exceeded=true when price moves beyond thresholdBps
    function testCheckDeviationExceeded() public {
        // 1. Set waktu base supaya timestamp konsisten
        vm.warp(100_000);

        // 2. Deploy mock feed dengan 1 round data
        MockPriceFeed mock = new MockPriceFeed(8, "BTC / USD");
        mock.setLatestRoundData(1, 50000e8, block.timestamp);

        // 3. Panggil checkDeviation dengan lastKnownPrice $50,000 dan threshold 100 bps (1%)
        //    Move price ke $51,000 (2% increase) untuk melebihi threshold
        mock.setLatestRoundData(2, 51000e8, block.timestamp);
        (bool exceeded, int256 deviationBps) = cpfg.checkDeviation(address(mock), 50000e8, 100);

        // 4. Assert hasil
        //    Deviation = ((51000 - 50000) / 50000) * 10,000 = 200 bps > threshold 100 bps
        assertTrue(exceeded, "Deviation should be exceeded");
        assertEq(deviationBps, int256(((51000e8 - 50000e8) * 10000) / 50000e8), "Deviation bps should be correct");
    }

    /// @notice Verifies checkDeviation returns exceeded=false when price stays within thresholdBps
    function testCheckDeviationNotExceeded() public {
        // 1. Set waktu base supaya timestamp konsisten
        vm.warp(100_000);

        // 2. Deploy mock feed dengan 1 round data
        MockPriceFeed mock = new MockPriceFeed(8, "BTC / USD");
        mock.setLatestRoundData(1, 50000e8, block.timestamp);

        // 3. Panggil checkDeviation dengan lastKnownPrice $50,000 dan threshold 100 bps (1%)
        //    Move price ke $50,500 (1% increase) untuk tetap dalam threshold
        mock.setLatestRoundData(2, 50500e8, block.timestamp);
        (bool exceeded, int256 deviationBps) = cpfg.checkDeviation(address(mock), 50000e8, 100);

        // 4. Assert hasil
        //    Deviation = ((50500 - 50000) / 50000) * 10,000 = 100 bps == threshold
        assertFalse(exceeded, "Deviation should not be exceeded");
        assertEq(deviationBps, int256(((50500e8 - 50000e8) * 10000) / 50000e8), "Deviation bps should be correct");
    }

    /// @notice Ensures checkDeviation reverts with CPFG__InvalidPrice when _lastKnownPrice <= 0
    function testCheckDeviationRevertsOnInvalidPrice() public {
        MockPriceFeed mock = new MockPriceFeed(8, "BTC / USD");
        mock.setLatestRoundData(1, 50000e8, block.timestamp);

        vm.expectRevert(abi.encodeWithSelector(CPFG.CPFG__InvalidPrice.selector));
        cpfg.checkDeviation(address(mock), 0, 100);
    }

    /// @notice Ensures checkDeviation reverts with CPFG__InvalidThreshold when _thresholdBps is 0
    function testCheckDeviationRevertsOnZeroThreshold() public {
        MockPriceFeed mock = new MockPriceFeed(8, "BTC / USD");
        mock.setLatestRoundData(1, 50000e8, block.timestamp);

        vm.expectRevert(abi.encodeWithSelector(CPFG.CPFG__InvalidThreshold.selector));
        cpfg.checkDeviation(address(mock), 50000e8, 0);
    }

    // ============ getDashboardData ============

    /// @notice Verifies getDashboardData returns a fully populated DashboardData struct with correct values
    function testGetDashboardData() public {
        // 1. Set waktu base supaya timestamp konsisten
        vm.warp(1_000_000);

        // 2. Deploy mock feed dengan data yang diperlukan untuk semua field DashboardData
        MockPriceFeed mock = new MockPriceFeed(8, "BTC / USD");
        mock.setRoundData(1, 48000e8, block.timestamp - 7 days);
        mock.setRoundData(2, 50000e8, block.timestamp - 1 days);
        mock.setRoundData(3, 51000e8, block.timestamp - 1 hours);
        mock.setRoundData(4, 52000e8, block.timestamp); // latest

        // 3. Panggil getDashboardData
        // _numRounds = 4 karena mock cuma punya 4 round (round yang belum di-set akan revert)
        CPFG.DashboardData memory data = cpfg.getDashboardData(address(mock), 2.5 hours, 4);

        // 4. Assert semua field di DashboardData
        assertEq(data.latest.price, 52000e8, "Latest price should be correct");
        assertEq(data.latest.decimals, 8, "Decimals should be correct");
        assertEq(data.latest.updatedAt, block.timestamp, "UpdatedAt should be correct");
        assertEq(data.latest.roundId, 4, "RoundId should be correct");
        assertEq(data.change1h, int256(((int256(52000e8) - int256(51000e8)) * 10000) / int256(51000e8)), "1h change should be correct");
        assertEq(data.change24h, int256(((int256(52000e8) - int256(50000e8)) * 10000) / int256(50000e8)), "24h change should be correct");
        assertEq(data.change7d, int256(((int256(52000e8) - int256(48000e8)) * 10000) / int256(48000e8)), "7d change should be correct");
    }

}
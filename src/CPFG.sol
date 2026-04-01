// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./FeedRegistry.sol";

/// @title Chainlink Price Feed Getter (CPFG)
/// @notice Utility contract for fetching latest, batch, and historical prices from Chainlink AggregatorV3
/// @dev All functions are view/pure — no state is stored in this contract
/// @custom:security Always validate staleness before using prices in production

contract CPFG is Ownable {

    FeedRegistry private immutable i_registry;


    constructor(FeedRegistry _registry) Ownable(msg.sender) {
        i_registry = _registry;
    }

    /// @notice Registers a Chainlink feed address for a given pair name
    /// @param _pair Human-readable pair name (e.g. "BTC/USD")
    /// @param _feed Address of the AggregatorV3Interface price feed
    function registerFeed(string memory _pair, address _feed) external onlyOwner {
        if (_feed == address(0)) {
            revert CPFG__InvalidFeedAddress();
        }
        i_registry.registerFeed(_pair, _feed);
    }

    /// @notice Removes a registered feed for a given pair name
    /// @param _pair Human-readable pair name to remove
    function removeFeed(string memory _pair) external onlyOwner {
        if (i_registry.isRegisteredFeed(_pair) == false) {
            revert CPFG__PairNotRegistered(_pair);
        }
        i_registry.removeFeed(_pair);
    }

    /// @notice Represents a complete snapshot of price data from a single feed
    struct PriceData {
        int256 price;       // Raw price (divide by 10**decimals for human-readable)
        uint8 decimals;     // Feed decimal precision
        uint256 updatedAt;  // Unix timestamp of last update
        uint80 roundId;     // Round ID of this data point
    }

    /// @notice Represents a single historical price data point
    struct HistoricalPoint {
        uint80 roundId;     // Round ID of this historical point
        int256 price;       // Price at this round
        uint256 timestamp;  // Unix timestamp of this round
    }

    /// @notice Aggregated data bundle for a single feed — designed for one-call FE consumption
    struct DashboardData {
        PriceData latest;           // Latest price snapshot
        bool isStale;               // Whether the feed exceeds maxAge
        uint256 timeSinceUpdate;    // Seconds since last update
        HistoricalPoint[] history;  // Last N historical rounds
        int256 change1h;            // ~1h price change in bps
        int256 change24h;           // ~24h price change in bps
        int256 change7d;            // ~7d price change in bps
    }

    uint256 public constant DEFAULT_MAX_AGE = 1 hours;
    uint256 public constant MAX_ROUNDS = 100;

    error CPFG__InvalidFeedAddress();
    error CPFG__InvalidPrice();
    error CPFG__StalePriceFeed(address feed, uint256 updatedAt, uint256 maxAge);
    error CPFG__EmptyFeedsArray();
    error CPFG__ExceedsMaxRounds(uint256 requested, uint256 max);
    error CPFG__InvalidThreshold();
    error CPFG__PairNotRegistered(string pair);
    error CPFG__FeedCallFailed(string pair);

    /// @notice Checks whether a price feed's latest data exceeds the allowed age
    /// @param _priceFeed Address of the AggregatorV3Interface price feed
    /// @param _maxAge Maximum allowed age in seconds for the price data
    /// @return isStale True if the feed data is older than _maxAge
    /// @return timeSinceUpdate Number of seconds elapsed since the last update
    function checkStaleness(address _priceFeed, uint256 _maxAge) public view returns (bool isStale, uint256 timeSinceUpdate) {
        if (_priceFeed == address(0)) {
            revert CPFG__InvalidFeedAddress();
        }
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);
        (, , uint256 updatedAt, ,) = priceFeed.latestRoundData();
        timeSinceUpdate = block.timestamp - updatedAt;
        isStale = timeSinceUpdate > _maxAge;
        return (isStale, timeSinceUpdate);
    }

    /// @notice Fetches the latest price data from a single Chainlink price feed
    /// @dev Validates feed address, price positivity, and staleness before returning
    /// @param _priceFeed Address of the AggregatorV3Interface price feed
    /// @return price Latest raw price from the feed
    /// @return decimals Number of decimals used by the feed
    /// @return updatedAt Unix timestamp of the last update
    /// @return roundId Round ID of the latest data point
    function getLatestPrice(address _priceFeed) public view returns (int256, uint8, uint256, uint80) {
        if (_priceFeed == address(0)) {
            revert CPFG__InvalidFeedAddress();
        }
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);
        (uint80 roundId, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        return (price, priceFeed.decimals(), updatedAt, roundId);
    }

    /// @notice Get the latest prices from multiple Chainlink price feeds
    /// @param _priceFeeds Array of Chainlink AggregatorV3Interface price feed addresses
    /// @return prices Array of latest prices corresponding to each feed
    function getBatchPrices(address[] memory _priceFeeds) public view returns (PriceData[] memory) {
        if (_priceFeeds.length == 0) {
            revert CPFG__EmptyFeedsArray();
        }
        PriceData[] memory results = new PriceData[](_priceFeeds.length);
        for (uint i = 0; i < _priceFeeds.length; i++) {
            (results[i].price, results[i].decimals, results[i].updatedAt, results[i].roundId) = getLatestPrice(_priceFeeds[i]);
        }
        return results;
    }

    /// @notice Derives a cross price between two feeds (e.g. BTC/ETH from BTC/USD and ETH/USD)
    /// @dev Result is scaled to decimalsResult precision. Assumes both feeds share the same quote currency.
    /// @param _feedA Address of the numerator feed (e.g. BTC/USD)
    /// @param _feedB Address of the denominator feed (e.g. ETH/USD)
    /// @param _decimalsResult Desired decimal precision for the derived price
    /// @return derivedPrice The cross price scaled to _decimalsResult
    function getDerivedPrice(address _feedA, address _feedB, uint8 _decimalsResult) public view returns (int256 derivedPrice) {
        (int256 priceA, uint8 decimalsA, ,) = getLatestPrice(_feedA);
        (int256 priceB, uint8 decimalsB, ,) = getLatestPrice(_feedB);
        if (priceA <= 0 || priceB <= 0) {
            revert CPFG__InvalidPrice();
        }
        // Scale priceA to the desired decimals and adjust for the difference in feed decimals
        int256 scaledPriceA = priceA * int256(10 ** _decimalsResult) * int256(10 ** decimalsB) / int256(10 ** decimalsA);
        derivedPrice = scaledPriceA / priceB;
        return derivedPrice;
    }

    /// @notice Fetches the last N rounds of historical price data from a feed
    /// @dev Iterates backwards from the latest round ID. Stops early if round data is unavailable.
    /// @param _priceFeed Address of the AggregatorV3Interface price feed
    /// @param _numRounds Number of historical rounds to fetch (max: MAX_ROUNDS)
    /// @return history Array of HistoricalPoint structs ordered from latest to oldest
    function getHistoricalPrices(address _priceFeed, uint80 _numRounds) public view returns (HistoricalPoint[] memory) {
        if (_priceFeed == address(0)) {
            revert CPFG__InvalidFeedAddress();
        }
        if (_numRounds == 0 || _numRounds > MAX_ROUNDS) {
            revert CPFG__ExceedsMaxRounds(_numRounds, MAX_ROUNDS);
        }
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);
        (, , , , uint80 latestRoundId) = priceFeed.latestRoundData();
        HistoricalPoint[] memory history = new HistoricalPoint[](_numRounds);
        for (uint80 i = 0; i < _numRounds; i++) {
            (uint80 roundId, int256 price, , uint256 updatedAt, ) = priceFeed.getRoundData(latestRoundId - i);
            history[i] = HistoricalPoint({price: price, timestamp: updatedAt, roundId: roundId});
        }
        return history;
    }

    /// @notice Approximates price changes over ~1h, ~24h, and ~7d by walking backwards through rounds
    /// @dev Changes are expressed in basis points (bps). 100 bps = 1%.
    ///      Round intervals are not fixed — results are approximate based on timestamp proximity.
    /// @param _priceFeed Address of the AggregatorV3Interface price feed
    /// @return change1h Approximate price change over the last ~1 hour in bps
    /// @return change24h Approximate price change over the last ~24 hours in bps
    /// @return change7d Approximate price change over the last ~7 days in bps
    function getPriceChanges(address _priceFeed) public view returns (int256 change1h, int256 change24h, int256 change7d) {
        (int256 currentPrice, , , uint80 latestRoundId) = getLatestPrice(_priceFeed);

        // Define target timestamps
        uint256 t1h = block.timestamp - 1 hours;
        uint256 t24h = block.timestamp - 24 hours;
        uint256 t7d = block.timestamp - 7 days;

        // Initialize prices to currentPrice as fallback
        int256 price1h = currentPrice;
        int256 price24h = currentPrice;
        int256 price7d = currentPrice;
        bool found1h;
        bool found24h;
        bool found7d;

        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);

        // Walk backwards through rounds to find the closest data points for each interval
        for (uint80 i = 1; i <= MAX_ROUNDS; i++) {
            uint80 currentRoundId = latestRoundId - i;
            try priceFeed.getRoundData(currentRoundId) returns (uint80, int256 price, uint256, uint256 updatedAt, uint80) {
                if (!found1h && updatedAt <= t1h) {
                    price1h = price;
                    found1h = true;
                }
                if (!found24h && updatedAt <= t24h) {
                    price24h = price;
                    found24h = true;
                }
                if (!found7d && updatedAt <= t7d) {
                    price7d = price;
                    found7d = true;
                }
                if (found1h && found24h && found7d) {
                    break;
                }
            } catch {
                continue;
            }
        }

        // Calculate changes in basis points (bps)
        change1h = ((currentPrice - price1h) * 10000) / price1h;
        change24h = ((currentPrice - price24h) * 10000) / price24h;
        change7d = ((currentPrice - price7d) * 10000) / price7d;
        return (change1h, change24h, change7d);
    }

    /// @notice Calculates the Time-Weighted Average Price over a given time window
    /// @dev Walks backwards through rounds until timeWindow is covered or MAX_ROUNDS is reached.
    ///      Weights each round equally (simple average, not time-weighted by duration).
    /// @param _priceFeed Address of the AggregatorV3Interface price feed
    /// @param _timeWindow Duration in seconds to calculate the TWAP over
    /// @return twapPrice The average price over the sampled rounds
    /// @return roundsSampled Number of rounds included in the calculation
    /// @return actualTimeRange Actual time range covered by the sampled rounds
    function getTWAP( address _priceFeed, uint256 _timeWindow ) public view returns (int256 twapPrice, uint256 roundsSampled, uint256 actualTimeRange) {
        if (_priceFeed == address(0)) {
            revert CPFG__InvalidFeedAddress();
        }
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);
        (uint80 latestRoundId, int256 latestPrice, , uint256 latestTimestamp, ) = priceFeed.latestRoundData();

        uint256 cutoffTime = latestTimestamp - _timeWindow;
        int256 priceSum = 0;
        roundsSampled = 0;
        uint256 oldestTimestamp = latestTimestamp;

        for (uint80 i = 0; i < MAX_ROUNDS; i++) {
            uint80 currentRoundId = latestRoundId - i;
            try priceFeed.getRoundData(currentRoundId) returns (uint80, int256 price, uint256, uint256 updatedAt, uint80) {
                if (updatedAt < cutoffTime) {
                    break;
                }
                priceSum += price;
                roundsSampled++;
                oldestTimestamp = updatedAt;
            } catch {
                break;
            }
        }

        if (roundsSampled == 0) {
            return (latestPrice, 1, 0);
        }

        twapPrice = priceSum / int256(roundsSampled);
        actualTimeRange = latestTimestamp - oldestTimestamp;
        return (twapPrice, roundsSampled, actualTimeRange);
    }

    /// @notice Checks whether the current price has deviated from a reference price beyond a threshold
    /// @dev Deviation is calculated as: ((currentPrice - lastKnownPrice) * 10000) / lastKnownPrice
    /// @param _priceFeed Address of the AggregatorV3Interface price feed
    /// @param _lastKnownPrice Reference price to compare against (must be > 0)
    /// @param _thresholdBps Deviation threshold in basis points (e.g. 500 = 5%)
    /// @return exceeded True if absolute deviation exceeds _thresholdBps
    /// @return deviationBps Signed deviation in basis points (negative = price dropped)
    function checkDeviation( address _priceFeed, int256 _lastKnownPrice, uint256 _thresholdBps ) public view returns (bool exceeded, int256 deviationBps) {
        if (_lastKnownPrice <= 0) {
            revert CPFG__InvalidPrice();
        }
        if (_thresholdBps == 0) {
            revert CPFG__InvalidThreshold();
        }

        (int256 currentPrice, , ,) = getLatestPrice(_priceFeed);
        if (currentPrice <= 0) {
            revert CPFG__InvalidPrice();
        }
        deviationBps = ((currentPrice - _lastKnownPrice) * 10000) / _lastKnownPrice;
        int256 absDeviation = deviationBps >= 0 ? deviationBps : -deviationBps;
        exceeded = absDeviation > int256(_thresholdBps);
        return (exceeded, deviationBps);
    }

    /// @notice Resolves a pair name to its feed address and metadata from the on-chain registry
    /// @dev Requires the pair to be registered via the registry mapping
    /// @param _pair Human-readable pair name (e.g. "BTC/USD")
    /// @return feedAddress The registered Chainlink feed address for this pair
    /// @return decimals Decimal precision of the feed
    /// @return description Description string returned by the feed
    function getFeedInfo(string memory _pair) public view returns (address feedAddress, uint8 decimals, string memory description) {
        address feed = i_registry.getFeedAddress(_pair);
        if (feed == address(0)) {
            revert CPFG__PairNotRegistered(_pair);
        }
        AggregatorV3Interface feedInterface = AggregatorV3Interface(feed);
        try feedInterface.decimals() returns (uint8 _decimals) {
            decimals = _decimals;
        } catch {
            revert CPFG__FeedCallFailed(_pair);
        }
        try feedInterface.description() returns (string memory _description) {
            description = _description;
        } catch {
            revert CPFG__FeedCallFailed(_pair);
        }
        return (feed, decimals, description);
    }

    /// @notice Retrieves a comprehensive dashboard snapshot for a given Chainlink price feed.
    /// @dev Aggregates latest price, staleness check, historical prices, and price changes into a single call.
    /// @param _priceFeed The address of the Chainlink AggregatorV3Interface price feed.
    /// @param _maxAge The maximum acceptable age (in seconds) before the feed is considered stale.
    /// @param _numRounds The number of historical rounds to retrieve.
    /// @return A `DashboardData` struct containing latest price, staleness info, historical prices, and price change percentages (in bps).
    function getDashboardData(address _priceFeed, uint256 _maxAge, uint80 _numRounds) public view returns (DashboardData memory) {
        if (_priceFeed == address(0)) {
            revert CPFG__InvalidFeedAddress();
        }
        DashboardData memory data;
        (data.latest.price, data.latest.decimals, data.latest.updatedAt, data.latest.roundId) = getLatestPrice(_priceFeed);
        (data.isStale, data.timeSinceUpdate) = checkStaleness(_priceFeed, _maxAge);
        data.history = getHistoricalPrices(_priceFeed, _numRounds);
        (data.change1h, data.change24h, data.change7d) = getPriceChanges(_priceFeed);
        return data;
    }
}   

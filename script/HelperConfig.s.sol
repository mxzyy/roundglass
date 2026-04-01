// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockPriceFeed} from "../test/mocks/MockPriceFeed.sol";

/// @title HelperConfig
/// @notice Network-aware configuration for CPFG deployments
/// @dev Deploys mocks on local chains (Anvil), uses real Chainlink addresses on live networks
contract HelperConfig is Script {
    struct FeedConfig {
        string pair;
        address feed;
    }

    uint256 public constant ANVIL_CHAIN_ID = 31337;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant MAINNET_CHAIN_ID = 1;

    uint8 public constant MOCK_DECIMALS = 8;
    int256 public constant MOCK_BTC_PRICE = 65000e8;
    int256 public constant MOCK_ETH_PRICE = 3200e8;
    int256 public constant MOCK_LINK_PRICE = 15e8;

    function getConfig() public returns (FeedConfig[] memory) {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            return getSepoliaConfig();
        } else if (block.chainid == MAINNET_CHAIN_ID) {
            return getMainnetConfig();
        } else {
            return getAnvilConfig();
        }
    }

    function getSepoliaConfig() internal pure returns (FeedConfig[] memory feeds) {
        feeds = new FeedConfig[](3);
        feeds[0] = FeedConfig("BTC/USD", 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43);
        feeds[1] = FeedConfig("ETH/USD", 0x694AA1769357215DE4FAC081bf1f309aDC325306);
        feeds[2] = FeedConfig("LINK/USD", 0xc59E3633BAAC79493d908e63626716e204A45EdF);
    }

    function getMainnetConfig() internal pure returns (FeedConfig[] memory feeds) {
        feeds = new FeedConfig[](3);
        feeds[0] = FeedConfig("BTC/USD", 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);
        feeds[1] = FeedConfig("ETH/USD", 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        feeds[2] = FeedConfig("LINK/USD", 0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c);
    }

    function getAnvilConfig() internal returns (FeedConfig[] memory feeds) {
        feeds = new FeedConfig[](3);

        MockPriceFeed btcFeed = new MockPriceFeed(MOCK_DECIMALS, "BTC / USD");
        MockPriceFeed ethFeed = new MockPriceFeed(MOCK_DECIMALS, "ETH / USD");
        MockPriceFeed linkFeed = new MockPriceFeed(MOCK_DECIMALS, "LINK / USD");

        uint256 currentTime = block.timestamp;

        // BTC/USD — 10 rounds of historical data
        _seedMockRounds(btcFeed, MOCK_BTC_PRICE, currentTime, 10);
        // ETH/USD
        _seedMockRounds(ethFeed, MOCK_ETH_PRICE, currentTime, 10);
        // LINK/USD
        _seedMockRounds(linkFeed, MOCK_LINK_PRICE, currentTime, 10);

        feeds[0] = FeedConfig("BTC/USD", address(btcFeed));
        feeds[1] = FeedConfig("ETH/USD", address(ethFeed));
        feeds[2] = FeedConfig("LINK/USD", address(linkFeed));
    }

    /// @notice Seeds a mock feed with N rounds of slightly varying historical data
    /// @dev Round 0 = oldest, round N-1 = latest. Prices vary +/- ~1% to simulate real movement.
    function _seedMockRounds(MockPriceFeed feed, int256 basePrice, uint256 latestTimestamp, uint80 numRounds) internal {
        // Use a safe base timestamp so subtraction doesn't underflow
        uint256 baseTime = latestTimestamp > numRounds * 1 hours
            ? latestTimestamp - ((numRounds - 1) * 1 hours)
            : 1;
        for (uint80 i = 0; i < numRounds; i++) {
            uint256 roundTimestamp = baseTime + (uint256(i) * 1 hours);
            // Small price variation: +/- up to 1% based on round index
            int256 variation = (basePrice * int256(int80(i % 5))) / 500;
            int256 price = (i % 2 == 0) ? basePrice + variation : basePrice - variation;
            feed.setRoundData(i + 1, price, roundTimestamp);
        }
    }
}

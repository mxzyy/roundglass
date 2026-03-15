// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract CPFG {

    /// @notice Get the latest price data from a Chainlink price feed
    /// @param _priceFeed The address of the Chainlink AggregatorV3Interface price feed
    /// @return price The latest price
    /// @return decimals The number of decimals in the price feed
    /// @return updatedAt The timestamp of the last update
    /// @return roundId The round ID of the latest data
    function getLatestPrice(address _priceFeed) public view returns (int256, uint8, uint256, uint80) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);
        (uint80 roundId, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        return (price, priceFeed.decimals(), updatedAt, roundId);
    }

    /// @notice Get the latest prices from multiple Chainlink price feeds
    /// @param _priceFeeds Array of Chainlink AggregatorV3Interface price feed addresses
    /// @return prices Array of latest prices corresponding to each feed
    function getBatchPrices(address[] memory _priceFeeds) public view returns (int256[] memory) {
        int256[] memory prices = new int256[](_priceFeeds.length);
        for (uint i = 0; i < _priceFeeds.length; i++) {
            (prices[i], , , )    = getLatestPrice(_priceFeeds[i]);
        }
        return prices;
    }

    /// @notice Get historical price data from a Chainlink price feed
    /// @param _priceFeed The address of the Chainlink AggregatorV3Interface price feed
    /// @param _roundData The round ID to query historical data for
    function getHistoricalPrices(address _priceFeed, uint256 _roundData) public {

    }    

}

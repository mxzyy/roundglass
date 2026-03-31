// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title MockPriceFeed
/// @notice Mock implementation of AggregatorV3Interface for unit testing
/// @dev Supports configurable decimals, description, and multi-round historical data
contract MockPriceFeed is AggregatorV3Interface {
    uint8 private s_decimals;
    string private s_description;
    uint256 private s_version;

    struct RoundData {
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
    }

    mapping(uint80 => RoundData) private s_rounds;
    uint80 private s_latestRoundId;

    constructor(uint8 _decimals, string memory _description) {
        s_decimals = _decimals;
        s_description = _description;
        s_version = 1;
    }

    /// @notice Sets a single round of price data
    /// @param _roundId The round ID to set
    /// @param _answer The price answer for this round
    /// @param _updatedAt The timestamp for this round
    function setRoundData(uint80 _roundId, int256 _answer, uint256 _updatedAt) external {
        s_rounds[_roundId] = RoundData({
            answer: _answer,
            startedAt: _updatedAt,
            updatedAt: _updatedAt
        });
        if (_roundId > s_latestRoundId) {
            s_latestRoundId = _roundId;
        }
    }

    /// @notice Convenience function to set the latest round in one call
    /// @param _roundId The round ID
    /// @param _answer The price answer
    /// @param _updatedAt The timestamp
    function setLatestRoundData(uint80 _roundId, int256 _answer, uint256 _updatedAt) external {
        s_rounds[_roundId] = RoundData({
            answer: _answer,
            startedAt: _updatedAt,
            updatedAt: _updatedAt
        });
        s_latestRoundId = _roundId;
    }

    function decimals() external view override returns (uint8) {
        return s_decimals;
    }

    function description() external view override returns (string memory) {
        return s_description;
    }

    function version() external view override returns (uint256) {
        return s_version;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        RoundData memory round = s_rounds[_roundId];
        require(round.updatedAt > 0, "Round not set");
        return (_roundId, round.answer, round.startedAt, round.updatedAt, _roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        RoundData memory round = s_rounds[s_latestRoundId];
        return (s_latestRoundId, round.answer, round.startedAt, round.updatedAt, s_latestRoundId);
    }
}

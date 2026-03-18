// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title FeedRegistry
/// @notice On-chain registry that maps human-readable pair names to Chainlink feed addresses
/// @dev Owner-managed registry with reverse lookup and enumeration support
contract FeedRegistry is Ownable {
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Maps pair name (e.g. "BTC/USD") to its Chainlink feed address
    mapping(string => address) private s_feeds;
    /// @notice Reverse lookup to check if a feed address is registered
    mapping(address => bool) private s_registeredFeeds;
    /// @notice Array of all registered pair names for enumeration
    string[] private s_registeredPairs;

    /// @notice Emitted when a new pair-feed mapping is registered
    event FeedRegistered(string indexed pair, address indexed feed);
    /// @notice Emitted when an existing pair's feed address is updated
    event FeedUpdated(string indexed pair, address indexed oldFeed, address indexed newFeed);
    /// @notice Emitted when a pair-feed mapping is removed
    event FeedRemoved(string indexed pair, address indexed feed);

    error FeedRegistry__PairAlreadyRegistered(string pair);
    error FeedRegistry__PairNotRegistered(string pair);
    error FeedRegistry__InvalidFeedAddress();
    error FeedRegistry__FeedAddressUnchanged();

    /// @notice Registers a new pair name to a Chainlink feed address
    /// @dev Reverts if the pair is already registered or feed is address(0)
    /// @param pair Human-readable pair name (e.g. "BTC/USD")
    /// @param feed Address of the Chainlink AggregatorV3Interface price feed
    function registerFeed(string calldata pair, address feed) external onlyOwner {
        if (s_feeds[pair] != address(0)) {
            revert FeedRegistry__PairAlreadyRegistered(pair);
        }
        if (feed == address(0)) {
            revert FeedRegistry__InvalidFeedAddress();
        }

        s_feeds[pair] = feed;
        s_registeredFeeds[feed] = true;
        s_registeredPairs.push(pair);

        emit FeedRegistered(pair, feed);
    }

    /// @notice Updates the feed address for an already-registered pair
    /// @dev Reverts if pair is not registered, newFeed is address(0), or newFeed equals the current feed
    /// @param pair Human-readable pair name to update
    /// @param newFeed New Chainlink feed address to associate with the pair
    function updateFeed(string calldata pair, address newFeed) external onlyOwner {
        address oldFeed = s_feeds[pair];
        if (oldFeed == address(0)) {
            revert FeedRegistry__PairNotRegistered(pair);
        }
        if (newFeed == address(0)) {
            revert FeedRegistry__InvalidFeedAddress();
        }
        if (oldFeed == newFeed) {
            revert FeedRegistry__FeedAddressUnchanged();
        }

        s_feeds[pair] = newFeed;
        s_registeredFeeds[oldFeed] = false;
        s_registeredFeeds[newFeed] = true;

        emit FeedUpdated(pair, oldFeed, newFeed);
    }

    /// @notice Removes a registered pair-feed mapping
    /// @dev Uses swap-and-pop to remove from s_registeredPairs array. Reverts if pair is not registered.
    /// @param pair Human-readable pair name to remove
    function removeFeed(string calldata pair) external onlyOwner {
        address feed = s_feeds[pair];
        if (feed == address(0)) {
            revert FeedRegistry__PairNotRegistered(pair);
        }

        delete s_feeds[pair];
        s_registeredFeeds[feed] = false;

        // Remove from registeredPairs
        for (uint i = 0; i < s_registeredPairs.length; i++) {
            if (keccak256(bytes(s_registeredPairs[i])) == keccak256(bytes(pair))) {
                s_registeredPairs[i] = s_registeredPairs[s_registeredPairs.length - 1];
                s_registeredPairs.pop();
                break;
            }
        }

        emit FeedRemoved(pair, feed);
    }

    /// @notice Returns the feed address for a given pair name
    /// @param pair Human-readable pair name (e.g. "BTC/USD")
    /// @return The Chainlink feed address, or address(0) if not registered
    function getFeedAddress(string calldata pair) external view returns (address) {
        return s_feeds[pair];
    }

    /// @notice Checks whether a pair name has a registered feed
    /// @param pair Human-readable pair name to check
    /// @return True if the pair has a registered feed address
    function isRegisteredFeed(string calldata pair) external view returns (bool) {
        return s_feeds[pair] != address(0);
    }

    /// @notice Checks whether a feed address is registered in the registry
    /// @param feed Address to check
    /// @return True if the address is a registered feed
    function isRegisteredFeedAddress(address feed) external view returns (bool) {
        return s_registeredFeeds[feed];
    }

    /// @notice Returns all registered pair names
    /// @return Array of all currently registered pair name strings
    function getAllRegisteredPairs() external view returns (string[] memory) {
        return s_registeredPairs;
    }

}
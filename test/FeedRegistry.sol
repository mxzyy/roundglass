//// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FeedRegistry.sol";

/// @title FeedRegistryTest
/// @notice Comprehensive unit tests for the FeedRegistry contract
/// @dev Tests cover all public/external functions, access control, events, custom errors, and edge cases
contract FeedRegistryTest is Test {
    FeedRegistry public feedRegistry;

    address public owner;
    address public nonOwner;

    address public feedA;
    address public feedB;
    address public feedC;

    string constant PAIR_BTC_USD = "BTC/USD";
    string constant PAIR_ETH_USD = "ETH/USD";
    string constant PAIR_SOL_USD = "SOL/USD";

    /// @notice Deploys a fresh FeedRegistry before each test
    function setUp() public {
        owner = address(this);
        nonOwner = makeAddr("nonOwner");
        feedA = makeAddr("feedA");
        feedB = makeAddr("feedB");
        feedC = makeAddr("feedC");

        feedRegistry = new FeedRegistry(owner);
    }

    // ==================== Constructor ====================

    /// @notice Verifies the deployer is set as the initial owner
    function test_constructor_setsOwner() public view {
        assertEq(feedRegistry.owner(), owner);
    }

    // ==================== registerFeed ====================

    /// @notice Successfully registers a single feed and verifies storage
    function test_registerFeed_singlePair() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);

        assertEq(feedRegistry.getFeedAddress(PAIR_BTC_USD), feedA);
        assertTrue(feedRegistry.isRegisteredFeed(PAIR_BTC_USD));
        assertTrue(feedRegistry.isRegisteredFeedAddress(feedA));
    }

    /// @notice Registers multiple distinct pairs and verifies each is stored correctly
    function test_registerFeed_multiplePairs() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.registerFeed(PAIR_ETH_USD, feedB);
        feedRegistry.registerFeed(PAIR_SOL_USD, feedC);

        assertEq(feedRegistry.getFeedAddress(PAIR_BTC_USD), feedA);
        assertEq(feedRegistry.getFeedAddress(PAIR_ETH_USD), feedB);
        assertEq(feedRegistry.getFeedAddress(PAIR_SOL_USD), feedC);

        string[] memory pairs = feedRegistry.getAllRegisteredPairs();
        assertEq(pairs.length, 3);
    }

    /// @notice Emits FeedRegistered event with correct pair and feed address
    function test_registerFeed_emitsFeedRegistered() public {
        vm.expectEmit(true, true, false, true);
        emit FeedRegistry.FeedRegistered(PAIR_BTC_USD, feedA);

        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
    }

    /// @notice Reverts when registering a pair that already exists
    function test_registerFeed_revertsIfPairAlreadyRegistered() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);

        vm.expectRevert(
            abi.encodeWithSelector(FeedRegistry.FeedRegistry__PairAlreadyRegistered.selector, PAIR_BTC_USD)
        );
        feedRegistry.registerFeed(PAIR_BTC_USD, feedB);
    }

    /// @notice Reverts when registering with address(0) as the feed address
    function test_registerFeed_revertsIfFeedIsZeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(FeedRegistry.FeedRegistry__InvalidFeedAddress.selector)
        );
        feedRegistry.registerFeed(PAIR_BTC_USD, address(0));
    }

    /// @notice Reverts when a non-owner calls registerFeed
    function test_registerFeed_revertsIfCallerIsNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner)
        );
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
    }

    /// @notice Verifies the pair is appended to s_registeredPairs array
    function test_registerFeed_appendsToPairsArray() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);

        string[] memory pairs = feedRegistry.getAllRegisteredPairs();
        assertEq(pairs.length, 1);
        assertEq(pairs[0], PAIR_BTC_USD);
    }

    // ==================== updateFeed ====================

    /// @notice Successfully updates a registered feed to a new address
    function test_updateFeed_updatesExistingPair() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.updateFeed(PAIR_BTC_USD, feedB);

        assertEq(feedRegistry.getFeedAddress(PAIR_BTC_USD), feedB);
    }

    /// @notice Verifies old feed address is deregistered and new one is registered
    function test_updateFeed_updatesRegisteredFeedAddresses() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.updateFeed(PAIR_BTC_USD, feedB);

        assertFalse(feedRegistry.isRegisteredFeedAddress(feedA));
        assertTrue(feedRegistry.isRegisteredFeedAddress(feedB));
    }

    /// @notice Emits FeedUpdated event with correct old and new feed addresses
    function test_updateFeed_emitsFeedUpdated() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);

        vm.expectEmit(true, true, true, true);
        emit FeedRegistry.FeedUpdated(PAIR_BTC_USD, feedA, feedB);

        feedRegistry.updateFeed(PAIR_BTC_USD, feedB);
    }

    /// @notice Reverts when updating a pair that has not been registered
    function test_updateFeed_revertsIfPairNotRegistered() public {
        vm.expectRevert(
            abi.encodeWithSelector(FeedRegistry.FeedRegistry__PairNotRegistered.selector, PAIR_BTC_USD)
        );
        feedRegistry.updateFeed(PAIR_BTC_USD, feedB);
    }

    /// @notice Reverts when updating to address(0)
    function test_updateFeed_revertsIfNewFeedIsZeroAddress() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);

        vm.expectRevert(
            abi.encodeWithSelector(FeedRegistry.FeedRegistry__InvalidFeedAddress.selector)
        );
        feedRegistry.updateFeed(PAIR_BTC_USD, address(0));
    }

    /// @notice Reverts when updating to the same feed address
    function test_updateFeed_revertsIfFeedAddressUnchanged() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);

        vm.expectRevert(
            abi.encodeWithSelector(FeedRegistry.FeedRegistry__FeedAddressUnchanged.selector)
        );
        feedRegistry.updateFeed(PAIR_BTC_USD, feedA);
    }

    /// @notice Reverts when a non-owner calls updateFeed
    function test_updateFeed_revertsIfCallerIsNotOwner() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);

        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner)
        );
        feedRegistry.updateFeed(PAIR_BTC_USD, feedB);
    }

    // ==================== removeFeed ====================

    /// @notice Successfully removes a registered feed
    function test_removeFeed_deletesMapping() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.removeFeed(PAIR_BTC_USD);

        assertEq(feedRegistry.getFeedAddress(PAIR_BTC_USD), address(0));
        assertFalse(feedRegistry.isRegisteredFeed(PAIR_BTC_USD));
        assertFalse(feedRegistry.isRegisteredFeedAddress(feedA));
    }

    /// @notice Verifies the pair is removed from the s_registeredPairs array
    function test_removeFeed_removesPairFromArray() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.registerFeed(PAIR_ETH_USD, feedB);

        feedRegistry.removeFeed(PAIR_BTC_USD);

        string[] memory pairs = feedRegistry.getAllRegisteredPairs();
        assertEq(pairs.length, 1);
        assertEq(pairs[0], PAIR_ETH_USD);
    }

    /// @notice Verifies swap-and-pop correctly handles removing the last element
    function test_removeFeed_removesLastElementFromArray() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.registerFeed(PAIR_ETH_USD, feedB);

        feedRegistry.removeFeed(PAIR_ETH_USD);

        string[] memory pairs = feedRegistry.getAllRegisteredPairs();
        assertEq(pairs.length, 1);
        assertEq(pairs[0], PAIR_BTC_USD);
    }

    /// @notice Removes a feed from the middle of the array and verifies swap-and-pop order
    function test_removeFeed_swapAndPopMiddleElement() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.registerFeed(PAIR_ETH_USD, feedB);
        feedRegistry.registerFeed(PAIR_SOL_USD, feedC);

        feedRegistry.removeFeed(PAIR_BTC_USD);

        string[] memory pairs = feedRegistry.getAllRegisteredPairs();
        assertEq(pairs.length, 2);
        // After swap-and-pop: SOL/USD replaces BTC/USD at index 0, ETH/USD stays at index 1
        assertEq(pairs[0], PAIR_SOL_USD);
        assertEq(pairs[1], PAIR_ETH_USD);
    }

    /// @notice Verifies removing the only registered feed results in an empty array
    function test_removeFeed_removesOnlyElement() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.removeFeed(PAIR_BTC_USD);

        string[] memory pairs = feedRegistry.getAllRegisteredPairs();
        assertEq(pairs.length, 0);
    }

    /// @notice Emits FeedRemoved event with correct pair and feed address
    function test_removeFeed_emitsFeedRemoved() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);

        vm.expectEmit(true, true, false, true);
        emit FeedRegistry.FeedRemoved(PAIR_BTC_USD, feedA);

        feedRegistry.removeFeed(PAIR_BTC_USD);
    }

    /// @notice Reverts when removing a pair that is not registered
    function test_removeFeed_revertsIfPairNotRegistered() public {
        vm.expectRevert(
            abi.encodeWithSelector(FeedRegistry.FeedRegistry__PairNotRegistered.selector, PAIR_BTC_USD)
        );
        feedRegistry.removeFeed(PAIR_BTC_USD);
    }

    /// @notice Reverts when a non-owner calls removeFeed
    function test_removeFeed_revertsIfCallerIsNotOwner() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);

        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner)
        );
        feedRegistry.removeFeed(PAIR_BTC_USD);
    }

    /// @notice After removing, the same pair can be re-registered
    function test_removeFeed_allowsReRegistration() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.removeFeed(PAIR_BTC_USD);

        // Should not revert
        feedRegistry.registerFeed(PAIR_BTC_USD, feedB);
        assertEq(feedRegistry.getFeedAddress(PAIR_BTC_USD), feedB);
    }

    // ==================== getFeedAddress ====================

    /// @notice Returns address(0) for an unregistered pair
    function test_getFeedAddress_returnsZeroForUnregisteredPair() public view {
        assertEq(feedRegistry.getFeedAddress(PAIR_BTC_USD), address(0));
    }

    /// @notice Returns the correct feed address for a registered pair
    function test_getFeedAddress_returnsCorrectAddress() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        assertEq(feedRegistry.getFeedAddress(PAIR_BTC_USD), feedA);
    }

    // ==================== isRegisteredFeed ====================

    /// @notice Returns false for a pair that has not been registered
    function test_isRegisteredFeed_returnsFalseForUnregisteredPair() public view {
        assertFalse(feedRegistry.isRegisteredFeed(PAIR_BTC_USD));
    }

    /// @notice Returns true for a registered pair
    function test_isRegisteredFeed_returnsTrueForRegisteredPair() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        assertTrue(feedRegistry.isRegisteredFeed(PAIR_BTC_USD));
    }

    /// @notice Returns false after a pair is removed
    function test_isRegisteredFeed_returnsFalseAfterRemoval() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.removeFeed(PAIR_BTC_USD);
        assertFalse(feedRegistry.isRegisteredFeed(PAIR_BTC_USD));
    }

    // ==================== isRegisteredFeedAddress ====================

    /// @notice Returns false for an address that has never been registered
    function test_isRegisteredFeedAddress_returnsFalseForUnknownAddress() public view {
        assertFalse(feedRegistry.isRegisteredFeedAddress(feedA));
    }

    /// @notice Returns true for a currently registered feed address
    function test_isRegisteredFeedAddress_returnsTrueForRegisteredAddress() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        assertTrue(feedRegistry.isRegisteredFeedAddress(feedA));
    }

    /// @notice Returns false for a feed address after its pair is removed
    function test_isRegisteredFeedAddress_returnsFalseAfterRemoval() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.removeFeed(PAIR_BTC_USD);
        assertFalse(feedRegistry.isRegisteredFeedAddress(feedA));
    }

    /// @notice Returns false for old address after feed is updated
    function test_isRegisteredFeedAddress_returnsFalseForOldAfterUpdate() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.updateFeed(PAIR_BTC_USD, feedB);
        assertFalse(feedRegistry.isRegisteredFeedAddress(feedA));
        assertTrue(feedRegistry.isRegisteredFeedAddress(feedB));
    }

    // ==================== getAllRegisteredPairs ====================

    /// @notice Returns an empty array when no feeds are registered
    function test_getAllRegisteredPairs_returnsEmptyArrayInitially() public view {
        string[] memory pairs = feedRegistry.getAllRegisteredPairs();
        assertEq(pairs.length, 0);
    }

    /// @notice Returns all registered pair names in insertion order
    function test_getAllRegisteredPairs_returnsAllPairs() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.registerFeed(PAIR_ETH_USD, feedB);

        string[] memory pairs = feedRegistry.getAllRegisteredPairs();
        assertEq(pairs.length, 2);
        assertEq(pairs[0], PAIR_BTC_USD);
        assertEq(pairs[1], PAIR_ETH_USD);
    }

    /// @notice Array length decreases after removal
    function test_getAllRegisteredPairs_reflectsRemovals() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.registerFeed(PAIR_ETH_USD, feedB);

        feedRegistry.removeFeed(PAIR_BTC_USD);

        string[] memory pairs = feedRegistry.getAllRegisteredPairs();
        assertEq(pairs.length, 1);
    }

    // ==================== Integration / Edge Cases ====================

    /// @notice Full lifecycle: register → update → remove → re-register
    function test_fullLifecycle() public {
        // Register
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        assertEq(feedRegistry.getFeedAddress(PAIR_BTC_USD), feedA);

        // Update
        feedRegistry.updateFeed(PAIR_BTC_USD, feedB);
        assertEq(feedRegistry.getFeedAddress(PAIR_BTC_USD), feedB);
        assertFalse(feedRegistry.isRegisteredFeedAddress(feedA));
        assertTrue(feedRegistry.isRegisteredFeedAddress(feedB));

        // Remove
        feedRegistry.removeFeed(PAIR_BTC_USD);
        assertEq(feedRegistry.getFeedAddress(PAIR_BTC_USD), address(0));
        assertFalse(feedRegistry.isRegisteredFeedAddress(feedB));

        // Re-register with a different feed
        feedRegistry.registerFeed(PAIR_BTC_USD, feedC);
        assertEq(feedRegistry.getFeedAddress(PAIR_BTC_USD), feedC);
        assertTrue(feedRegistry.isRegisteredFeedAddress(feedC));
    }

    /// @notice Same feed address can be used for different pairs
    function test_sameFeedAddressForDifferentPairs() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.registerFeed(PAIR_ETH_USD, feedA);

        assertEq(feedRegistry.getFeedAddress(PAIR_BTC_USD), feedA);
        assertEq(feedRegistry.getFeedAddress(PAIR_ETH_USD), feedA);
        assertTrue(feedRegistry.isRegisteredFeedAddress(feedA));
    }

    /// @notice Removing one pair sharing a feed address marks the address as unregistered
    /// @dev This is a known edge case: s_registeredFeeds uses a simple bool, so removing
    ///      any pair with that address sets it to false even if another pair still uses it
    function test_sharedFeedAddress_removalEdgeCase() public {
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
        feedRegistry.registerFeed(PAIR_ETH_USD, feedA);

        feedRegistry.removeFeed(PAIR_BTC_USD);

        // Edge case: feedA is marked as unregistered even though ETH/USD still points to it
        assertFalse(feedRegistry.isRegisteredFeedAddress(feedA));
        // But the mapping still returns feedA for ETH/USD
        assertEq(feedRegistry.getFeedAddress(PAIR_ETH_USD), feedA);
    }

    /// @notice Registers a pair with an empty string name
    function test_registerFeed_emptyStringPair() public {
        feedRegistry.registerFeed("", feedA);
        assertEq(feedRegistry.getFeedAddress(""), feedA);
        assertTrue(feedRegistry.isRegisteredFeed(""));
    }

    /// @notice Pair names are case-sensitive — "BTC/USD" and "btc/usd" are different pairs
    function test_pairNamesAreCaseSensitive() public {
        feedRegistry.registerFeed("BTC/USD", feedA);
        feedRegistry.registerFeed("btc/usd", feedB);

        assertEq(feedRegistry.getFeedAddress("BTC/USD"), feedA);
        assertEq(feedRegistry.getFeedAddress("btc/usd"), feedB);
    }

    /// @notice Ownership can be transferred and new owner can manage feeds
    function test_ownershipTransfer() public {
        feedRegistry.transferOwnership(nonOwner);

        vm.prank(nonOwner);
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);

        assertEq(feedRegistry.getFeedAddress(PAIR_BTC_USD), feedA);
    }

    /// @notice Old owner cannot manage feeds after ownership transfer
    function test_ownershipTransfer_oldOwnerReverts() public {
        feedRegistry.transferOwnership(nonOwner);

        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner)
        );
        feedRegistry.registerFeed(PAIR_BTC_USD, feedA);
    }
}

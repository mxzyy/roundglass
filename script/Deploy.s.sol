// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {FeedRegistry} from "../src/FeedRegistry.sol";
import {CPFG} from "../src/CPFG.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployCPFG is Script {
    function run() external returns (CPFG, FeedRegistry) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.FeedConfig[] memory feeds = helperConfig.getConfig();

        vm.startBroadcast();

        // 1. Deploy FeedRegistry with deployer as initial owner
        FeedRegistry feedRegistry = new FeedRegistry(msg.sender);
        console.log("FeedRegistry deployed at:", address(feedRegistry));

        // 2. Deploy CPFG with the registry
        CPFG cpfg = new CPFG(feedRegistry);
        console.log("CPFG deployed at:", address(cpfg));

        // 3. Transfer FeedRegistry ownership to CPFG so it can manage feeds
        feedRegistry.transferOwnership(address(cpfg));
        console.log("FeedRegistry ownership transferred to CPFG");

        // 4. Register all feeds from config
        for (uint256 i = 0; i < feeds.length; i++) {
            cpfg.registerFeed(feeds[i].pair, feeds[i].feed);
            console.log("Registered feed:", feeds[i].pair);
        }

        vm.stopBroadcast();

        return (cpfg, feedRegistry);
    }
}

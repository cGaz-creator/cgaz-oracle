// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { MockGasFeed } from "test/CgazTokenBurn.t.sol"; // ou le chemin vers ton MockGasFeed

contract DeployMockFeed is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_KEY"));
        // On fixe le prix à 1e18 (1 USDC = 1 cGAZ)
        MockGasFeed feed = new MockGasFeed(1e18);
        console.log("MockGasFeed deployed at:", address(feed));
        vm.stopBroadcast();
    }
}

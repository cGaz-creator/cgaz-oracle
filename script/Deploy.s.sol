// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { cGAZ } from "src/cGAZ.sol";

contract Deploy is Script {
    function run() external {
        // Récupère la clé privée au format bytes32 puis cast en uint256
        bytes32 pk = vm.envBytes32("DEPLOYER_KEY");
        vm.startBroadcast(uint256(pk));

        address usdcAddress = vm.envAddress("USDC_SEPOLIA");
        address priceFeed   = vm.envAddress("CHAINLINK_FEED_SEPOLIA");

        cGAZ token = new cGAZ(usdcAddress, priceFeed);
        console.log("cGAZ deployed to:", address(token));

        vm.stopBroadcast();
    }
}

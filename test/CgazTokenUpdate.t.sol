// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {cGAZ} from "src/cGAZ.sol";
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";
import {MockERC20} from "./CgazTokenMint.t.sol"; // réutilise ton mock existant

contract DummyFeed is AggregatorV3Interface {
    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function description() external pure override returns (string memory) {
        return "Dummy";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80) external pure override returns (uint80, int256, uint256, uint256, uint80) {
        revert("unused");
    }

    function latestRoundData() external pure override returns (uint80, int256, uint256, uint256, uint80) {
        return (0, 1e18, 0, 0, 0);
    }
}

contract UpdatePriceTest is Test {
    cGAZ token;
    MockERC20 usdc;
    DummyFeed feed;

    address owner = address(1);
    address updater = address(2);
    address attacker = address(3);

    function setUp() public {
        vm.prank(owner);
        usdc = new MockERC20();

        vm.prank(owner);
        feed = new DummyFeed();

        vm.prank(owner);
        token = new cGAZ(address(usdc), address(feed));

        // Le owner définit l’updater
        vm.prank(owner);
        token.setUpdater(updater);
    }

    function testUpdatePriceByUpdaterWorks() public {
        vm.prank(updater);
        token.updatePrice(1e18);
        assertEq(token.currentPrice(), 1e18, "Price not updated");
    }

    function testUpdatePriceByNonUpdaterReverts() public {
        vm.prank(attacker);
        vm.expectRevert("Not authorized");
        token.updatePrice(1e18);
    }
}

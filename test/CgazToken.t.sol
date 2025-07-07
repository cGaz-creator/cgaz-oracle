// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {CgazToken} from "src/CgazToken.sol";
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";

/// @dev Mock Chainlink feed for tests
contract MockGasFeed is AggregatorV3Interface {
    int256 public immutable mockPrice;

    constructor(int256 _price) {
        mockPrice = _price;
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function description() external pure override returns (string memory) {
        return "Mock Gas";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80) external pure override returns (uint80, int256, uint256, uint256, uint80) {
        revert("not used");
    }

    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (0, mockPrice, 0, 0, 0);
    }
}

contract CgazTokenTest is Test {
    CgazToken public token;
    address public owner = address(1);

    function setUp() public {
        // 1) Deploy mock oracle at price = 1 gwei
        vm.prank(owner);
        MockGasFeed feed = new MockGasFeed(1e9);
        // 2) Instantiate token with that oracle
        vm.prank(owner);
        token = new CgazToken("cGAZ", "CGAZ", address(feed));
        // 3) Publish a first price so mint/burn can proceed
        vm.prank(address(feed));
        token.updatePrice(1e9);
    }

    function testMintBurnFlow() public {
        vm.startPrank(owner);
        token.mint(address(this), 100);
        assertEq(token.balanceOf(address(this)), 100, "Mint net incorrect");
        assertEq(token.balanceOf(owner), 0, "Owner fee incorrect");

        token.burn(address(this), 50);
        assertEq(token.balanceOf(address(this)), 50, "Burn net incorrect");
        assertEq(token.balanceOf(owner), 0, "Owner fee incorrect");
        vm.stopPrank();
    }

    function testUpdatePriceGating() public {
        // After initial update in setUp, mint works
        vm.prank(owner);
        token.mint(address(this), 1);

        // Simulate passing >1h
        vm.warp(block.timestamp + 3601);

        // Now price is stale again
        vm.prank(owner);
        vm.expectRevert("Price stale");
        token.mint(address(this), 1);

        // Oracle republishes
        address feedAddr = token.oracle();
        vm.prank(feedAddr);
        token.updatePrice(2e9);

        // Mint works again
        vm.prank(owner);
        token.mint(address(this), 2);
        // On avait 1 au début + 2 = 3
        assertEq(token.balanceOf(address(this)), 3, "Balance cumulative incorrecte");
    }
}

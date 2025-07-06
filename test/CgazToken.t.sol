// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {CgazToken} from "src/CgazToken.sol";
import {AggregatorV3Interface} from "chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @dev Mock de l’oracle Chainlink pour les tests
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
        // Deploy mock oracle at 1 gwei
        vm.prank(owner);
        MockGasFeed feed = new MockGasFeed(1e9);
        // Instantiate token with 1h update interval
        vm.prank(owner);
        token = new CgazToken("cGAZ", "CGAZ", address(feed), 3600);
    }

    function testMintBurnFlow() public {
        vm.startPrank(owner);
        // Mint 100: fee = floor(100 * 0.5%) = 0
        token.mint(address(this), 100);
        assertEq(token.balanceOf(address(this)), 100, "Mint net incorrect");
        assertEq(token.balanceOf(owner), 0, "Fee mint incorrect");

        // Burn 50: fee = 0
        token.burn(address(this), 50);
        assertEq(token.balanceOf(address(this)), 50, "Burn net incorrect");
        assertEq(token.balanceOf(owner), 0, "Fee burn incorrect");
        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {CgazToken} from "src/CgazToken.sol";
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @dev Mock simple d’un ERC20 pour les tests
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        // Optionnel : minter des tokens si tu veux tester recoverUSDC
        _mint(address(this), type(uint256).max);
    }
}

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
    MockERC20 public mockUSDC;
    address public owner = address(1);

    function setUp() public {
        // 1) Mock oracle + mock USDC
        vm.prank(owner);
        MockGasFeed feed = new MockGasFeed(1e9);
        // Deploy le mock USDC et stocke-le en state var
        mockUSDC = new MockERC20();

        // Faucet pour owner : crédit depuis le MockERC20 (qui détient initialement tous les tokens)
        vm.prank(address(mockUSDC));
        mockUSDC.transfer(owner, 1e6);

        // 2) Deploy token avec _oracle + mockUSDC
        vm.prank(owner);
        token = new CgazToken("cGAZ", "CGAZ", address(feed), mockUSDC);

        // 3) initial price on-chain (warp pour que lastUpdated ≠ 0)
        vm.warp(1);
        vm.prank(address(feed));
        token.updatePrice(1e9);
    }

    function testMintBurnFlow() public {
        vm.startPrank(owner);
        // Approve le contrat à débiter 100 USDC
        mockUSDC.approve(address(token), 100);
        // Dépose 100 USDC → grossCGAZ = 100 * 1e18 / 1e9 = 100e9
        token.mint(address(this), 100);

        // On a minté net = grossCGAZ * 9950/10000
        uint256 gross = 100 * 1e9;
        uint256 fee = (gross * 50) / 10000;
        uint256 net = gross - fee;

        assertEq(token.balanceOf(address(this)), net, "Mint net incorrect");
        assertEq(token.balanceOf(owner), fee, "Owner fee incorrect");

        // Puis on burn 50e9 (soit 50 cGAZ en base 1e9)
        // => remboursé en USDC : 50e9 * price / 1e18 = 50 USDC, avec frais
        token.burn(address(this), 50 * 1e9);
        // Attendu : burn net cGAZ = 50e9 * 9950/10000
        uint256 burned = (50 * 1e9 * 9950) / 10000;
        uint256 burnFee = (50 * 1e9) - burned;
        assertEq(token.balanceOf(address(this)), net - burned, "Burn net incorrect");
        assertEq(token.balanceOf(owner), fee + burnFee, "Owner fee incorrect");

        vm.stopPrank();
    }

    function testUpdatePriceGating() public {
        // After initial update in setUp, mint works
        vm.startPrank(owner);
        mockUSDC.approve(address(token), 1);
        token.mint(address(this), 1);
        vm.stopPrank();

        // Simulate passing >1h
        vm.warp(block.timestamp + 3601);

        // Now price is stale again
        vm.startPrank(owner);
        vm.expectRevert("Price stale");
        token.mint(address(this), 1);
        vm.stopPrank();

        // Oracle republishes
        address feedAddr = token.oracle();
        vm.prank(feedAddr);
        token.updatePrice(2e9);

        // Mint works again
        vm.startPrank(owner);
        mockUSDC.approve(address(token), 2);
        token.mint(address(this), 2);
        vm.stopPrank();

        // On a minté net deux fois 995 000 000 (995e6) ⇒ cumul = 1 990 000 000
        assertEq(token.balanceOf(address(this)), 1_990_000_000, "Balance cumulative incorrecte");
    }
}

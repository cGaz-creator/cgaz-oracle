// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {cGAZ as CgazToken} from "src/cGAZ.sol";
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @dev Mock USDC minimal
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Mock Chainlink feed
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

contract MintFlowTest is Test {
    CgazToken token;
    MockERC20 mockUSDC;
    MockGasFeed feed;
    address owner = address(1);

    function setUp() public {
        // 1) setup mocks: oracle + USDC
        vm.prank(owner);
        feed = new MockGasFeed(1e18); // prix USDC→cGAZ = 1
        mockUSDC = new MockERC20();
        // créditer owner en USDC
        mockUSDC.mint(owner, 1_000_000);

        // 2) déployer le token
        vm.prank(owner);
        token = new CgazToken(address(mockUSDC), address(feed));

        // 3) set updater to this contract
        vm.prank(owner);
        token.setUpdater(address(this));

        // 4) initialiser le prix on-chain (warp + appel par l'oracle)
        vm.warp(100);
        token.updatePrice(1e18);
    }

    function testMintMintsCorrectAmountAndFees() public {
        // owner approve 100 USDC to token
        vm.startPrank(owner);
        mockUSDC.approve(address(token), 100);
        // mint 100 USDC → 100 cGAZ brut
        token.mint(owner, 100);
        vm.stopPrank();

        // brut = 100 * 1e18 / 1e18 = 100
        // fee = 100 * 50 / 10000 = 0.5 → tronqué à 0
        // net = 100 - 0 = 100
        assertEq(token.balanceOf(owner), 100, "net cGAZ incorrect");

        // le contrat a prélevé 100 USDC
        assertEq(mockUSDC.balanceOf(address(token)), 100, "USDC non recu");

        // owner fee amount = floor(0.5) = 0 (car 50bps sur 100 donne 0.5)
        // donc owner should still have 0 cGAZ fee minted
        assertEq(token.balanceOf(address(this)), 0, "commission inattendue");
    }
function testMintWithNonZeroFee() public {
    // ajuster l'oracle pour un prix non-unité
    vm.prank(owner);
    feed = new MockGasFeed(2e18); // prix = 2 USDC / cGAZ

    // redéployer le token avec le nouveau feed
    vm.prank(owner);
    token = new CgazToken(address(mockUSDC), address(feed));

    // autoriser ce contrat de test comme updater
    vm.prank(owner);
    token.setUpdater(address(this));

    // avancer le temps et mettre à jour le prix via adresse autorisée
    vm.warp(200);
    vm.prank(address(this));
    token.updatePrice(2e18);

    // mint 100 USDC → brut = 100 * 1e18 / 2e18 = 50 cGAZ
    // fee = 50 * 50 / 10_000 = 0.25 (tronqué à 0)
    vm.startPrank(owner);
    mockUSDC.approve(address(token), 100);
    token.mint(address(this), 100);
    vm.stopPrank();

    // net = 50 cGAZ
    assertEq(token.balanceOf(address(this)), 50, "net cGAZ incorrect");

    // USDC transféré sur le contrat
    assertEq(mockUSDC.balanceOf(address(token)), 100, "USDC non recu");
}

function testMintWithFeeLargeAmount() public {
    // prix = 1 USDC = 1 cGAZ
    vm.prank(owner);
    feed = new MockGasFeed(1e18);

    // déployer le token avec ce feed
    vm.prank(owner);
    token = new CgazToken(address(mockUSDC), address(feed));

    // autoriser ce contrat de test comme updater
    vm.prank(owner);
    token.setUpdater(address(this));

    // avancer le temps et mettre à jour le prix
    vm.warp(300);
    vm.prank(address(this));
    token.updatePrice(1e18);

    // mint 10_000 USDC → brut = 10_000 cGAZ
    vm.startPrank(owner);
    mockUSDC.approve(address(token), 10_000);
    token.mint(address(this), 10_000);
    vm.stopPrank();

    uint256 expectedGross = 10_000 * 1e18 / 1e18; // 10_000
    uint256 expectedFee = (expectedGross * 50) / 10_000; // 50
    uint256 expectedNet = expectedGross - expectedFee;

    assertEq(token.balanceOf(address(this)), expectedNet, "net cGAZ incorrect");
    assertEq(token.balanceOf(owner), expectedFee, "fee cGAZ incorrect");
    assertEq(mockUSDC.balanceOf(address(token)), 10_000, "USDC non recu");
}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {cGAZ as CgazToken} from "src/cGAZ.sol";
import "src/interfaces/AggregatorV3Interface.sol";

// ERC20 pour le mock USDC
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
// Interface Chainlink pour le mock oracle
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";

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

contract BurnFlowTest is Test {
    CgazToken token;
    MockERC20 mockUSDC;
    MockGasFeed feed;
    address owner = address(1);

    function setUp() public {
        // Deploy mocks
        vm.prank(owner);
        feed = new MockGasFeed(2e9);
        mockUSDC = new MockERC20();
        // Créditer owner en mockUSDC via la fonction mint du mock
        mockUSDC.mint(owner, 1e6);

        // Deploy token
        vm.prank(owner);
        token = new CgazToken(address(mockUSDC), address(feed));

        vm.prank(owner);
        token.setUpdater(address(this));
        
        vm.warp(1);
        token.updatePrice(2e9);

        // Mint quelques cGAZ (depôt USDC)
        vm.startPrank(owner);
        mockUSDC.approve(address(token), 100);
        token.mint(address(this), 100);
        vm.stopPrank();
    }

    function testBurnReturnsUSDC() public {
        // 1) Solde cGAZ initial
        uint256 balanceCGAZ = token.balanceOf(address(this));
        assertTrue(balanceCGAZ > 0, "Pas de cGAZ a bruler");
        // 2) Stocke le solde USDC de l’owner avant burn
        uint256 ownerBefore = mockUSDC.balanceOf(owner);

        // 3) Burn la moitié des cGAZ
        uint256 toBurn = balanceCGAZ / 2;
        vm.startPrank(owner);
        token.burn(address(this), toBurn);
        vm.stopPrank();

        // 4) Calcul prévu de netUSDC et feeUSDC
        uint256 grossUSDC = (toBurn * 2e9) / 1e18;
        uint256 feeUSDC = (grossUSDC * 50) / 10000;
        uint256 netUSDC = grossUSDC - feeUSDC;

        // 5) Assertions
        assertEq(mockUSDC.balanceOf(address(this)), netUSDC, "USDC net incorrect");
        assertEq(mockUSDC.balanceOf(owner) - ownerBefore, feeUSDC, "Commission owner incorrecte");
    }
function testBurnWithFeeLargeAmount() public {
    // 1. Setup oracle (1 USDC = 1 cGAZ)
    vm.prank(owner);
    feed = new MockGasFeed(1e18);

    vm.prank(owner);
    token = new CgazToken(address(mockUSDC), address(feed));

    // autoriser ce contrat de test comme updater
    vm.prank(owner);
    token.setUpdater(address(this));

    vm.warp(300);
    vm.prank(address(this));
    token.updatePrice(1e18);

    // 2. Mint 10_000 USDC → brut = 10_000 cGAZ
    vm.startPrank(owner);
    mockUSDC.approve(address(token), 10_000);
    token.mint(address(this), 10_000);
    vm.stopPrank();

    uint256 burnAmount = token.balanceOf(address(this));

    // 3. Capture solde owner avant burn
    uint256 beforeFeeCgaz = token.balanceOf(owner);
    uint256 beforeFeeUsdc = mockUSDC.balanceOf(owner);

    // 4. Burn tous les cGAZ
    vm.startPrank(address(this));
    token.burn(address(this), burnAmount);
    vm.stopPrank();

    // 5. Calculs attendus
    uint256 feeCGAZ = (burnAmount * 50) / 10_000;        // = 50e18
    uint256 netCGAZ = burnAmount - feeCGAZ;              // = 9950e18
    uint256 usdcGross = (netCGAZ * 1e18) / 1e18;         // = 9950
    uint256 feeUSDC = (usdcGross * 50) / 10_000;         // = 49
    uint256 usdcNet = usdcGross - feeUSDC;              // = 9901

    // 6. Assertions
    assertEq(mockUSDC.balanceOf(address(this)), usdcNet, "USDC net incorrect");
    assertEq(token.balanceOf(owner) - beforeFeeCgaz, feeCGAZ, "fee cGAZ incorrect");
    assertEq(mockUSDC.balanceOf(owner) - beforeFeeUsdc, feeUSDC, "fee USDC incorrect");
}
}

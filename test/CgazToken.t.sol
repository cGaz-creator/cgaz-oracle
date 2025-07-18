// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "src/interfaces/AggregatorV3Interface.sol";

/// @title Crypto Gas Index (cGAZ) token MVP
/// @notice Mint/burn against USDC with on-chain price, pause & reentrancy guard
contract cGAZ is ERC20, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant FEE_BASIS_POINTS = 50;
    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;
    uint256 public constant STALE_THRESHOLD = 1 hours;

    IERC20 public immutable usdc;
    AggregatorV3Interface public immutable priceFeed;
    uint256 public lastUpdated;
    int256 public currentPrice;

    event PriceUpdated(int256 price, uint256 timestamp);
    event TokensMinted(address indexed to, uint256 netAmount, uint256 fee);
    event TokensBurned(address indexed from, uint256 burnedAmount, uint256 fee);

    constructor(address _usdc, address _priceFeed) ERC20("Crypto Gas Index", "cGAZ") {
        usdc = IERC20(_usdc);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    /// @notice Only the designated oracle (priceFeed) can update the price
    function updatePrice(int256 price) external {
        require(msg.sender == address(priceFeed), "Only oracle");
        require(price > 0, "Invalid price");
        if (lastUpdated != 0) {
            require(block.timestamp >= lastUpdated + STALE_THRESHOLD, "Too soon");
        }
        currentPrice = price;
        lastUpdated = block.timestamp;
        emit PriceUpdated(price, lastUpdated);
    }

    function _freshPrice() internal view returns (int256) {
        require(lastUpdated != 0, "Price not set");
        require(block.timestamp <= lastUpdated + STALE_THRESHOLD, "Price stale");
        return currentPrice;
    }

    function mint(address to, uint256 usdcAmount) external whenNotPaused nonReentrant {
        int256 price = _freshPrice();
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        uint256 gross = (usdcAmount * 1e18) / uint256(price);
        uint256 fee = (gross * FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
        uint256 net = gross - fee;
        _mint(to, net);
        _mint(owner(), fee);
        emit TokensMinted(to, net, fee);
    }

    function burn(address from, uint256 cgazAmount) external whenNotPaused nonReentrant {
        int256 price = _freshPrice();
        uint256 feeCGAZ = (cgazAmount * FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
        uint256 netCGAZ = cgazAmount - feeCGAZ;
        _burn(from, netCGAZ);
        _mint(owner(), feeCGAZ);
        uint256 usdcGross = (netCGAZ * uint256(price)) / 1e18;
        uint256 feeUSDC = (usdcGross * FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
        uint256 usdcNet = usdcGross - feeUSDC;
        usdc.safeTransfer(from, usdcNet);
        usdc.safeTransfer(owner(), feeUSDC);
        emit TokensBurned(from, netCGAZ, feeCGAZ);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function recoverUSDC(address to, uint256 amount) external onlyOwner {
        usdc.safeTransfer(to, amount);
    }
}

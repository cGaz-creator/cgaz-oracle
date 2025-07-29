// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "./interfaces/AggregatorV3Interface.sol";

/// @title Crypto Gas Index (cGAZ) token MVP
/// @notice Mint/burn against USDC with on-chain price, pause & reentrancy guard
contract cGAZ is ERC20, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Basis points for fees (0.5%)
    uint256 public constant FEE_BASIS_POINTS = 50;
    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;
    /// @notice Time window before price becomes stale (5 minutes)
    uint256 public constant STALE_THRESHOLD = 5 minutes;

    IERC20 public immutable usdc;
    AggregatorV3Interface public immutable priceFeed;
    uint256 public lastUpdated;
    int256 public currentPrice;
    address public updater;

    event PriceUpdated(int256 price, uint256 timestamp);
    event TokensMinted(address indexed user, uint256 usdcIn, uint256 netCgaz, uint256 feeCgaz);
    event TokensBurned(address indexed user, uint256 burnedCgaz, uint256 feeCgaz, uint256 usdcOut, uint256 feeUsdc);

    /// @param _usdc Address of USDC token
    /// @param _priceFeed Chainlink price feed for USDC→cGAZ

    constructor(address _usdc, address _priceFeed) ERC20("Crypto Gas Index", "cGAZ") {
        usdc = IERC20(_usdc);
        priceFeed = AggregatorV3Interface(_priceFeed);
        // Ownable() s’exécute automatiquement et fera owner = msg.sender
    }

    /// @notice Update on-chain price (only price oracle)
    function updatePrice(int256 price) external onlyUpdater {
        require(price > 0, "Invalid price");
        // allow first update or once per interval
        if (lastUpdated != 0) {
            require(block.timestamp >= lastUpdated + STALE_THRESHOLD, "Too soon");
        }
        currentPrice = price;
        lastUpdated = block.timestamp;
        emit PriceUpdated(price, lastUpdated);
    }

    /// @dev Ensure price is fresh
    function _freshPrice() internal view returns (int256) {
        require(lastUpdated != 0, "Price not set");
        require(block.timestamp <= lastUpdated + STALE_THRESHOLD, "Price stale");
        return currentPrice;
    }

    /// @notice Mint cGAZ by depositing USDC
    /// @param to Recipient of cGAZ
    /// @param usdcAmount Amount of USDC to deposit
    function mint(address to, uint256 usdcAmount) external whenNotPaused nonReentrant {
        require(to != address(0), "Invalid recipient");
        require(usdcAmount > 0, "Amount must be > 0");

        int256 price = _freshPrice();

        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        uint256 gross = (usdcAmount * 1e18) / uint256(price);
        uint256 fee = (gross * FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
        uint256 net = gross - fee;

        _mint(to, net);
        _mint(owner(), fee);

        emit TokensMinted(to, usdcAmount, net, fee);
    }

    /// @notice Burn cGAZ to redeem USDC
    /// @param from Address burning tokens
    /// @param cgazAmount Amount of cGAZ to burn
    function burn(address from, uint256 cgazAmount) external whenNotPaused nonReentrant {
        require(from != address(0), "Invalid sender");
        require(cgazAmount > 0, "Amount must be > 0");

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

        emit TokensBurned(from, cgazAmount, feeCGAZ, usdcNet, feeUSDC);
    }

    /// @notice Pause mint and burn in emergencies
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Recover stray USDC from contract
    function recoverUSDC(address to, uint256 amount) external onlyOwner {
        usdc.safeTransfer(to, amount);
    }
    /// @notice Set the address allowed to call updatePrice

    function setUpdater(address newUpdater) external onlyOwner {
        require(newUpdater != address(0), "Invalid updater");
        updater = newUpdater;
    }

    modifier onlyUpdater() {
        require(msg.sender == updater, "Not authorized");
        _;
    }
}

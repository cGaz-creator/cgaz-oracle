// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/utils/Pausable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title cGAZ with on-chain price updates and 0.5% fees
contract CgazToken is ERC20, Ownable, AccessControl, Pausable {
    using SafeERC20 for IERC20;

    uint256 public constant FEE_BASIS_POINTS = 50; // 0.5%
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant UPDATE_INTERVAL = 3600; // 1 h
    uint256 public constant OFFCHAIN_FETCH_INTERVAL = 300; // 5 min

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    AggregatorV3Interface public oracle;
    int256 public currentPrice;
    uint256 public lastUpdated;
    IERC20 public usdc;

    event PriceUpdated(int256 price, uint256 timestamp);
    event TokensMinted(address indexed to, uint256 netAmount, uint256 fee);
    event TokensBurned(address indexed from, uint256 burnedAmount, uint256 fee);
    event USDCRecovered(address to, uint256 amount);

    constructor(string memory name_, string memory symbol_, address _oracle, IERC20 _usdc)
        ERC20(name_, symbol_)
        Ownable(msg.sender)
    {
        // 1) Rôles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        // 2) Init variables
        oracle = AggregatorV3Interface(_oracle);
        usdc = _usdc;
    }

    /// @notice Publie un nouveau prix on-chain (seul l’oracle)
    function updatePrice(int256 _price) external {
        require(msg.sender == address(oracle), "Only oracle");
        require(_price > 0, "Invalid price");
        if (lastUpdated != 0) {
            require(block.timestamp >= lastUpdated + UPDATE_INTERVAL, "Too soon");
        }
        currentPrice = _price;
        lastUpdated = block.timestamp;
        emit PriceUpdated(_price, lastUpdated);
    }

    /// @dev Check freshness
    modifier priceFresh() {
        require(lastUpdated != 0 && block.timestamp <= lastUpdated + UPDATE_INTERVAL, "Price stale");
        _;
    }

    /// @notice Mint cGAZ contre USDC
    function mint(address to, uint256 usdcAmount) external onlyOwner whenNotPaused priceFresh {
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        uint256 grossCGAZ = (usdcAmount * 10 ** decimals()) / uint256(currentPrice);
        uint256 feeCGAZ = (grossCGAZ * FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
        uint256 netCGAZ = grossCGAZ - feeCGAZ;

        _mint(to, netCGAZ);
        _mint(owner(), feeCGAZ);
        emit TokensMinted(to, netCGAZ, feeCGAZ);
    }

    /// @notice Burn cGAZ et restitue des USDC
    function burn(address from, uint256 cgazAmount) external onlyOwner whenNotPaused priceFresh {
        // 1) Split fee / net
        uint256 feeCGAZ = (cgazAmount * FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
        uint256 netCGAZ = cgazAmount - feeCGAZ;

        // 2) Burn net and mint fee in cGAZ
        _burn(from, netCGAZ);
        _mint(owner(), feeCGAZ);

        // 3) Convert to USDC
        uint256 grossUSDC = (netCGAZ * uint256(currentPrice)) / 10 ** decimals();
        uint256 feeUSDC = (grossUSDC * FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
        uint256 netUSDC = grossUSDC - feeUSDC;

        // 4) Transfers
        usdc.safeTransfer(from, netUSDC);
        usdc.safeTransfer(owner(), feeUSDC);

        emit TokensBurned(from, netCGAZ, feeCGAZ);
    }

    /// @notice Récupère USDC bloqués
    function recoverUSDC(address to, uint256 amount) external onlyOwner {
        usdc.safeTransfer(to, amount);
        emit USDCRecovered(to, amount);
    }

    /// @notice Met en pause mint & burn
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Reprend le fonctionnement
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}

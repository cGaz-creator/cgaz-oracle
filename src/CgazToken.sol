// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";

/// @title cGAZ with on-chain price updates and 0.5% fees
contract CgazToken is ERC20, Ownable {
    uint256 public constant FEE_BASIS_POINTS = 50; // 0.5%
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant UPDATE_INTERVAL = 3600; // 1h on-chain
    uint256 public constant OFFCHAIN_FETCH_INTERVAL = 300; // 5min off-chain

    address public oracle;
    int256 public currentPrice;
    uint256 public lastUpdated;

    /// @notice Instance du token USDC (mainnet)
    IERC20 public usdc;

    event PriceUpdated(int256 price, uint256 timestamp);
    event TokensMinted(address indexed to, uint256 netAmount, uint256 fee);
    event TokensBurned(address indexed from, uint256 burnedAmount, uint256 fee);

    constructor(string memory name_, string memory symbol_, address _oracle, IERC20 _usdc)
        ERC20(name_, symbol_)
        Ownable(msg.sender)
    {
        oracle = _oracle;
        usdc = _usdc;
    }
    /// @notice Publie un nouveau prix on-chain (seul `oracle` peut appeler)

    function updatePrice(int256 _price) external {
        require(msg.sender == oracle, "Only oracle");
        require(_price > 0, "Invalid price");
        if (lastUpdated != 0) {
            require(block.timestamp >= lastUpdated + UPDATE_INTERVAL, "Too soon");
        }
        currentPrice = _price;
        lastUpdated = block.timestamp;
        emit PriceUpdated(_price, lastUpdated);
    }

    function _getPrice() internal view returns (int256) {
        require(lastUpdated != 0, "Price stale");
        require(block.timestamp <= lastUpdated + UPDATE_INTERVAL, "Price stale");
        return currentPrice;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _getPrice();
        uint256 fee = (amount * FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
        uint256 net = amount - fee;
        _mint(to, net);
        _mint(owner(), fee);
        emit TokensMinted(to, net, fee);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _getPrice();
        uint256 fee = (amount * FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
        uint256 burned = amount - fee;
        _burn(from, burned);
        _transfer(from, owner(), fee);
        emit TokensBurned(from, burned, fee);
    }
    /// @notice Permet au propriétaire de récupérer des USDC bloqués par erreur

    function recoverUSDC(address to, uint256 amount) external onlyOwner {
        usdc.transfer(to, amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";

import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";

contract CgazToken is ERC20, Ownable {
    uint256 public constant FEE_BASIS_POINTS = 50;
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    address public oracle;
    int256 public currentPrice;
    uint256 public lastUpdated;
    uint256 public immutable updateInterval;

    event PriceUpdated(int256 price, uint256 timestamp);
    event TokensMinted(address indexed to, uint256 netAmount, uint256 fee);
    event TokensBurned(address indexed from, uint256 burnedAmount, uint256 fee);

    constructor(string memory name_, string memory symbol_, address _oracle, uint256 _updateInterval)
        ERC20(name_, symbol_)
        Ownable(msg.sender)
    {
        oracle = _oracle;
        updateInterval = _updateInterval;
    }

    function updatePrice(int256 _price) external {
        require(msg.sender == oracle, "Only oracle");
        require(_price > 0, "Invalid price");
        // Si ce n'est pas la première mise à jour, on vérifie l'intervalle
        if (lastUpdated != 0) {
            require(block.timestamp >= lastUpdated + updateInterval, "Too soon");
        }

        currentPrice = _price;
        lastUpdated = block.timestamp;
        emit PriceUpdated(_price, lastUpdated);
    }

    function _getPrice() internal view returns (int256) {
        require(lastUpdated != 0, "Price stale");
        require(block.timestamp <= lastUpdated + updateInterval, "Price stale");
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
}

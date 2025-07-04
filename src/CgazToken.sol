// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title CgazToken with fixed 0.5% mint/burn fee
/// @notice ERC20 token that charges a 0.5% fee on minting and burning
contract CgazToken is ERC20, Ownable {
    /// @dev Fee in basis points (50 = 0.5%)
    uint256 public constant FEE_BASIS_POINTS = 50;
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    event TokensMinted(address indexed to, uint256 netAmount, uint256 fee);
    event TokensBurned(address indexed from, uint256 burnedAmount, uint256 fee);

    /// @param name_ Token name
    /// @param symbol_ Token symbol
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) Ownable(msg.sender) {}

    /// @notice Mint tokens with a 0.5% fee paid to the owner
    /// @param to Recipient of the minted tokens
    /// @param amount The total amount to mint (fee will be deducted)
    function mint(address to, uint256 amount) external onlyOwner {
        uint256 fee = (amount * FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
        uint256 net = amount - fee;

        _mint(to, net);
        _mint(owner(), fee);
        emit TokensMinted(to, net, fee);
    }

    /// @notice Burn tokens with a 0.5% fee transferred to the owner
    /// @param from Address whose tokens will be burned
    /// @param amount The total amount to burn (fee will be deducted)
    function burn(address from, uint256 amount) external onlyOwner {
        uint256 fee = (amount * FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
        uint256 burned = amount - fee;

        _burn(from, burned);
        _transfer(from, owner(), fee);
        emit TokensBurned(from, burned, fee);
    }
}

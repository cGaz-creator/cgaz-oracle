// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {CgazToken} from "src/CgazToken.sol";

/// @dev Mock minimal ERC-20 pour nos tests
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract CgazTokenRecoverTest is Test {
    CgazToken token;
    MockERC20 mockUSDC;
    address owner = address(1);

    function setUp() public {
        // 1) déployer le mock USDC et credit 1 000 000 pour test
        mockUSDC = new MockERC20();
        mockUSDC.mint(address(this), 1e6);

        // 2) déployer notre token en lui passant le mockUSDC
        vm.prank(owner);
        token = new CgazToken("cGAZ", "CGAZ", owner, mockUSDC);

        // 3) envoyer un peu de mockUSDC sur l’adresse du contrat
        mockUSDC.transfer(address(token), 1e6);
    }

    function testRecoverUSDC() public {
        // le owner peut récupérer
        uint256 amount = 1e6;
        vm.prank(owner);
        token.recoverUSDC(address(this), amount);

        // on a bien reçu nos mockUSDC
        assertEq(mockUSDC.balanceOf(address(this)), amount);
    }
}

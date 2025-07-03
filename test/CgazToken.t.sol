// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {CgazToken} from "../src/CgazToken.sol";

contract CgazTokenTest is Test {
    CgazToken token;
    address owner = address(1);

    function setUp() public {
        // On déploie le contrat en tant qu'owner
        vm.startPrank(owner);
        token = new CgazToken("Cgaz", "CGAZ");
        vm.stopPrank();
    }

    function testMintBurnFlow() public {
        // Toutes les tx envoyées par owner
        vm.startPrank(owner);

        // Mint 100 tokens : fee = 0 (100 * 0,5% = 0.5 => arrondi à 0)
        token.mint(address(this), 100);
        assertEq(token.balanceOf(address(this)), 100, "Mint net incorrect");

        // Burn 50 tokens : fee = 0
        token.burn(address(this), 50);
        assertEq(token.balanceOf(address(this)), 50, "Burn net incorrect");

        vm.stopPrank();
    }
}

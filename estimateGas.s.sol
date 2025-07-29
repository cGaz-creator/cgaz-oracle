// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/cGAZ.sol"; // adapte le chemin selon ton arborescence

contract EstimateGas is Script {
    function run() external {
        // Charge les variables d'environnement
        address owner = vm.envAddress("DEPLOYER_ADDRESS");
        address cGAZAddress = vm.envAddress("CGAZ_ADDRESS");

        // Instancie le contrat
        cGAZ token = cGAZ(cGAZAddress);

        // Simule un appel depuis l'owner avec un nouveau prix
        vm.startBroadcast(owner);

        // Définis un prix fictif pour le test
        uint256 newPrice = 3866300; // ex : 3.8663 USD/MMBtu avec 6 décimales

        // Estimation du gas utilisé pour l'appel
        uint256 gasUsed = token.updatePrice.estimateGas(newPrice);

        vm.stopBroadcast();

        console2.log("Gas utilisé pour updatePrice():", gasUsed);
    }
}

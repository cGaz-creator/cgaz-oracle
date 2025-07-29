import dotenv from "dotenv";
import axios from "axios";
import { ethers } from "ethers";

dotenv.config();

console.log("Script déclenché à :", new Date().toISOString());

console.log("Vérification des variables d'environnement :");
const requiredVars = ["RPC_URL", "PRIVATE_KEY", "CONTRACT_ADDRESS", "CHAINLINK_DECIMALS", "API_KEY"];
const missingVars = requiredVars.filter((key) => !process.env[key]);

if (missingVars.length > 0) {
  console.error("Variables d'environnement manquantes :", missingVars);
  process.exit(1);
}
console.log("--------------------------");

// Vérification jour et heure
const now = new Date();
const utcHour = now.getUTCHours();
const day = now.getUTCDay(); // 0 = dimanche, 6 = samedi

if (day === 0 || day === 6) {
  console.log("Marché fermé (week-end). Aucune mise à jour.");
  process.exit(0);
}

if (utcHour === 21) {
  console.log("Marché fermé entre 21h et 22h UTC. Aucune mise à jour.");
  process.exit(0);
}

// Récupérer le prix du gaz via l'API
async function fetchGasPrice() {
  try {
    const res = await axios.get("https://commodities-api.com/api/latest", {
      params: {
        access_key: process.env.API_KEY,
        base: "NG",
        symbols: "USD"
      }
    });

    const rawPrice = res.data?.data?.rates?.USD;
    if (!rawPrice) throw new Error("Réponse API invalide");

    const priceInt = BigInt(Math.round(rawPrice * 10 ** Number(process.env.CHAINLINK_DECIMALS)));

    console.log("Prix NG/USD =", rawPrice, "| BigInt =", priceInt.toString());
    return priceInt;

  } catch (err) {
    console.error("Erreur API :", err.message);
    throw err;
  }
}

// Appeler le contrat
async function updateOnChain(priceInt) {
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

  const abi = [
    "function updatePrice(int256 newPrice) external",
  ];
  const contract = new ethers.Contract(process.env.CONTRACT_ADDRESS, abi, wallet);

  try {
    const tx = await contract.updatePrice(priceInt);
    console.log("Transaction envoyée :", tx.hash);
    await tx.wait();
    console.log("Transaction confirmée.");
  } catch (err) {
    console.error("Erreur dans updatePriceOnce.js :", err.message);
    process.exit(1);
  }
}

// Lancer le tout
fetchGasPrice()
  .then(updateOnChain)
  .catch((err) => {
    console.error("Erreur finale :", err.message);
    process.exit(1);
  });

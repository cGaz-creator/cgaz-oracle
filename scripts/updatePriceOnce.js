// scripts/updatePriceOnce.js
import dotenv from "dotenv";
import axios from "axios";
import { ethers } from "ethers";

dotenv.config();

console.log("Script déclenché à :", new Date().toISOString());

console.log("Vérification des variables d'environnement :");
console.log("RPC_URL =", !!process.env.RPC_URL);
console.log("PRIVATE_KEY =", !!process.env.PRIVATE_KEY);
console.log("CONTRACT_ADDRESS =", !!process.env.CONTRACT_ADDRESS);
console.log("CHAINLINK_DECIMALS =", !!process.env.CHAINLINK_DECIMALS);
console.log("API_KEY =", !!process.env.API_KEY);
console.log("--------------------------");

const {
  RPC_URL,
  PRIVATE_KEY,
  CONTRACT_ADDRESS,
  CHAINLINK_DECIMALS,
  API_KEY,
} = process.env;

const ABI = [
  "function updatePrice(int256 newPrice) external",
];

function isMarketClosedNowUTC() {
  const now = new Date();
  const day = now.getUTCDay(); // 0 = Sunday, 6 = Saturday
  const hour = now.getUTCHours();
  return day === 0 || day === 6 || hour === 21;
}

async function fetchGasPrice() {
  const url = `https://commodities-api.com/api/latest?access_key=${API_KEY}&base=NG&symbols=USD`;

  let res;
  try {
    res = await axios.get(url);
  } catch (err) {
    console.error("Erreur API :", err.message);
    throw err;
  }

  console.log("Réponse API :", JSON.stringify(res.data, null, 2));

  const rawPrice = res.data?.data?.rates?.USD;

  if (typeof rawPrice === "undefined") {
    throw new Error("Champ 'rates.USD' absent dans la réponse");
  }

  const price = Number(rawPrice);
  if (isNaN(price)) {
    throw new Error("Prix retourné invalide (NaN)");
  }

  const factor = 10 ** Number(CHAINLINK_DECIMALS);
  const scaled = BigInt(Math.round(price * factor));

  console.log("Prix NG/USD =", price, "| BigInt =", scaled.toString());

  return scaled;
}

async function main() {
  if (isMarketClosedNowUTC()) {
    console.log("Marché fermé (weekend ou entre 21h-22h UTC). Pas de mise à jour.");
    return;
  }

  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, wallet);

  const newPrice = await fetchGasPrice();

  const tx = await contract.updatePrice(newPrice);
  console.log("Transaction envoyée :", tx.hash);
  await tx.wait();
  console.log("Transaction confirmée.");
}

main().catch((err) => {
  console.error("Erreur dans updatePriceOnce.js :", err.message);
  process.exit(1);
});

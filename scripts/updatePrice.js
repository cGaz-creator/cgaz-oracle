import { ethers } from "ethers";
import dotenv from "dotenv";
dotenv.config();

const DEPLOYER_KEY = process.env.DEPLOYER_KEY?.trim();
const ARB_SEPOLIA_RPC = process.env.ARB_SEPOLIA_RPC?.trim();
const CHAINLINK_FEED_SEPOLIA = process.env.CHAINLINK_FEED_SEPOLIA?.trim();

if (!DEPLOYER_KEY || !ARB_SEPOLIA_RPC || !CHAINLINK_FEED_SEPOLIA) {
  console.error("Missing required environment variables.");
  process.exit(1);
}

const provider = new ethers.JsonRpcProvider(ARB_SEPOLIA_RPC);
const wallet = new ethers.Wallet(DEPLOYER_KEY, provider);

const abi = ["function updatePrice(uint256 newPrice) external"];
const contract = new ethers.Contract(CHAINLINK_FEED_SEPOLIA, abi, wallet);

// Vérifie si le marché est ouvert
function isMarketOpen(date = new Date()) {
  const utcHour = date.getUTCHours();
  const day = date.getUTCDay(); // 0 = dimanche, 6 = samedi
  if (day === 6) return false;
  if (day === 0 && utcHour < 23) return false;
  if (utcHour >= 21 && utcHour < 22) return false;
  return true;
}

// Simule un prix entre 3.70 et 4.20 (6 décimales)
function generateMockPrice() {
  const raw = (Math.random() * (4.20 - 3.70) + 3.70).toFixed(6);
  return ethers.parseUnits(raw, 6);
}

async function main() {
  if (!isMarketOpen()) {
    console.log("Marché fermé, mise à jour annulée.");
    return;
  }

  const mockPrice = generateMockPrice();
  console.log("Prix simulé (scaled, 6 décimales) :", mockPrice.toString());

  const tx = await contract.updatePrice(mockPrice);
  console.log("Transaction envoyée :", tx.hash);
  await tx.wait();
  console.log("Mise à jour du prix effectuée.");
}

main().catch((err) => {
  console.error("Erreur dans updatePrice.js :", err);
});

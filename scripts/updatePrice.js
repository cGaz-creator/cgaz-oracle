// scripts/updatePrice.js
import "dotenv/config";
import { ethers } from "ethers";
import fetch from "node-fetch";

const {
  DEPLOYER_KEY,
  ARB_SEPOLIA_RPC,
  CHAINLINK_FEED_SEPOLIA,
  EIA_API_KEY,
} = process.env;

if (!DEPLOYER_KEY || !ARB_SEPOLIA_RPC || !CHAINLINK_FEED_SEPOLIA || !EIA_API_KEY) {
  console.error("Missing required environment variables.");
  process.exit(1);
}

const provider = new ethers.JsonRpcProvider(ARB_SEPOLIA_RPC);
const wallet = new ethers.Wallet(DEPLOYER_KEY, provider);
console.log("Wallet address:", wallet.address);

const abi = ["function updatePrice(uint256 newPrice) external"];
const contract = new ethers.Contract(CHAINLINK_FEED_SEPOLIA, abi, wallet);

async function fetchGasPriceUSD() {
  const url = `https://api.stlouisfed.org/fred/series/observations?series_id=PNGASJPUSDM&api_key=${process.env.FRED_API_KEY}&file_type=json&limit=1`;
  try {
    const res = await fetch(url);
    const json = await res.json();

    if (!json.observations || !json.observations.length) {
      console.error("FRED API response is empty or invalid:", JSON.stringify(json, null, 2));
      return null;
    }

    const value = parseFloat(json.observations[0].value);
    console.log("Latest gas price from FRED (USD):", value);
    return value;
  } catch (err) {
    console.error("Failed to fetch gas price from FRED:", err);
    return null;
  }
}

async function main() {
  const priceUSD = await fetchGasPriceUSD();
  if (!priceUSD) {
    console.error("Could not retrieve gas price.");
    return;
  }

  const scaledPrice = ethers.parseUnits(priceUSD.toFixed(6), 18);
  console.log("Scaled for on-chain use:", scaledPrice.toString());

  const tx = await contract.updatePrice(scaledPrice);
  console.log("Transaction sent:", tx.hash);
  await tx.wait();
  console.log("Price updated successfully.");
}

main().catch((err) => {
  console.error("Script execution failed:", err);
});

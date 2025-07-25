import { ethers } from "ethers";
import fetch from "node-fetch";

const DEPLOYER_KEY = process.env.DEPLOYER_KEY?.trim();
const ARB_SEPOLIA_RPC = process.env.ARB_SEPOLIA_RPC?.trim();
const CHAINLINK_FEED_SEPOLIA = process.env.CHAINLINK_FEED_SEPOLIA?.trim();
const FRED_API_KEY = process.env.FRED_API_KEY?.trim();

if (!DEPLOYER_KEY || !ARB_SEPOLIA_RPC || !CHAINLINK_FEED_SEPOLIA || !FRED_API_KEY) {
  console.error("Missing required environment variables:");
  console.error("DEPLOYER_KEY:", !!DEPLOYER_KEY);
  console.error("ARB_SEPOLIA_RPC:", !!ARB_SEPOLIA_RPC);
  console.error("CHAINLINK_FEED_SEPOLIA:", !!CHAINLINK_FEED_SEPOLIA);
  console.error("FRED_API_KEY:", !!FRED_API_KEY);
  process.exit(1);
}

const provider = new ethers.JsonRpcProvider(ARB_SEPOLIA_RPC);
const wallet = new ethers.Wallet(DEPLOYER_KEY, provider);

const abi = ["function updatePrice(int256 newPrice) external"];
const contract = new ethers.Contract(CHAINLINK_FEED_SEPOLIA, abi, wallet);

async function fetchGasPriceUSD() {
  const url = `https://api.stlouisfed.org/fred/series/observations?series_id=PNGASJPUSDM&api_key=${FRED_API_KEY}&file_type=json&limit=1`;
  try {
    const res = await fetch(url);
    const json = await res.json();

    if (!json.observations || !json.observations.length) {
      console.error("FRED API response is invalid or empty:", JSON.stringify(json, null, 2));
      return null;
    }

    const value = parseFloat(json.observations[0].value);
    console.log("Latest gas price from FRED (USD):", value);
    return value;
  } catch (err) {
    console.error("Failed to fetch gas price:", err);
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
  console.log("Scaled price:", scaledPrice.toString());

  const tx = await contract.updatePrice(scaledPrice);
  console.log("Transaction sent:", tx.hash);
  await tx.wait();
  console.log("Price updated successfully.");
}

main().catch((err) => {
  console.error("Script execution failed:", err);
});

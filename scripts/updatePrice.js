// scripts/updatePrice.js
import "dotenv/config";
import { ethers } from "ethers";
import fetch from "node-fetch";

const { DEPLOYER_KEY, ARB_SEPOLIA_RPC, CHAINLINK_FEED_SEPOLIA } = process.env;

if (!DEPLOYER_KEY || !ARB_SEPOLIA_RPC || !CHAINLINK_FEED_SEPOLIA) {
  console.error("Missing required environment variables.");
  process.exit(1);
}

const provider = new ethers.JsonRpcProvider(ARB_SEPOLIA_RPC);
const wallet = new ethers.Wallet(DEPLOYER_KEY, provider);

const abi = ["function updatePrice(uint256 newPrice) external"];
const contract = new ethers.Contract(CHAINLINK_FEED_SEPOLIA, abi, wallet);

async function fetchGasPriceUSD() {
  const url = "https://api.eia.gov/series/?api_key=YOUR_EIA_KEY&series_id=NG.RNGWHHD.D";
  try {
    const response = await fetch(url);
    const json = await response.json();
    const latest = json.series[0].data[0]; // [date, price]
    return parseFloat(latest[1]);
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
  console.log("Fetched gas price:", priceUSD, "USD/mmBTU");
  console.log("Scaled for on-chain use:", scaledPrice.toString());

  const tx = await contract.updatePrice(scaledPrice);
  console.log("Transaction sent:", tx.hash);
  await tx.wait();
  console.log("Price updated successfully.");
}

main().catch((err) => {
  console.error("Script execution failed:", err);
});

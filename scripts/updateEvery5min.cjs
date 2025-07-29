require("dotenv").config();
const axios = require("axios");
const { ethers } = require("ethers");

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
  const hour = now.getUTCHours(); // UTC hour

  if (day === 0 || day === 6) return true;
  if (hour === 21) return true;
  return false;
}

async function fetchGasPrice() {
  const url = `https://commodities-api.com/api/latest?access_key=${API_KEY}&base=USD&symbols=NG`;
  const res = await axios.get(url);
  const rawPrice = res.data?.data?.rates?.NG;

  if (!rawPrice) throw new Error("Gas price not found in API response");

  const price = 1 / rawPrice; // Convert to NGUSD
  return BigInt(Math.round(price * 10 ** Number(CHAINLINK_DECIMALS)));
}

async function loopUpdate() {
const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, wallet);

  while (true) {
    const now = new Date().toISOString();
    try {
      if (isMarketClosedNowUTC()) {
        console.log(`[${now}] Market closed — skipping update`);
      } else {
        const newPrice = await fetchGasPrice();
        const tx = await contract.updatePrice(newPrice);
        console.log(`[${now}] Sent updatePrice tx: ${tx.hash}`);
        await tx.wait();
        console.log(`[${now}] Confirmed.`);
      }
    } catch (err) {
      console.error(`[${now}] ERROR: ${err.message}`);
    }

    console.log(`[${now}] Waiting 5 minutes...`);
    await new Promise((r) => setTimeout(r, 5 * 60 * 1000)); // 5 min
  }
}

loopUpdate();

#!/usr/bin/env node

const axios = require("axios");

const SCREEPS_TOKEN = process.env.SCREEPS_TOKEN;
const SCREEPS_API_URL = "https://screeps.com/api/user/memory-segment";

async function fetchSegments(shard) {
  const segments = Array.from({ length: 91 }, (_, i) => i).join(",");

  const response = await axios.get(SCREEPS_API_URL, {
    headers: {
      "X-Token": SCREEPS_TOKEN,
    },
    params: {
      segment: segments,
      shard: shard,
    },
  });

  return response.data;
}

async function main() {
  const shard = process.argv[2] || "shard3";
  const data = await fetchSegments(shard);
  console.log(JSON.stringify(data, null, 2));
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = { fetchSegments };

#!/usr/bin/env node

require("dotenv").config();

const axios = require("axios");

const SCREEPS_TOKEN = process.env.SCREEPS_TOKEN;

async function fetchSegments(shard) {
  const segments = Array.from({ length: 91 }, (_, i) => i).join(",");
  
  const urlPrefix = shard === "shardSeason" ? "season/" : "";
  const apiUrl = `https://screeps.com/${urlPrefix}api/user/memory-segment`;

  const response = await axios.get(apiUrl, {
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
  const shard = process.argv[2] || "shardX";
  const data = await fetchSegments(shard);
  console.log(JSON.stringify(data, null, 2));
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = { fetchSegments };

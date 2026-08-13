#!/usr/bin/env node

require("dotenv").config();

const axios = require("axios");
const { buildMemorySegmentUrl, getScreepsConfig } = require("./config");

async function fetchSegments(shard) {
  const segments = Array.from({ length: 91 }, (_, i) => i).join(",");
  const { token, baseUrl } = getScreepsConfig();
  const apiUrl = buildMemorySegmentUrl(baseUrl, shard);

  const response = await axios.get(apiUrl, {
    headers: {
      "X-Token": token,
    },
    params: {
      segment: segments,
      shard: shard,
    },
  });

  return response.data;
}

async function main() {
  const { shards } = getScreepsConfig();
  const shard = process.argv[2] || shards[0];
  const data = await fetchSegments(shard);
  console.log(JSON.stringify(data, null, 2));
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = { fetchSegments };

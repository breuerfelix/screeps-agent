require("dotenv").config();

const DEFAULT_BASE_URL = "https://screeps.com";
const DEFAULT_SHARDS = ["shardSeason", "shardX"];

function normalizeBaseUrl(baseUrl = DEFAULT_BASE_URL) {
  return baseUrl.trim().replace(/\/+$/, "");
}

function parseShardList(value) {
  if (!value) {
    return [...DEFAULT_SHARDS];
  }

  const shards = value
    .split(",")
    .map((shard) => shard.trim())
    .filter(Boolean);

  if (shards.length === 0) {
    throw new Error("SCREEPS_SHARDS must define at least one shard");
  }

  return shards;
}

function getScreepsConfig(env = process.env) {
  return {
    baseUrl: normalizeBaseUrl(env.SCREEPS_BASE_URL || DEFAULT_BASE_URL),
    shards: parseShardList(env.SCREEPS_SHARDS),
    token: env.SCREEPS_TOKEN,
  };
}

function buildMemorySegmentUrl(baseUrl, shard) {
  const normalizedBaseUrl = normalizeBaseUrl(baseUrl);
  const useSeasonApi =
    normalizedBaseUrl === DEFAULT_BASE_URL && shard === "shardSeason";

  return `${normalizedBaseUrl}/${useSeasonApi ? "season/" : ""}api/user/memory-segment`;
}

module.exports = {
  DEFAULT_BASE_URL,
  DEFAULT_SHARDS,
  buildMemorySegmentUrl,
  getScreepsConfig,
  normalizeBaseUrl,
  parseShardList,
};

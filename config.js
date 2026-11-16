require("dotenv").config({ quiet: true });

const DEFAULT_BASE_URL = "https://screeps.com";
const DEFAULT_SHARDS = ["shardSeason", "shardX"];

function normalizeBaseUrl(baseUrl = DEFAULT_BASE_URL) {
  return baseUrl.trim().replace(/\/+$/, "");
}

function normalizeOptionalUrl(value) {
  if (!value) {
    return null;
  }

  const normalized = String(value).trim().replace(/\/+$/, "");
  return normalized || null;
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

function getDefaultShard(shards = DEFAULT_SHARDS) {
  return shards.length === 1 ? shards[0] : null;
}

function getScreepsConfig(env = process.env) {
  return {
    baseUrl: normalizeBaseUrl(env.SCREEPS_BASE_URL || DEFAULT_BASE_URL),
    shards: parseShardList(env.SCREEPS_SHARDS),
    token: env.SCREEPS_TOKEN,
  };
}

function getLokiConfig(env = process.env) {
  const url = normalizeOptionalUrl(env.LOKI_URL);

  return {
    url,
    enabled: Boolean(url),
  };
}

function buildScreepsUrl(baseUrl, shard, path) {
  const normalizedBaseUrl = normalizeBaseUrl(baseUrl);
  const useSeasonPath =
    normalizedBaseUrl === DEFAULT_BASE_URL && shard === "shardSeason";
  const prefix = useSeasonPath ? "/season" : "";
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  return `${normalizedBaseUrl}${prefix}${normalizedPath}`;
}

function buildSeasonApiUrl(baseUrl, shard, resourcePath) {
  return buildScreepsUrl(baseUrl, shard, `/api/${resourcePath.replace(/^\/+/, "")}`);
}

function buildMemorySegmentUrl(baseUrl, shard) {
  return buildSeasonApiUrl(baseUrl, shard, "user/memory-segment");
}

module.exports = {
  DEFAULT_BASE_URL,
  DEFAULT_SHARDS,
  buildMemorySegmentUrl,
  buildScreepsUrl,
  buildSeasonApiUrl,
  getDefaultShard,
  getLokiConfig,
  getScreepsConfig,
  normalizeBaseUrl,
  normalizeOptionalUrl,
  parseShardList,
};

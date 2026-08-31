const test = require("node:test");
const assert = require("node:assert/strict");

function loadConfig() {
  delete require.cache[require.resolve("../config")];
  return require("../config");
}

function resetEnv() {
  process.env.SCREEPS_BASE_URL = "";
  process.env.SCREEPS_SHARDS = "";
  process.env.LOKI_URL = "";
}

test("uses backward-compatible defaults for official deployment", () => {
  resetEnv();

  const { getScreepsConfig, buildMemorySegmentUrl, buildScreepsUrl } =
    loadConfig();
  const config = getScreepsConfig();

  assert.equal(config.baseUrl, "https://screeps.com");
  assert.deepEqual(config.shards, ["shardSeason", "shardX"]);
  assert.equal(
    buildMemorySegmentUrl(config.baseUrl, "shardSeason"),
    "https://screeps.com/season/api/user/memory-segment",
  );
  assert.equal(
    buildMemorySegmentUrl(config.baseUrl, "shardX"),
    "https://screeps.com/api/user/memory-segment",
  );
  assert.equal(
    buildScreepsUrl(config.baseUrl, "shardSeason", "/socket/1/session/websocket"),
    "https://screeps.com/season/socket/1/session/websocket",
  );
});

test("reads base URL and shard list from environment for private deployment", () => {
  resetEnv();
  process.env.SCREEPS_BASE_URL = "https://screeps.private.example/";
  process.env.SCREEPS_SHARDS = "  coolify , shard3  ,custom  ";

  const { getScreepsConfig, buildMemorySegmentUrl } = loadConfig();
  const config = getScreepsConfig();

  assert.equal(config.baseUrl, "https://screeps.private.example");
  assert.deepEqual(config.shards, ["coolify", "shard3", "custom"]);
  assert.equal(
    buildMemorySegmentUrl(config.baseUrl, "coolify"),
    "https://screeps.private.example/api/user/memory-segment",
  );
});

test("rejects empty shard lists after parsing", () => {
  resetEnv();
  process.env.SCREEPS_SHARDS = " , , ";

  const { getScreepsConfig } = loadConfig();

  assert.throws(
    () => getScreepsConfig(),
    /SCREEPS_SHARDS must define at least one shard/,
  );
});

test("normalizes optional Loki URL and enables log capture only when set", () => {
  resetEnv();
  process.env.LOKI_URL = "http://loki.internal:3100/";

  const { getLokiConfig } = loadConfig();
  const config = getLokiConfig();

  assert.equal(config.url, "http://loki.internal:3100");
  assert.equal(config.enabled, true);

  resetEnv();
  const disabledConfig = loadConfig().getLokiConfig();
  assert.equal(disabledConfig.url, null);
  assert.equal(disabledConfig.enabled, false);
});

test("uses single configured shard as websocket log fallback label", () => {
  resetEnv();

  const { getDefaultShard } = loadConfig();

  assert.equal(getDefaultShard(["coolify"]), "coolify");
  assert.equal(getDefaultShard(["shardSeason", "shardX"]), null);
});

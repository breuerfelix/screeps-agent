const test = require("node:test");
const assert = require("node:assert/strict");

function loadConfig() {
  delete require.cache[require.resolve("../config")];
  return require("../config");
}

test("uses backward-compatible defaults for official deployment", () => {
  delete process.env.SCREEPS_BASE_URL;
  delete process.env.SCREEPS_SHARDS;

  const { getScreepsConfig, buildMemorySegmentUrl } = loadConfig();
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
});

test("reads base URL and shard list from environment for private deployment", () => {
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
  process.env.SCREEPS_SHARDS = " , , ";

  const { getScreepsConfig } = loadConfig();

  assert.throws(
    () => getScreepsConfig(),
    /SCREEPS_SHARDS must define at least one shard/,
  );
});

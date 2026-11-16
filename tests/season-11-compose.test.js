const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const composePath = path.join(__dirname, "..", "docker-compose.season-11.yml");

test("Season 11 compose targets only the seasonal shard", () => {
  const compose = fs.readFileSync(composePath, "utf8");

  assert.match(compose, /SCREEPS_TOKEN: \$\{SCREEPS_SEASON11_TOKEN:\?[^}]+\}/);
  assert.match(compose, /SCREEPS_BASE_URL: https:\/\/screeps\.com/);
  assert.match(compose, /SCREEPS_SHARDS: shardSeason/);
  assert.match(compose, /VICTORIA_METRICS_URL:/);
  assert.match(compose, /LOKI_URL:/);
  assert.match(compose, /external:\s+true/);
  assert.match(compose, /name: \$\{MONITORING_NETWORK:-monitoring_monitoring\}/);
  assert.doesNotMatch(compose, /YOUR_|replace-with|admin:jamo/);
});

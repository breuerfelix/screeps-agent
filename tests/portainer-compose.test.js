const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

test("Portainer compose keeps official-world deployment on GitOps-managed main image", () => {
  const compose = fs.readFileSync(
    path.join(__dirname, "..", "docker-compose.portainer.yml"),
    "utf8",
  );

  assert.match(
    compose,
    /image:\s+\$\{SCREEPS_AGENT_IMAGE:-ghcr\.io\/breuerfelix\/screeps-agent:main\}/,
  );
  assert.match(
    compose,
    /SCREEPS_BASE_URL:\s+\$\{SCREEPS_BASE_URL:-https:\/\/screeps\.com\}/,
  );
  assert.match(
    compose,
    /SCREEPS_SHARDS:\s+\$\{SCREEPS_SHARDS:-shardSeason,shardX\}/,
  );
  assert.match(compose, /LOKI_URL:\s+\$\{LOKI_URL:-\}/);
  assert.match(
    compose,
    /name:\s+\$\{MONITORING_NETWORK:-monitoring_monitoring\}/,
  );
  assert.match(compose, /external:\s+true/);
  assert.doesNotMatch(compose, /env_file:/);
  assert.doesNotMatch(compose, /depends_on:/);
});

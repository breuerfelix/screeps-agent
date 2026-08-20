const test = require("node:test");
const assert = require("node:assert/strict");

const { parseSegments } = require("../segment_parser");
const { extractMetrics } = require("../ingest_segment");

test("parses official Screeps array responses without changing indexes", () => {
  const response = {
    data: [
      "",
      JSON.stringify({ unixTimestamp: 123, cpu: { used: 4.5 } }),
      null,
    ],
  };

  assert.deepEqual(parseSegments(response), {
    0: null,
    1: { unixTimestamp: 123, cpu: { used: 4.5 } },
    2: null,
  });
});

test("parses private-server string responses into a single segment payload", () => {
  const response = {
    ok: 1,
    data: JSON.stringify({
      unixTimestamp: 7407400,
      cpu: { getUsed: 21.02743 },
      memory: { used: 15180 },
    }),
  };

  const segments = parseSegments(response);

  assert.deepEqual(segments, {
    0: {
      unixTimestamp: 7407400,
      cpu: { getUsed: 21.02743 },
      memory: { used: 15180 },
    },
  });

  const metrics = extractMetrics(segments[0], "coolify");
  assert.deepEqual(
    metrics.find((metric) => metric.metric.__name__ === "screeps_cpu_getUsed"),
    {
      metric: { __name__: "screeps_cpu_getUsed", shard: "coolify" },
      value: 21.02743,
      timestamp: 7407400,
    },
  );
});

test("parses numeric-key segment maps if a Screeps endpoint returns them", () => {
  const response = {
    data: {
      0: JSON.stringify({ unixTimestamp: 7, cpu: { bucket: 10000 } }),
      1: "",
    },
  };

  assert.deepEqual(parseSegments(response), {
    0: { unixTimestamp: 7, cpu: { bucket: 10000 } },
    1: null,
  });
});

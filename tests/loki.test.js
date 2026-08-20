const test = require("node:test");
const assert = require("node:assert/strict");

const { buildLokiPayload } = require("../loki");

test("groups log entries into Loki streams by label set", () => {
  const payload = buildLokiPayload([
    {
      labels: { source: "screeps_console", shard: "coolify", message_type: "log" },
      line: "line-1",
      timestampNs: "1000000",
    },
    {
      labels: { source: "screeps_console", shard: "coolify", message_type: "log" },
      line: "line-2",
      timestampNs: "2000000",
    },
    {
      labels: {
        source: "screeps_console",
        shard: "coolify",
        message_type: "result",
      },
      line: "line-3",
      timestampNs: "3000000",
    },
  ]);

  assert.deepEqual(payload, {
    streams: [
      {
        stream: {
          source: "screeps_console",
          shard: "coolify",
          message_type: "log",
        },
        values: [
          ["1000000", "line-1"],
          ["2000000", "line-2"],
        ],
      },
      {
        stream: {
          source: "screeps_console",
          shard: "coolify",
          message_type: "result",
        },
        values: [["3000000", "line-3"]],
      },
    ],
  });
});

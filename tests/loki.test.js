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

test("keeps structured JSON fields in one Loki line without turning them into labels", () => {
  const line = JSON.stringify({
    schema_version: 1,
    timestamp: "2026-08-21T18:30:42.123Z",
    level: "error",
    message: "Failed to refresh creep",
    source: "overmind",
    logger: "Overlord",
    context: { creep: "worker-42", overlord: "W1N1>worker" },
  });

  const payload = buildLokiPayload([
    {
      labels: {
        source: "screeps_console",
        server_host: "screeps.felixbreuer.me",
        shard: "coolify",
        message_type: "log",
      },
      line,
      timestampNs: "1787337042123000000",
    },
  ]);

  assert.deepEqual(payload.streams[0].stream, {
    source: "screeps_console",
    server_host: "screeps.felixbreuer.me",
    shard: "coolify",
    message_type: "log",
  });
  assert.equal(payload.streams[0].values[0][0], "1787337042123000000");
  assert.equal(payload.streams[0].values[0][1], line);
  assert.deepEqual(JSON.parse(payload.streams[0].values[0][1]).context, {
    creep: "worker-42",
    overlord: "W1N1>worker",
  });
});

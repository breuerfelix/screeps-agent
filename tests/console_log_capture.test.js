const test = require("node:test");
const assert = require("node:assert/strict");

const {
  buildConsoleChannel,
  buildConsoleLogEntries,
  buildSocketUrl,
  parseSockJsFrame,
} = require("../console_log_capture");

test("parses SockJS batch frames into inner messages", () => {
  const frames = parseSockJsFrame('a["time 1","protocol 14"]');

  assert.deepEqual(frames, [
    { type: "message", value: "time 1" },
    { type: "message", value: "protocol 14" },
  ]);
});

test("builds console channel name from user id", () => {
  assert.equal(
    buildConsoleChannel("a43a1abaee978fc"),
    "user:a43a1abaee978fc/console",
  );
});

test("builds websocket url from Screeps base URL", () => {
  const url = buildSocketUrl("https://screeps.felixbreuer.me", 147);

  assert.match(
    url,
    /^wss:\/\/screeps\.felixbreuer\.me\/socket\/147\/[a-z0-5]{8}\/websocket$/,
  );
});

test("creates Loki-ready console log entries with shard fallback", () => {
  const entries = buildConsoleLogEntries(
    {
      messages: {
        log: ["hello"],
        results: ["world"],
      },
      error: "boom",
    },
    {
      baseLabels: {
        source: "screeps_console",
        server_host: "screeps.felixbreuer.me",
        username: "hermes",
      },
      defaultShard: "coolify",
      timestampMs: 1787210043487,
    },
  );

  assert.deepEqual(
    entries.map((entry) => ({ labels: entry.labels, line: entry.line })),
    [
      {
        labels: {
          source: "screeps_console",
          server_host: "screeps.felixbreuer.me",
          username: "hermes",
          shard: "coolify",
          message_type: "log",
        },
        line: "hello",
      },
      {
        labels: {
          source: "screeps_console",
          server_host: "screeps.felixbreuer.me",
          username: "hermes",
          shard: "coolify",
          message_type: "result",
        },
        line: "world",
      },
      {
        labels: {
          source: "screeps_console",
          server_host: "screeps.felixbreuer.me",
          username: "hermes",
          shard: "coolify",
          message_type: "error",
        },
        line: "boom",
      },
    ],
  );

  assert.ok(entries.every((entry) => entry.timestampNs === "1787210043487000000"));
});

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
    entries.map((entry) => ({
      labels: entry.labels,
      line: JSON.parse(entry.line).message,
    })),
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

test("keeps schema-v1 JSON lines intact and timestamps them from the event", () => {
  const line = JSON.stringify({
    schema_version: 1,
    timestamp: "2026-08-21T18:30:42.123Z",
    level: "error",
    message: "Failed to refresh creep",
    source: "overmind",
    logger: "Overlord",
    tick: 12345678,
    context: {
      creep: "worker-42",
      overlord: "W1N1>worker",
      room: "W1N1",
      operation: "refresh",
    },
    data: { attempt: 2 },
  });

  const entries = buildConsoleLogEntries(
    { messages: { log: [line] }, shard: "coolify" },
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

  assert.equal(entries.length, 1);
  assert.equal(entries[0].line, line);
  assert.equal(entries[0].timestampNs, "1787337042123000000");
  assert.deepEqual(entries[0].labels, {
    source: "screeps_console",
    server_host: "screeps.felixbreuer.me",
    username: "hermes",
    shard: "coolify",
    message_type: "log",
  });
  assert.deepEqual(JSON.parse(entries[0].line).context, {
    creep: "worker-42",
    overlord: "W1N1>worker",
    room: "W1N1",
    operation: "refresh",
  });
});

test("uses ingestion time when a structured event timestamp is invalid", () => {
  const line = JSON.stringify({
    schema_version: 1,
    timestamp: "not-a-timestamp",
    level: "warning",
    message: "timestamp unavailable",
    source: "overmind",
    logger: "Segmenter",
  });

  const entries = buildConsoleLogEntries(
    { messages: { log: [line] } },
    { timestampMs: 1787210043487 },
  );

  assert.equal(entries[0].line, line);
  assert.equal(entries[0].timestampNs, "1787210043487000000");
});

test("wraps legacy and malformed lines as searchable JSON fallback events", () => {
  const entries = buildConsoleLogEntries(
    {
      messages: {
        log: [
          "[2026-08-21T18:30:42.123Z] INFO: old format",
          '{"schema_version":1,"level":"info"}',
        ],
      },
    },
    {
      baseLabels: { source: "screeps_console" },
      defaultShard: "coolify",
      timestampMs: 1787210043487,
    },
  );

  assert.equal(entries.length, 2);
  const legacy = JSON.parse(entries[0].line);
  const malformed = JSON.parse(entries[1].line);

  assert.deepEqual(legacy, {
    schema_version: 1,
    timestamp: "2026-08-20T07:14:03.487Z",
    level: "info",
    message: "[2026-08-21T18:30:42.123Z] INFO: old format",
    source: "screeps_console",
    logger: "legacy",
    data: {
      legacy: true,
      raw_line: "[2026-08-21T18:30:42.123Z] INFO: old format",
    },
  });
  assert.equal(malformed.data.legacy, true);
  assert.equal(malformed.data.parse_error, true);
  assert.equal(malformed.data.raw_line, '{"schema_version":1,"level":"info"}');
  assert.ok(entries.every((entry) => entry.timestampNs === "1787210043487000000"));
});

test("converts websocket payload errors into one structured agent event", () => {
  const entries = buildConsoleLogEntries(
    { error: "console stream failed", shard: "coolify" },
    {
      baseLabels: { source: "screeps_console" },
      defaultShard: "coolify",
      timestampMs: 1787210043487,
    },
  );

  assert.equal(entries.length, 1);
  assert.deepEqual(JSON.parse(entries[0].line), {
    schema_version: 1,
    timestamp: "2026-08-20T07:14:03.487Z",
    level: "error",
    message: "console stream failed",
    source: "screeps_agent",
    logger: "console_stream",
    error: {
      name: "ScreepsConsoleError",
      message: "console stream failed",
    },
  });
  assert.equal(entries[0].labels.message_type, "error");
});

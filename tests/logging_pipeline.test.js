const test = require("node:test");
const assert = require("node:assert/strict");

const { buildConsoleLogEntries } = require("../console_log_capture");
const { buildLokiPayload } = require("../loki");

const labels = {
  source: "screeps_console",
  server_host: "private.example",
  username: "hermes",
};

function eventLine(event) {
  const line = JSON.stringify(event);
  assert.equal(line.includes("\u001b"), false);
  assert.equal(line.includes("\n"), false);
  return line;
}

test("final Loki payload supports level and context filtering", () => {
  const entries = buildConsoleLogEntries(
    {
      shard: "coolify",
      messages: {
        log: [
          eventLine({
            schema_version: 1,
            timestamp: "2026-08-21T18:30:42.123Z",
            level: "info",
            message: "spawned worker-42",
            source: "overmind",
            logger: "Overlord",
            tick: 12345678,
            context: {
              creep: "worker-42",
              overlord: "W1N1>worker",
              room: "W1N1",
              role: "worker",
            },
            data: { body_cost: 250 },
          }),
          eventLine({
            schema_version: 1,
            timestamp: "2026-08-21T18:30:42.124Z",
            level: "debug",
            message: "requesting miner",
            source: "overmind",
            logger: "Creep",
            tick: 12345678,
            context: {
              creep: "miner-7",
              overlord: "W1N1>source0",
              room: "W1N1",
              role: "miner",
            },
          }),
          eventLine({
            schema_version: 1,
            timestamp: "2026-08-21T18:30:42.125Z",
            level: "warning",
            message: "spawn queue delayed",
            source: "overmind",
            logger: "Overlord",
            tick: 12345678,
            context: {
              overlord: "W1N1>worker",
              room: "W1N1",
              subsystem: "mining",
            },
          }),
          eventLine({
            schema_version: 1,
            timestamp: "2026-08-21T18:30:42.126Z",
            level: "error",
            message: "refresh failed",
            source: "overmind",
            logger: "console.log",
            tick: 12345678,
            error: { name: "TypeError", message: "refresh failed" },
          }),
        ],
      },
    },
    {
      baseLabels: labels,
      defaultShard: "coolify",
      timestampMs: 1787210043487,
    },
  );

  const payload = buildLokiPayload(entries);
  assert.equal(payload.streams.length, 1);
  assert.deepEqual(payload.streams[0].stream, {
    ...labels,
    shard: "coolify",
    message_type: "log",
  });

  const records = payload.streams.flatMap((stream) =>
    stream.values.map(([timestampNs, line]) => ({
      timestampNs,
      ...JSON.parse(line),
    })),
  );
  assert.equal(records.length, 4);
  assert.ok(records.every((record) => record.schema_version === 1));
  assert.ok(records.every((record) => typeof record.level === "string"));

  const errors = records.filter((record) => record.level === "error");
  assert.equal(errors.length, 1);
  assert.equal(errors[0].message, "refresh failed");

  const workerEvents = records.filter(
    (record) => record.context?.overlord === "W1N1>worker",
  );
  assert.deepEqual(
    workerEvents.map((record) => record.message),
    ["spawned worker-42", "spawn queue delayed"],
  );
  assert.equal(workerEvents[0].context.creep, "worker-42");
  assert.equal(workerEvents[1].context.subsystem, "mining");

  for (const record of records) {
    assert.equal(Object.hasOwn(record, "context_overlord"), false);
    assert.equal(Object.hasOwn(record, "level_label"), false);
  }
});

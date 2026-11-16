const test = require("node:test");
const assert = require("node:assert/strict");
const axios = require("axios");
const ScreepsAgent = require("../agent");

const {
  buildConsoleChannel,
  buildConsoleLogEntries,
  buildSocketUrl,
  parseSockJsFrame,
  probeConsoleLogCapture,
  wrapSockJsMessage,
} = require("../console_log_capture");

const BASE_URL = "https://screeps.felixbreuer.me";
const LOKI_URL = "http://loki.example.test:3100";
const TOKEN = "test-token";

function setupAgent(t) {
  const env = {
    SCREEPS_BASE_URL: BASE_URL,
    SCREEPS_SHARDS: "coolify",
    SCREEPS_TOKEN: TOKEN,
    LOKI_URL,
  };
  for (const [key, value] of Object.entries(env)) {
    const previous = process.env[key];
    process.env[key] = value;
    t.after(() => {
      if (previous === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = previous;
      }
    });
  }

  const agent = new ScreepsAgent();
  agent.log = {
    info: t.mock.fn(),
    error: t.mock.fn(),
  };
  const exit = t.mock.method(process, "exit", () => {});
  return { agent, exit };
}

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

test("exits on the first identity failure without logging credentials", async (t) => {
  const { agent, exit } = setupAgent(t);
  const get = t.mock.method(axios, "get", async () => {
    throw Object.assign(new Error(`getaddrinfo EAI_AGAIN ${TOKEN}`), {
      code: "EAI_AGAIN",
    });
  });

  await agent.startConsoleLogs();

  assert.equal(get.mock.callCount(), 1);
  assert.equal(get.mock.calls[0].arguments[1].timeout, 10000);
  assert.equal(exit.mock.callCount(), 1);
  assert.deepEqual(exit.mock.calls[0].arguments, [1]);
  assert.equal(
    agent.log.error.mock.calls[0].arguments[0],
    "Console websocket streamer exited",
  );
});

test("the probe submits the selected shard and reports a rejected command", { timeout: 2000 }, async (t) => {
  t.mock.method(axios, "get", async () => ({
    data: { _id: "probe-user-id", username: "probe-user" },
  }));
  const post = t.mock.method(axios, "post", async () => ({
    data: { error: "invalid shard" },
  }));
  const connected = Promise.withResolvers();
  const socket = new EventTarget();
  socket.send = t.mock.fn();
  socket.close = t.mock.fn();
  t.mock.method(globalThis, "WebSocket", function () {
    connected.resolve();
    return socket;
  });

  const result = assert.rejects(probeConsoleLogCapture({
    baseUrl: "https://screeps.com",
    token: TOKEN,
    shards: ["shardX"],
    logger: { info() {} },
    timeoutMs: 1000,
  }), /Set SCREEPS_SHARDS to one active shard/);
  await connected.promise;
  socket.dispatchEvent(new MessageEvent("message", { data: 'a["auth ok"]' }));
  await result;

  const [url, body] = post.mock.calls[0].arguments;
  assert.equal(url, "https://screeps.com/api/user/console");
  assert.equal(body.shard, "shardX");
  assert.equal(socket.close.mock.callCount(), 1);
});

test("forwards console logs to Loki and exits when the websocket closes", { timeout: 2000 }, async (t) => {
  const { agent, exit } = setupAgent(t);
  const get = t.mock.method(axios, "get", async () => ({
    data: { _id: "hermes-id", username: "hermes" },
  }));

  const connected = Promise.withResolvers();
  const socket = new EventTarget();
  socket.send = t.mock.fn();
  const connect = t.mock.method(globalThis, "WebSocket", function () {
    connected.resolve();
    return socket;
  });

  const pushed = Promise.withResolvers();
  t.mock.method(axios, "post", async (url, payload) => {
    pushed.resolve({ url, payload });
    return { status: 204 };
  });

  const stream = agent.startConsoleLogs();
  await connected.promise;
  assert.equal(get.mock.calls[0].arguments[0], `${BASE_URL}/api/auth/me`);

  const channel = "user:hermes-id/console";
  socket.dispatchEvent(new Event("open"));
  socket.dispatchEvent(new MessageEvent("message", { data: 'a["auth ok"]' }));
  assert.deepEqual(socket.send.mock.calls.map(({ arguments: args }) => args[0]), [
    wrapSockJsMessage(`auth ${TOKEN}`),
    wrapSockJsMessage(`subscribe ${channel}`),
  ]);

  const line = "console forwarding test";
  const message = JSON.stringify([channel, { messages: { log: [line] } }]);
  socket.dispatchEvent(new MessageEvent("message", {
    data: `a${wrapSockJsMessage(message)}`,
  }));

  const { url, payload } = await pushed.promise;
  assert.equal(url, `${LOKI_URL}/loki/api/v1/push`);
  assert.equal(payload.streams.length, 1);
  assert.deepEqual(payload.streams[0].stream, {
    source: "screeps_console",
    server_host: "screeps.felixbreuer.me",
    username: "hermes",
    shard: "coolify",
    message_type: "log",
  });
  assert.equal(payload.streams[0].values[0][1], line);

  socket.dispatchEvent(new Event("close"));
  await stream;
  assert.equal(connect.mock.callCount(), 1);
  assert.equal(exit.mock.callCount(), 1);
  assert.deepEqual(exit.mock.calls[0].arguments, [1]);
});

test("normal shutdown exits zero", (t) => {
  const { agent, exit } = setupAgent(t);

  agent.shutdown();

  assert.equal(exit.mock.callCount(), 1);
  assert.deepEqual(exit.mock.calls[0].arguments, [0]);
  assert.equal(agent.log.error.mock.callCount(), 0);
});

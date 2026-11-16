const test = require("node:test");
const assert = require("node:assert/strict");
const { execFile } = require("node:child_process");
const { once } = require("node:events");
const { mkdtemp, rm, writeFile } = require("node:fs/promises");
const { createServer } = require("node:http");
const { tmpdir } = require("node:os");
const { join, resolve } = require("node:path");
const { promisify } = require("node:util");
const cron = require("node-cron");
const ScreepsAgent = require("../agent");
const { pushLogsToLoki } = require("../loki");

const execFileAsync = promisify(execFile);

test("loads .env and sends metrics and logs over HTTP", async (t) => {
  const directory = await mkdtemp(join(tmpdir(), "screeps-agent-"));
  t.after(() => rm(directory, { recursive: true }));
  await writeFile(
    join(directory, ".env"),
    "SCREEPS_TOKEN=smoke-token\nSCREEPS_SHARDS=smoke\n",
  );

  const requests = [];
  const server = createServer(async (request, response) => {
    const url = new URL(request.url, "http://127.0.0.1");
    const chunks = [];
    for await (const chunk of request) chunks.push(chunk);
    requests.push({
      method: request.method,
      path: url.pathname,
      params: url.searchParams,
      headers: request.headers,
      body: Buffer.concat(chunks).toString(),
    });

    if (url.pathname === "/api/user/memory-segment") {
      const segment = { unixTimestamp: 123, cpu: { used: 42 } };
      response.setHeader("Content-Type", "application/json");
      response.end(JSON.stringify({ data: [JSON.stringify(segment)] }));
    } else {
      response.writeHead(204).end();
    }
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => new Promise((done) => server.close(done)));
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  await execFileAsync(process.execPath, [resolve(__dirname, "../agent.js")], {
    cwd: directory,
    env: {
      NODE_ENV: "production",
      TEST_MODE: "true",
      SCREEPS_BASE_URL: baseUrl,
      VICTORIA_METRICS_URL: baseUrl,
    },
    timeout: 10000,
  });
  const entry = { labels: { shard: "smoke" }, line: "hello", timestampNs: "123" };
  assert.equal(await pushLogsToLoki([entry], baseUrl), true);

  assert.deepEqual(requests.map(({ method, path }) => [method, path]), [
    ["GET", "/api/user/memory-segment"],
    ["POST", "/api/v1/import"],
    ["POST", "/loki/api/v1/push"],
  ]);
  const [screeps, metrics, loki] = requests;
  assert.equal(screeps.headers["x-token"], "smoke-token");
  assert.equal(screeps.params.get("shard"), "smoke");
  assert.equal(screeps.params.get("segment").split(",").length, 91);
  assert.equal(metrics.headers["content-type"], "application/x-jsonlines");
  assert.deepEqual(JSON.parse(metrics.body), {
    metric: { __name__: "screeps_cpu_used", shard: "smoke" },
    values: [42],
    timestamps: [123],
  });
  assert.equal(loki.headers["content-type"], "application/json");
  assert.deepEqual(JSON.parse(loki.body), {
    streams: [{ stream: entry.labels, values: [["123", "hello"]] }],
  });
});

test("runs collection at the scheduled cron boundary", async (t) => {
  t.mock.timers.enable({
    apis: ["Date", "setTimeout"],
    now: new Date(2026, 0, 1, 12, 1, 59),
  });
  const agent = new ScreepsAgent();
  agent.log.info = () => {};
  t.mock.method(agent, "startConsoleLogs", () => {});
  const collect = t.mock.method(agent, "processAllShards", async () => {});
  const registerSignal = t.mock.method(process, "on");

  t.after(() => {
    for (const task of cron.getTasks().values()) task.destroy();
    for (const { arguments: [signal, handler] } of registerSignal.mock.calls) {
      if (signal === "SIGINT" || signal === "SIGTERM") {
        process.removeListener(signal, handler);
      }
    }
  });
  agent.start();

  t.mock.timers.tick(999);
  assert.equal(collect.mock.callCount(), 0);

  t.mock.timers.tick(1);
  await new Promise(setImmediate);
  assert.equal(collect.mock.callCount(), 1);
});

#!/usr/bin/env node

const axios = require("axios");
const { compile } = require("html-to-text");
const { URL } = require("node:url");
const {
  getDefaultShard,
  getLokiConfig,
  getScreepsConfig,
} = require("./config");
const { pushLogsToLoki, toTimestampNs } = require("./loki");

const DEFAULT_PROBE_TIMEOUT_MS = 30000;
const IDENTITY_TIMEOUT_MS = 10000;
const toConsoleText = compile({
  wordwrap: false,
  whitespaceCharacters: "",
  selectors: [{ selector: "a", options: { ignoreHref: true } }],
});

function randomSessionId() {
  const alphabet = "abcdefghijklmnopqrstuvwxyz012345";
  let value = "";

  for (let index = 0; index < 8; index += 1) {
    value += alphabet[Math.floor(Math.random() * alphabet.length)];
  }

  return value;
}

function buildSocketUrl(baseUrl, serverId = Math.floor(Math.random() * 1000)) {
  const wsBase = baseUrl.replace(/^http/, "ws").replace(/\/+$/, "");
  return `${wsBase}/socket/${serverId}/${randomSessionId()}/websocket`;
}

function buildConsoleChannel(userId) {
  return `user:${userId}/console`;
}

function wrapSockJsMessage(message) {
  return JSON.stringify([message]);
}

function parseSockJsFrame(frame) {
  if (frame === "o") {
    return [{ type: "open" }];
  }

  if (frame === "h") {
    return [{ type: "heartbeat" }];
  }

  if (frame.startsWith("a")) {
    return JSON.parse(frame.slice(1)).map((message) => ({
      type: "message",
      value: message,
    }));
  }

  if (frame.startsWith("m")) {
    return [{ type: "message", value: JSON.parse(frame.slice(1)) }];
  }

  if (frame.startsWith("c")) {
    return [{ type: "close", value: JSON.parse(frame.slice(1)) }];
  }

  return [{ type: "unknown", value: frame }];
}

function buildBaseLogLabels(baseUrl, username) {
  const parsedUrl = new URL(baseUrl);

  return {
    source: "screeps_console",
    server_host: parsedUrl.host,
    username,
  };
}

function buildConsoleLogEntries(payload, options = {}) {
  const shard = payload?.shard || options.defaultShard || "unknown";
  const timestampNs = toTimestampNs(options.timestampMs);
  const labels = {
    ...(options.baseLabels || {}),
    shard,
  };
  const entries = [];

  for (const line of payload?.messages?.log || []) {
    entries.push({
      labels: { ...labels, message_type: "log" },
      line: toConsoleText(String(line)),
      timestampNs,
    });
  }

  for (const line of payload?.messages?.results || []) {
    entries.push({
      labels: { ...labels, message_type: "result" },
      line: toConsoleText(String(line)),
      timestampNs,
    });
  }

  if (payload?.error) {
    entries.push({
      labels: { ...labels, message_type: "error" },
      line: toConsoleText(String(payload.error)),
      timestampNs,
    });
  }

  return entries;
}

async function fetchUserIdentity(baseUrl, token) {
  const response = await axios.get(`${baseUrl}/api/auth/me`, {
    headers: {
      "X-Token": token,
      "X-Username": token,
    },
    timeout: IDENTITY_TIMEOUT_MS,
  });

  return {
    userId: response.data._id,
    username: response.data.username,
  };
}

async function postConsoleExpression(baseUrl, token, expression, shard) {
  const response = await axios.post(
    `${baseUrl}/api/user/console`,
    { expression, shard },
    {
      headers: {
        "X-Token": token,
        "X-Username": token,
      },
    },
  );

  return response.data;
}

async function probeConsoleLogCapture({
  baseUrl,
  token,
  shards,
  logger = console,
  timeoutMs = DEFAULT_PROBE_TIMEOUT_MS,
}) {
  logger.info("Connecting to the Screeps console WebSocket...");
  const user = await fetchUserIdentity(baseUrl, token);
  const defaultShard = getDefaultShard(shards);
  const consoleChannel = buildConsoleChannel(user.userId);
  const probeId = `hermes-ws-probe-${Date.now()}`;
  const resultId = `hermes-ws-result-${Date.now()}`;
  const expression = `console.log(\"${probeId}\"); \"${resultId}\"`;
  const wsUrl = buildSocketUrl(baseUrl);

  return await new Promise((resolve, reject) => {
    const socket = new WebSocket(wsUrl);
    let finished = false;
    let consoleCommandResponse = null;

    const timeout = setTimeout(() => {
      finish(new Error("Timed out waiting for Screeps console websocket probe"));
    }, timeoutMs);

    function finish(error, result) {
      if (finished) {
        return;
      }

      finished = true;
      clearTimeout(timeout);

      try {
        socket.close();
      } catch {
        // best effort
      }

      if (error) {
        reject(error);
        return;
      }

      resolve(result);
    }

    socket.addEventListener("open", () => {
      socket.send(wrapSockJsMessage(`auth ${token}`));
    });

    socket.addEventListener("error", () => {
      finish(new Error("Screeps console websocket connection failed"));
    });

    socket.addEventListener("close", () => {
      finish(new Error("Screeps console websocket closed before the probe completed"));
    });

    socket.addEventListener("message", (event) => {
      handleMessage(String(event.data)).catch(finish);
    });

    async function handleMessage(rawFrame) {
      for (const frame of parseSockJsFrame(rawFrame)) {
        if (frame.type !== "message") {
          continue;
        }

        const message = frame.value;

        if (message.startsWith("auth ok")) {
          socket.send(wrapSockJsMessage(`subscribe ${consoleChannel}`));
          logger.info("WebSocket authenticated. Sending test console line...");
          consoleCommandResponse = await postConsoleExpression(
            baseUrl,
            token,
            expression,
            defaultShard ?? undefined,
          );
          if (consoleCommandResponse?.error === "invalid shard") {
            throw new Error("Screeps rejected the console shard. Set SCREEPS_SHARDS to one active shard.");
          }
          if (consoleCommandResponse?.error) {
            throw new Error("Screeps rejected the test console command");
          }
          continue;
        }

        if (message.startsWith("auth failed")) {
          finish(new Error("Screeps websocket auth failed"));
          return;
        }

        if (!message.startsWith("[")) {
          continue;
        }

        const [channel, payload] = JSON.parse(message);
        if (channel !== consoleChannel) {
          continue;
        }

        const logMessages = payload?.messages?.log || [];
        const resultMessages = payload?.messages?.results || [];
        const sawProbe = logMessages.some((line) => String(line).includes(probeId));
        const sawResult = resultMessages.some((line) =>
          String(line).includes(resultId),
        );

        if (!sawProbe && !sawResult) {
          continue;
        }

        finish(null, {
          wsUrl,
          consoleChannel,
          probeId,
          resultId,
          expression,
          consoleCommandResponse,
          payload,
          entries: buildConsoleLogEntries(payload, {
            baseLabels: buildBaseLogLabels(baseUrl, user.username),
            defaultShard,
          }),
          user,
        });
        return;
      }
    }
  });
}

function connectConsoleStreamSession({
  baseUrl,
  token,
  lokiUrl,
  consoleChannel,
  baseLabels,
  defaultShard,
  logger,
}) {
  return new Promise((_resolve, reject) => {
    const socket = new WebSocket(buildSocketUrl(baseUrl));

    socket.addEventListener("open", () => {
      socket.send(wrapSockJsMessage(`auth ${token}`));
    });

    socket.addEventListener("error", () => {
      reject(new Error("Screeps console websocket connection failed"));
    });

    socket.addEventListener("close", () => {
      reject(new Error("Screeps console websocket closed"));
    });

    socket.addEventListener("message", (event) => {
      handleMessage(String(event.data)).catch(reject);
    });

    async function handleMessage(rawFrame) {
      for (const frame of parseSockJsFrame(rawFrame)) {
        if (frame.type !== "message") {
          continue;
        }

        const message = frame.value;

        if (message.startsWith("auth ok")) {
          socket.send(wrapSockJsMessage(`subscribe ${consoleChannel}`));
          logger.info(`Subscribed to ${consoleChannel} websocket stream`);
          continue;
        }

        if (message.startsWith("auth failed")) {
          throw new Error("Screeps websocket auth failed");
        }

        if (!message.startsWith("[")) {
          continue;
        }

        const [channel, payload] = JSON.parse(message);
        if (channel !== consoleChannel) {
          continue;
        }

        const entries = buildConsoleLogEntries(payload, {
          baseLabels,
          defaultShard,
        });

        if (entries.length === 0) {
          continue;
        }

        await pushLogsToLoki(entries, lokiUrl);
        logger.info(
          `Forwarded ${entries.length} Screeps console line(s) to Loki for shard ${entries[0].labels.shard}`,
        );
      }
    }
  });
}

async function startConsoleLogStreaming({ logger = console } = {}) {
  const { baseUrl, shards, token } = getScreepsConfig();
  const { enabled, url: lokiUrl } = getLokiConfig();

  if (!enabled) {
    logger.info("LOKI_URL not set. Screeps websocket log capture disabled.");
    return;
  }

  const user = await fetchUserIdentity(baseUrl, token);
  const consoleChannel = buildConsoleChannel(user.userId);
  const defaultShard = getDefaultShard(shards);
  const baseLabels = buildBaseLogLabels(baseUrl, user.username);

  logger.info(
    `Starting Screeps websocket log capture for ${user.username} via ${baseUrl}`,
  );

  await connectConsoleStreamSession({
    baseUrl,
    token,
    lokiUrl,
    consoleChannel,
    baseLabels,
    defaultShard,
    logger,
  });
}

module.exports = {
  DEFAULT_PROBE_TIMEOUT_MS,
  buildBaseLogLabels,
  buildConsoleChannel,
  buildConsoleLogEntries,
  buildSocketUrl,
  fetchUserIdentity,
  parseSockJsFrame,
  postConsoleExpression,
  probeConsoleLogCapture,
  randomSessionId,
  startConsoleLogStreaming,
  wrapSockJsMessage,
};

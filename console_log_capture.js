#!/usr/bin/env node

const axios = require("axios");
const { URL } = require("node:url");
const {
  getDefaultShard,
  getLokiConfig,
  getScreepsConfig,
} = require("./config");
const { pushLogsToLoki, toTimestampNs } = require("./loki");

const DEFAULT_PROBE_TIMEOUT_MS = 30000;
const DEFAULT_RECONNECT_DELAY_MS = 5000;
const STRUCTURED_LOG_LEVELS = new Set([
  "fatal",
  "error",
  "warning",
  "alert",
  "info",
  "debug",
]);

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

function normalizeTimestampMs(timestampMs = Date.now()) {
  return Number.isFinite(timestampMs) ? timestampMs : Date.now();
}

function isStructuredLogEvent(value) {
  return (
    value &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    value.schema_version === 1 &&
    typeof value.timestamp === "string" &&
    STRUCTURED_LOG_LEVELS.has(value.level) &&
    typeof value.message === "string" &&
    typeof value.source === "string" &&
    typeof value.logger === "string"
  );
}

function toRawLogLine(value) {
  if (typeof value === "string") {
    return value;
  }

  try {
    const serialized = JSON.stringify(value);
    return serialized === undefined ? String(value) : serialized;
  } catch {
    return String(value);
  }
}

function buildFallbackLogEvent(rawLine, timestampMs, parseError) {
  const data = {
    legacy: true,
    raw_line: rawLine,
  };

  if (parseError) {
    data.parse_error = true;
  }

  return {
    schema_version: 1,
    timestamp: new Date(timestampMs).toISOString(),
    level: "info",
    message: rawLine,
    source: "screeps_console",
    logger: "legacy",
    data,
  };
}

function normalizeConsoleLogLine(value, ingestionTimestampMs) {
  const rawLine = toRawLogLine(value);
  const trimmedLine = rawLine.trim();
  const timestampMs = normalizeTimestampMs(ingestionTimestampMs);
  let event;

  try {
    event = JSON.parse(trimmedLine);
  } catch {
    event = null;
  }

  if (!isStructuredLogEvent(event)) {
    const parseError =
      trimmedLine.startsWith("{") ||
      trimmedLine.startsWith('"') ||
      (trimmedLine.startsWith("[") &&
        !/^\[[^\]\r\n]+\]\s/.test(trimmedLine));
    event = buildFallbackLogEvent(rawLine, timestampMs, parseError);

    return {
      line: JSON.stringify(event),
      timestampNs: toTimestampNs(timestampMs),
    };
  }

  const eventTimestampMs = Date.parse(event.timestamp);

  return {
    line: trimmedLine,
    timestampNs: toTimestampNs(
      Number.isNaN(eventTimestampMs) ? timestampMs : eventTimestampMs,
    ),
  };
}

function buildConsoleErrorEntry(error, labels, timestampMs) {
  const messageValue =
    typeof error === "string"
      ? error
      : error?.message || toRawLogLine(error);
  const message =
    typeof messageValue === "string" ? messageValue : toRawLogLine(messageValue);
  const event = {
    schema_version: 1,
    timestamp: new Date(timestampMs).toISOString(),
    level: "error",
    message,
    source: "screeps_agent",
    logger: "console_stream",
    error: {
      name: "ScreepsConsoleError",
      message,
    },
  };

  return {
    labels: { ...labels, message_type: "error" },
    line: JSON.stringify(event),
    timestampNs: toTimestampNs(timestampMs),
  };
}

function buildConsoleLogEntries(payload, options = {}) {
  const shard = payload?.shard || options.defaultShard || "unknown";
  const timestampMs = normalizeTimestampMs(options.timestampMs);
  const labels = {
    ...(options.baseLabels || {}),
    shard,
  };
  const entries = [];

  for (const line of payload?.messages?.log || []) {
    const normalized = normalizeConsoleLogLine(line, timestampMs);
    entries.push({
      labels: { ...labels, message_type: "log" },
      line: normalized.line,
      timestampNs: normalized.timestampNs,
    });
  }

  for (const line of payload?.messages?.results || []) {
    const normalized = normalizeConsoleLogLine(line, timestampMs);
    entries.push({
      labels: { ...labels, message_type: "result" },
      line: normalized.line,
      timestampNs: normalized.timestampNs,
    });
  }

  if (payload?.error) {
    entries.push(buildConsoleErrorEntry(payload.error, labels, timestampMs));
  }

  return entries;
}

async function fetchUserIdentity(baseUrl, token) {
  const response = await axios.get(`${baseUrl}/api/auth/me`, {
    headers: {
      "X-Token": token,
      "X-Username": token,
    },
  });

  return {
    userId: response.data._id,
    username: response.data.username,
  };
}

async function postConsoleExpression(baseUrl, token, expression) {
  const response = await axios.post(
    `${baseUrl}/api/user/console`,
    { expression },
    {
      headers: {
        "X-Token": token,
        "X-Username": token,
      },
    },
  );

  return response.data;
}

function delay(ms, signal) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      cleanup();
      resolve();
    }, ms);

    function onAbort() {
      cleanup();
      reject(new Error("Aborted"));
    }

    function cleanup() {
      clearTimeout(timeout);
      signal?.removeEventListener("abort", onAbort);
    }

    signal?.addEventListener("abort", onAbort, { once: true });
  });
}

async function probeConsoleLogCapture({
  baseUrl,
  token,
  shards,
  logger = console,
  timeoutMs = DEFAULT_PROBE_TIMEOUT_MS,
}) {
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

    socket.addEventListener("message", (event) => {
      Promise.resolve(handleMessage(String(event.data))).catch((error) => {
        finish(error);
      });
    });

    async function handleMessage(rawFrame) {
      for (const frame of parseSockJsFrame(rawFrame)) {
        if (frame.type !== "message") {
          continue;
        }

        const message = frame.value;

        if (message.startsWith("auth ok")) {
          socket.send(wrapSockJsMessage(`subscribe ${consoleChannel}`));
          consoleCommandResponse = await postConsoleExpression(
            baseUrl,
            token,
            expression,
          );
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
  signal,
}) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(buildSocketUrl(baseUrl));
    let settled = false;

    function settle(error) {
      if (settled) {
        return;
      }

      settled = true;
      signal?.removeEventListener("abort", abortHandler);

      if (error) {
        reject(error);
        return;
      }

      resolve();
    }

    function abortHandler() {
      try {
        socket.close();
      } finally {
        settle();
      }
    }

    signal?.addEventListener("abort", abortHandler, { once: true });

    socket.addEventListener("open", () => {
      socket.send(wrapSockJsMessage(`auth ${token}`));
    });

    socket.addEventListener("error", () => {
      settle(new Error("Screeps console websocket connection failed"));
    });

    socket.addEventListener("close", () => {
      settle();
    });

    socket.addEventListener("message", (event) => {
      Promise.resolve(handleMessage(String(event.data))).catch((error) => {
        settle(error);
      });
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

async function startConsoleLogStreaming({ logger = console, signal } = {}) {
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

  while (!signal?.aborted) {
    try {
      await connectConsoleStreamSession({
        baseUrl,
        token,
        lokiUrl,
        consoleChannel,
        baseLabels,
        defaultShard,
        logger,
        signal,
      });
    } catch (error) {
      if (signal?.aborted) {
        break;
      }

      logger.error(`Console websocket stream failed: ${error.message}`);
    }

    if (signal?.aborted) {
      break;
    }

    logger.warn(
      `Reconnecting Screeps console websocket in ${DEFAULT_RECONNECT_DELAY_MS / 1000}s`,
    );

    try {
      await delay(DEFAULT_RECONNECT_DELAY_MS, signal);
    } catch {
      break;
    }
  }
}

module.exports = {
  DEFAULT_PROBE_TIMEOUT_MS,
  buildBaseLogLabels,
  buildConsoleChannel,
  buildConsoleLogEntries,
  buildSocketUrl,
  isStructuredLogEvent,
  normalizeConsoleLogLine,
  fetchUserIdentity,
  parseSockJsFrame,
  postConsoleExpression,
  probeConsoleLogCapture,
  randomSessionId,
  startConsoleLogStreaming,
  wrapSockJsMessage,
};

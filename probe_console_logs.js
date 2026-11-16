#!/usr/bin/env node

require("dotenv").config({ quiet: true });

const { isAxiosError } = require("axios");
const { getLokiConfig, getScreepsConfig } = require("./config");
const { probeConsoleLogCapture } = require("./console_log_capture");
const { pushLogsToLoki } = require("./loki");

async function main() {
  const screepsConfig = getScreepsConfig();
  const lokiConfig = getLokiConfig();

  const result = await probeConsoleLogCapture({
    baseUrl: screepsConfig.baseUrl,
    token: screepsConfig.token,
    shards: screepsConfig.shards,
    logger: { info: console.error },
  });

  let lokiPushSucceeded = false;
  if (lokiConfig.enabled) {
    lokiPushSucceeded = await pushLogsToLoki(result.entries, lokiConfig.url);
  }

  console.log(
    JSON.stringify(
      {
        wsUrl: result.wsUrl,
        consoleChannel: result.consoleChannel,
        observedShard: result.entries[0]?.labels?.shard || null,
        logMessages: result.payload?.messages?.log || [],
        resultMessages: result.payload?.messages?.results || [],
        lokiPushConfigured: lokiConfig.enabled,
        lokiPushSucceeded,
        consoleCommandResponse: result.consoleCommandResponse,
      },
      null,
      2,
    ),
  );
}

main().catch((error) => {
  console.error(isAxiosError(error) ? "Screeps console probe HTTP request failed" : error.message);
  process.exit(1);
});

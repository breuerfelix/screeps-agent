#!/usr/bin/env node

require("dotenv").config({ quiet: true });

const cron = require("node-cron");
const { processShards } = require("./one_shot");
const { startConsoleLogStreaming } = require("./console_log_capture");
const { getScreepsConfig } = require("./config");

class ScreepsAgent {
  constructor() {
    this.shutdownController = new AbortController();
    this.log = {
      info: (msg) => console.log(`[${new Date().toISOString()}] INFO: ${msg}`),
      warn: (msg) => console.log(`[${new Date().toISOString()}] WARN: ${msg}`),
      error: (msg) =>
        console.log(`[${new Date().toISOString()}] ERROR: ${msg}`),
    };
  }

  async processAllShards() {
    const { shards, baseUrl } = getScreepsConfig();
    this.log.info(
      `Starting data collection cycle for shards ${shards.join(", ")} via ${baseUrl}...`,
    );
    await processShards(shards, this.log);
    this.log.info("Data collection cycle completed successfully");
  }

  startConsoleLogs() {
    startConsoleLogStreaming({
      logger: this.log,
      signal: this.shutdownController.signal,
    }).catch((error) => {
      if (!this.shutdownController.signal.aborted) {
        this.log.error(`Console websocket streamer exited: ${error.message}`);
      }
    });
  }

  shutdown() {
    if (this.shutdownController.signal.aborted) {
      return;
    }

    this.log.info("Shutting down gracefully...");
    this.shutdownController.abort();
    process.exit(0);
  }

  start() {
    this.log.info("Starting Screeps Agent - collecting data every 2 minutes");
    this.startConsoleLogs();

    cron.schedule("*/2 * * * *", async () => {
      try {
        await this.processAllShards();
      } catch (error) {
        this.log.error(`Collection cycle failed: ${error.message}`);
      }
    });

    this.log.info("Agent scheduled and running...");

    process.on("SIGINT", () => {
      this.log.info("Received SIGINT");
      this.shutdown();
    });

    process.on("SIGTERM", () => {
      this.log.info("Received SIGTERM");
      this.shutdown();
    });
  }
}

function main() {
  const agent = new ScreepsAgent();

  if (process.env.TEST_MODE?.toLowerCase() === "true") {
    agent.log.info("Running in test mode - single collection cycle");
    agent
      .processAllShards()
      .then(() => process.exit(0))
      .catch((error) => {
        agent.log.error(`Test mode failed: ${error.message}`);
        process.exit(1);
      });
  } else {
    agent.log.info("Running in production mode - continuous collection");
    agent.start();
  }
}

if (require.main === module) {
  main();
}

module.exports = ScreepsAgent;

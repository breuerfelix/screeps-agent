#!/usr/bin/env node

require("dotenv").config();

const cron = require("node-cron");
const { processShards } = require("./one_shot");

const SHARDS = ["shard1", "shard3", "shardSeason"];

class ScreepsAgent {
  constructor() {
    this.log = {
      info: (msg) => console.log(`[${new Date().toISOString()}] INFO: ${msg}`),
      warn: (msg) => console.log(`[${new Date().toISOString()}] WARN: ${msg}`),
      error: (msg) =>
        console.log(`[${new Date().toISOString()}] ERROR: ${msg}`),
    };
  }

  async processAllShards() {
    this.log.info("Starting data collection cycle for all shards...");
    await processShards(SHARDS);
    this.log.info("Data collection cycle completed successfully");
  }

  start() {
    this.log.info("Starting Screeps Agent - collecting data every 2 minutes");

    // Schedule to run every 2 minutes
    cron.schedule("*/2 * * * *", async () => {
      try {
        await this.processAllShards();
      } catch (error) {
        this.log.error(`Collection cycle failed: ${error.message}`);
      }
    });

    // // Run once immediately
    // this.processAllShards().catch((error) => {
    //   this.log.error(`Initial collection failed: ${error.message}`);
    // });

    this.log.info("Agent scheduled and running...");

    // Keep the process alive
    process.on("SIGINT", () => {
      this.log.info("Received SIGINT, shutting down gracefully...");
      process.exit(0);
    });

    process.on("SIGTERM", () => {
      this.log.info("Received SIGTERM, shutting down gracefully...");
      process.exit(0);
    });
  }
}

// Main entry point
function main() {
  const agent = new ScreepsAgent();

  // Test mode if TEST_MODE environment variable is set
  if (process.env.TEST_MODE?.toLowerCase() === "true") {
    console.log("Running in test mode - single collection cycle");
    agent
      .processAllShards()
      .then(() => process.exit(0))
      .catch((error) => {
        console.error(`Test mode failed: ${error.message}`);
        process.exit(1);
      });
  } else {
    console.log("Running in production mode - continuous collection");
    agent.start();
  }
}

if (require.main === module) {
  main();
}

module.exports = ScreepsAgent;

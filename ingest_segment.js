#!/usr/bin/env node

const fs = require("fs");
const axios = require("axios");

const VICTORIA_METRICS_URL =
  process.env.VICTORIA_METRICS_URL || "http://localhost:8428";

function extractMetrics(segmentData, shard) {
  const metrics = [];
  const timestamp = segmentData.unixTimestamp;

  // Recursive function to extract metrics from nested objects
  function extractRecursive(obj, baseName, baseLabels = {}) {
    Object.entries(obj).forEach(([key, value]) => {
      if (key === "unixTimestamp") return; // Skip timestamp field

      if (typeof value === "number") {
        // Direct numeric value - create metric
        metrics.push({
          metric: { __name__: `${baseName}_${key}`, ...baseLabels },
          value: value,
          timestamp,
        });
      } else if (
        typeof value === "object" &&
        value !== null &&
        !Array.isArray(value)
      ) {
        // Check if this looks like a special case that needs labels
        if (isColonyData(baseName, key)) {
          // Colony data - add colony as label
          extractRecursive(value, `screeps_colony`, {
            ...baseLabels,
            colony: key,
          });
        } else if (isResourceData(baseName, key, value)) {
          // Resource data - add resource as label
          Object.entries(value).forEach(([resource, amount]) => {
            if (typeof amount === "number") {
              metrics.push({
                metric: { __name__: baseName, ...baseLabels, resource },
                value: amount,
                timestamp,
              });
            } else if (typeof amount === "object" && amount !== null) {
              // Handle nested resource data (like trader.bought.resource.amount)
              extractRecursive(amount, baseName, { ...baseLabels, resource });
            }
          });
        } else if (isRoomData(baseName, key)) {
          // Room-specific data - add room as label
          extractRecursive(value, baseName, { ...baseLabels, room: key });
        } else if (isRoleData(baseName, key, value)) {
          // Creep role data - add role as label
          extractRecursive(value, baseName, { ...baseLabels, role: key });
        } else if (isUsageTypeData(baseName, key, value)) {
          // Usage type data - add usage_type as label
          extractRecursive(value, baseName, { ...baseLabels, usage_type: key });
        } else if (isPhaseData(baseName, key, value)) {
          // Phase data - add phase as label
          extractRecursive(value, baseName, { ...baseLabels, phase: key });
        } else {
          // Regular nested object - continue with concatenated name
          extractRecursive(value, `${baseName}_${key}`, baseLabels);
        }
      }
    });
  }

  // Helper functions to identify special data patterns
  function isColonyData(baseName, key) {
    return baseName === "screeps" && key === "colonies";
  }

  function isResourceData(baseName, key, value) {
    const resourceKeys = [
      "assets",
      "resources",
      "bought",
      "sold",
      "prices",
      "incomingResources",
      "outgoingResources",
      "sendCosts",
    ];
    return resourceKeys.includes(key) && typeof value === "object";
  }

  function isRoomData(baseName, key) {
    // Room names follow pattern like E8N26, W1S1, etc.
    return /^[EW]\d+[NS]\d+$/.test(key);
  }

  function isRoleData(baseName, key, value) {
    return (
      baseName.includes("creeps") &&
      typeof value === "object" &&
      (value.hasOwnProperty("current") || value.hasOwnProperty("needed"))
    );
  }

  function isUsageTypeData(baseName, key, value) {
    return (
      (baseName.includes("energyUsage") || baseName.includes("usage")) &&
      typeof value === "object" &&
      !value.hasOwnProperty("current")
    );
  }

  function isPhaseData(baseName, key, value) {
    return baseName.includes("cpu_usage") && typeof value === "number";
  }

  // Start extraction from root
  extractRecursive(segmentData, "screeps", { shard });

  return metrics;
}

async function pushToVictoriaMetrics(metrics) {
  const url = `${VICTORIA_METRICS_URL}/api/v1/import`;

  // Convert to VictoriaMetrics import format (needs values array)
  const lines = metrics.map((metric) => {
    return JSON.stringify({
      metric: metric.metric,
      values: [metric.value],
      timestamps: [metric.timestamp],
    });
  });

  const data = lines.join("\n");

  console.log("Sample lines being sent:");
  console.log(lines.slice(0, 3).join("\n"));
  console.log("...");

  const response = await axios.post(url, data, {
    headers: {
      "Content-Type": "application/x-jsonlines",
    },
  });

  return response.status === 204;
}

async function main() {
  const segmentData = JSON.parse(
    fs.readFileSync("sample_segment.json", "utf8"),
  );

  console.log("Extracting metrics from segment data...");
  const metrics = extractMetrics(segmentData);

  console.log(`Extracted ${metrics.length} metrics`);
  console.log("\nSample metrics:");
  metrics.slice(0, 10).forEach((metric, i) => {
    console.log(`${i + 1}. ${metric.metric.__name__} = ${metric.value}`);
    const labels = Object.entries(metric.metric)
      .filter(([key]) => key !== "__name__")
      .map(([key, value]) => `${key}="${value}"`)
      .join(", ");
    if (labels) {
      console.log(`   Labels: {${labels}}`);
    }
  });

  console.log("\nPushing to VictoriaMetrics...");
  const success = await pushToVictoriaMetrics(metrics);

  if (success) {
    console.log("✓ Successfully pushed metrics to VictoriaMetrics");
    console.log("\nExample queries you can now run:");
    console.log('- screeps_colony_rcl_level{shard="shard3",colony="E8N26"}');
    console.log(
      '- screeps_colony_assets{shard="shard3",colony="E6N28",resource="energy"}',
    );
    console.log('- screeps_cpu_used{shard="shard3"}');
    console.log('- screeps_trader_credits{shard="shard3"}');
    console.log(
      '- screeps_terminal_network_assets{shard="shard3",resource="energy"}',
    );
  } else {
    console.log("✗ Failed to push metrics");
  }
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = { extractMetrics, pushToVictoriaMetrics };

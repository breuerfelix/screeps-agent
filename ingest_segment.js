#!/usr/bin/env node

require("dotenv").config({ quiet: true });

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
          // Colony data - iterate over each colony and add room name as label
          Object.entries(value).forEach(([roomName, colonyData]) => {
            extractRecursive(colonyData, `screeps_room`, {
              ...baseLabels,
              room: roomName,
            });
          });
        } else if (isResourceData(baseName, key, value)) {
          // Resource data - add resource as label
          // Use baseName_key as the metric name (e.g., screeps_room_assets)
          const metricName = `${baseName}_${key}`;

          // Check if this is sendCosts pattern (room -> amount) instead of (resource -> ...)
          const allKeysAreRooms = Object.keys(value).every((k) =>
            isRoomName(k),
          );

          if (allKeysAreRooms) {
            // sendCosts pattern: room -> amount
            Object.entries(value).forEach(([room, amount]) => {
              if (typeof amount === "number") {
                metrics.push({
                  metric: { __name__: metricName, ...baseLabels, room },
                  value: amount,
                  timestamp,
                });
              }
            });
          } else {
            // Standard resource pattern
            Object.entries(value).forEach(([resource, amount]) => {
              if (typeof amount === "number") {
                metrics.push({
                  metric: { __name__: metricName, ...baseLabels, resource },
                  value: amount,
                  timestamp,
                });
              } else if (typeof amount === "object" && amount !== null) {
                // Check if nested data contains room names (for incomingResources/outgoingResources pattern)
                const hasRoomKeys = Object.keys(amount).some((k) =>
                  isRoomName(k),
                );
                if (hasRoomKeys) {
                  // Resource -> Room -> Amount pattern
                  Object.entries(amount).forEach(([room, roomAmount]) => {
                    if (typeof roomAmount === "number") {
                      metrics.push({
                        metric: {
                          __name__: metricName,
                          ...baseLabels,
                          resource,
                          room,
                        },
                        value: roomAmount,
                        timestamp,
                      });
                    }
                  });
                } else {
                  // Handle other nested resource data (like trader.bought.resource.amount)
                  extractRecursive(amount, metricName, {
                    ...baseLabels,
                    resource,
                  });
                }
              }
            });
          }
        } else if (isRoomData(baseName, key)) {
          // Room-specific data - add room as label
          // This handles cases like terminalNetwork.incomingResources.E8N26
          extractRecursive(value, baseName, { ...baseLabels, room: key });
        } else if (isRoleData(baseName, key, value)) {
          // Creep role data - add role as label
          extractRecursive(value, baseName, { ...baseLabels, role: key });
        } else {
          // Check if this is a labeled data pattern (returns label name if true)
          const labelInfo = getLabeledDataPattern(baseName, key, value);
          if (labelInfo) {
            // Emit child values with the specified label
            // Use baseName_key as the metric name (e.g., screeps_colony_energyUsage)
            const metricName = `${baseName}_${key}`;
            Object.entries(value).forEach(([childKey, childValue]) => {
              if (typeof childValue === "number") {
                metrics.push({
                  metric: {
                    __name__: metricName,
                    ...baseLabels,
                    [labelInfo.labelName]: childKey,
                  },
                  value: childValue,
                  timestamp,
                });
              } else if (
                typeof childValue === "object" &&
                childValue !== null
              ) {
                // Handle nested labeled data
                extractRecursive(childValue, metricName, {
                  ...baseLabels,
                  [labelInfo.labelName]: childKey,
                });
              }
            });
          } else {
            // Regular nested object - continue with concatenated name
            extractRecursive(value, `${baseName}_${key}`, baseLabels);
          }
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
    return isRoomName(key);
  }

  function isRoomName(key) {
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

  // Generic function to detect patterns that should emit child keys as labels
  // Returns { labelName: "label_name" } if pattern matches, null otherwise
  function getLabeledDataPattern(baseName, key, value) {
    if (typeof value !== "object" || value === null) return null;

    // Don't apply to objects with special structure fields
    if (value.hasOwnProperty("current") || value.hasOwnProperty("needed")) {
      return null;
    }

    // Check if all values are either numbers or simple objects (no deep nesting)
    const allChildrenAreSimple = Object.values(value).every(
      (v) => typeof v === "number" || (typeof v === "object" && v !== null),
    );

    if (!allChildrenAreSimple) return null;

    // Pattern 0: If all keys are room names, use room label
    const allKeysAreRooms = Object.keys(value).every((k) => isRoomName(k));
    if (
      allKeysAreRooms &&
      Object.values(value).every((v) => typeof v === "number")
    ) {
      return { labelName: "room" };
    }

    // Pattern 1: energyUsage, cpuUsage, or any field ending with "Usage"
    if (key.endsWith("Usage") || key === "usage") {
      return { labelName: "type" };
    }

    // Pattern 2: CPU phase data
    if (baseName.includes("cpu_usage")) {
      return { labelName: "phase" };
    }

    // Pattern 3: Generic "states" or similar container objects
    // Add more patterns here as needed
    const labelPatterns = [
      { keyPattern: /^(states|phases|types)$/i, labelName: "type" },
      { keyPattern: /^(categories|groups)$/i, labelName: "category" },
    ];

    for (const pattern of labelPatterns) {
      if (pattern.keyPattern.test(key)) {
        return { labelName: pattern.labelName };
      }
    }

    return null;
  }

  function isPhaseData(baseName, key, value) {
    return baseName.includes("cpu_usage") && typeof value === "number";
  }

  // Start extraction from root
  extractRecursive(segmentData, "screeps", { shard });

  return metrics;
}

async function pushToVictoriaMetrics(metrics, logger = console) {
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

  logger.info("Sample lines being sent:");
  logger.info(lines.slice(0, 3).join("\n"));
  logger.info("...");

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
    console.log('- screeps_colony_rcl_level{shard="shardX",colony="E8N26"}');
    console.log(
      '- screeps_colony_assets{shard="shardX",colony="E6N28",resource="energy"}',
    );
    console.log('- screeps_cpu_used{shard="shardX"}');
    console.log('- screeps_trader_credits{shard="shardX"}');
    console.log(
      '- screeps_terminal_network_assets{shard="shardX",resource="energy"}',
    );
  } else {
    console.log("✗ Failed to push metrics");
  }
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = { extractMetrics, pushToVictoriaMetrics };

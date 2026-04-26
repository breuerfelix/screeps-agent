#!/usr/bin/env node

const { extractMetrics } = require("./ingest_segment");
const fs = require("fs");

// Load debug segment data
const segmentData = JSON.parse(
  fs.readFileSync("debug_segment.json", "utf8"),
).data;

// Extract metrics
const metrics = extractMetrics(segmentData, "shardX");

// Group metrics by unique metric name
const metricsByName = new Map();

metrics.forEach((m) => {
  const metricName = m.metric.__name__;
  if (!metricsByName.has(metricName)) {
    metricsByName.set(metricName, m);
  }
});

// Sort by metric name and display one example per metric
console.log("=== One Example Per Unique Metric ===");
const sortedMetrics = Array.from(metricsByName.entries()).sort((a, b) =>
  a[0].localeCompare(b[0]),
);

sortedMetrics.forEach(([metricName, metric]) => {
  const labels = Object.entries(metric.metric)
    .filter(([k]) => k !== "__name__")
    .map(([k, v]) => `${k}="${v}"`)
    .join(", ");
  console.log(`${metricName}{${labels}} = ${metric.value}`);
});

console.log(`\n=== Summary ===`);
console.log(`Unique metric names: ${metricsByName.size}`);
console.log(`Total metrics extracted: ${metrics.length}`);

#!/usr/bin/env node

require("dotenv").config();

const { fetchSegments } = require("./fetch_segments");
const { parseSegments } = require("./segment_parser");
const { extractMetrics, pushToVictoriaMetrics } = require("./ingest_segment");
const { getScreepsConfig } = require("./config");
const fs = require("fs").promises;

async function processShards(shards) {
  console.log("Starting data collection for shards:", shards.join(", "));

  let totalMetrics = 0;

  for (const shard of shards) {
    console.log(`\nProcessing ${shard}...`);

    const apiResponse = await fetchSegments(shard);
    console.log(
      `Fetched ${Object.keys(apiResponse.data || {}).length} segments`,
    );

    const segments = parseSegments(apiResponse);
    const nonEmptySegments = Object.values(segments).filter(
      (s) => s !== null,
    ).length;
    console.log(`Parsed ${nonEmptySegments} non-empty segments`);

    for (const [segmentId, segmentData] of Object.entries(segments)) {
      if (segmentData) {
        const metrics = extractMetrics(segmentData, shard);
        if (metrics.length > 0) {
          console.log(`Segment ${segmentId}: ${metrics.length} metrics`);
          await pushToVictoriaMetrics(metrics);
          totalMetrics += metrics.length;
        }
      }
    }
  }

  console.log(`\n✓ Completed! Total metrics ingested: ${totalMetrics}`);
}

async function main() {
  const { shards } = getScreepsConfig();

  console.log("Starting data collection for shards:", shards.join(", "));

  for (const shard of shards) {
    console.log(`\nProcessing ${shard}...`);

    const apiResponse = await fetchSegments(shard);
    console.log(
      `Fetched ${Object.keys(apiResponse.data || {}).length} segments`,
    );

    const segments = parseSegments(apiResponse);

    // Get first segment for debugging
    const firstSegmentId = Object.keys(segments)[0];
    const firstSegment = segments[firstSegmentId];

    if (firstSegment) {
      console.log(`Writing first segment (${firstSegmentId}) to debug file`);
      await fs.writeFile(
        "debug_segment.json",
        JSON.stringify(
          {
            segmentId: firstSegmentId,
            data: firstSegment,
          },
          null,
          2,
        ),
      );
      console.log("Debug file written to debug_segment.json");
    } else {
      console.log("No segments found to debug");
    }
  }
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = { processShards };

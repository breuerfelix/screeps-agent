#!/usr/bin/env node

const axios = require("axios");

function toTimestampNs(timestampMs = Date.now()) {
  return `${BigInt(timestampMs) * 1000000n}`;
}

function buildLokiPayload(entries) {
  const groupedStreams = new Map();

  for (const entry of entries) {
    const labels = { ...entry.labels };
    const key = JSON.stringify(
      Object.keys(labels)
        .sort()
        .map((name) => [name, labels[name]]),
    );

    if (!groupedStreams.has(key)) {
      groupedStreams.set(key, {
        stream: labels,
        values: [],
      });
    }

    groupedStreams.get(key).values.push([
      entry.timestampNs || toTimestampNs(),
      String(entry.line),
    ]);
  }

  return {
    streams: Array.from(groupedStreams.values()),
  };
}

async function pushLogsToLoki(entries, lokiUrl) {
  if (!lokiUrl || entries.length === 0) {
    return false;
  }

  const response = await axios.post(
    `${lokiUrl}/loki/api/v1/push`,
    buildLokiPayload(entries),
    {
      headers: {
        "Content-Type": "application/json",
      },
    },
  );

  return response.status >= 200 && response.status < 300;
}

module.exports = {
  buildLokiPayload,
  pushLogsToLoki,
  toTimestampNs,
};

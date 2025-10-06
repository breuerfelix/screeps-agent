#!/usr/bin/env node

function parseSegments(apiResponse) {
  const segments = {};

  apiResponse.data.forEach((segmentString, index) => {
    if (segmentString && segmentString.trim() !== "") {
      segments[index] = JSON.parse(segmentString);
    } else {
      segments[index] = null;
    }
  });

  return segments;
}

module.exports = { parseSegments };

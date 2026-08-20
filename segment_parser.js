#!/usr/bin/env node

function parseSegmentString(segmentString) {
  if (segmentString && segmentString.trim() !== "") {
    return JSON.parse(segmentString);
  }

  return null;
}

function parseSegments(apiResponse) {
  const payload =
    apiResponse && Object.prototype.hasOwnProperty.call(apiResponse, "data")
      ? apiResponse.data
      : apiResponse;

  if (Array.isArray(payload)) {
    return Object.fromEntries(
      payload.map((segmentString, index) => [
        index,
        parseSegmentString(segmentString),
      ]),
    );
  }

  if (typeof payload === "string") {
    return { 0: parseSegmentString(payload) };
  }

  if (payload && typeof payload === "object") {
    const entries = Object.entries(payload);
    const looksLikeSegmentMap = entries.every(
      ([segmentId, segmentString]) =>
        /^\d+$/.test(segmentId) &&
        (typeof segmentString === "string" || segmentString === null),
    );

    if (looksLikeSegmentMap) {
      return Object.fromEntries(
        entries.map(([segmentId, segmentString]) => [
          segmentId,
          parseSegmentString(segmentString),
        ]),
      );
    }

    return { 0: payload };
  }

  throw new TypeError("Unsupported Screeps memory-segment response shape");
}

module.exports = { parseSegments };

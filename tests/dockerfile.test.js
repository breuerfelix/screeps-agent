const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

test("Dockerfile copies runtime scripts into /app", () => {
  const dockerfile = fs.readFileSync(
    path.join(__dirname, "..", "Dockerfile"),
    "utf8",
  );

  assert.match(
    dockerfile,
    /^COPY\s+agent\.js\s+fetch_segments\.js\s+segment_parser\.js\s+ingest_segment\.js\s+one_shot\.js\s+config\.js\s+console_log_capture\.js\s+loki\.js\s+probe_console_logs\.js\s+\.\/$/m,
  );
});

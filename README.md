# Screeps Monitoring Agent

This Node.js agent fetches Screeps memory segments and pushes metrics to VictoriaMetrics for monitoring and visualization in Grafana.

## Features

- Fetches memory segments from configured Screeps shards
- Parses JSON data from memory segments and extracts metrics
- Pushes metrics to VictoriaMetrics in time-series format
- Streams Screeps console websocket messages into Loki when `LOKI_URL` is configured
- Labels console logs with `shard`, `server_host`, `username`, and `message_type`
- Runs continuously on a 2-minute schedule
- Ships as a Docker image for local and remote deployments
- Publishes container images to GHCR via GitHub Actions
- Supports env-configured Screeps targets via `SCREEPS_BASE_URL` and `SCREEPS_SHARDS`
- Keeps metrics labeled by `shard` only; console logs also carry `server_host` for cross-environment separation

## Published container image

This repository publishes images to:

`ghcr.io/breuerfelix/screeps-agent`

Tag strategy:

- Branch pushes: sanitized branch-name tags such as `main` or `ci-ghcr-publish`
- Every push: `sha-<full-git-sha>`
- Default branch only: `main` and `latest`
- Git tags like `v1.2.3`: `v1.2.3`

Examples:

```bash
docker pull ghcr.io/breuerfelix/screeps-agent:main
docker pull ghcr.io/breuerfelix/screeps-agent:sha-<full-git-sha>
```

The GitHub Actions workflow logs in with `GITHUB_TOKEN` and pushes to the package namespace that matches this repository.

## Deployment

Run one container from `ghcr.io/breuerfelix/screeps-agent:main` per Screeps world. The agent makes outbound connections to Screeps, VictoriaMetrics, and optionally Loki. It requires no inbound ports or persistent storage.

For a private image, configure your deployment environment to authenticate to GHCR with `read:packages` access before pulling.

### Agent environment variables

| Variable | Value |
| --- | --- |
| `SCREEPS_TOKEN` | API token issued by the target Screeps server. |
| `SCREEPS_BASE_URL` | Screeps base URL. Defaults to `https://screeps.com`. Set it to your server URL for a private world. |
| `SCREEPS_SHARDS` | Comma-separated shard names. Defaults to `shardSeason,shardX`. Set it to the shard names used by your private server. |
| `VICTORIA_METRICS_URL` | VictoriaMetrics base URL reachable from the agent. |
| `LOKI_URL` | Optional Loki base URL reachable from the agent. Set it to enable console log ingestion. |
| `TEST_MODE` | Set to `true` to collect metrics once and exit. Defaults to continuous operation. |

## Local development

Node.js 22.4.0 or newer is required. The websocket console capture path uses the built-in `WebSocket` client, which is only stable from Node 22.4.0 onward.

Set the agent environment variables in your shell or `.env` before starting Node.js. For a host-side run against the bundled monitoring services, use `http://localhost:8428` for VictoriaMetrics and `http://localhost:3100` for Loki.

```bash
npm ci
npm start
```

Single-run mode:

```bash
TEST_MODE=true npm start
```

Probe the websocket console path against the configured Screeps target:

```bash
npm run probe:console
```

On `screeps.com`, set `SCREEPS_SHARDS` to one active shard, for example `SCREEPS_SHARDS=shardX npm run probe:console`.

If `LOKI_URL` is set, the probe also pushes the captured console event into Loki so you can verify end-to-end ingestion.

Run tests:

```bash
npm test
```

Syntax check the main scripts:

```bash
node --check agent.js
node --check console_log_capture.js
node --check loki.js
node --check probe_console_logs.js
node --check fetch_segments.js
node --check one_shot.js
node --check ingest_segment.js
node --check segment_parser.js
```

## Local container build

```bash
docker build -t screeps-agent:dev .
```

## Local monitoring stack

The bundled `docker-compose.yml` runs the agent with Grafana, VictoriaMetrics, and Loki for local development. Copy `.env.example` to `.env`, replace `SCREEPS_TOKEN`, and adjust the Screeps settings for your world. The example endpoints use the bundled services. Set `SCREEPS_AGENT_IMAGE` in `.env` to override the image used by Compose.

```bash
cp .env.example .env
```

After editing `.env`, start the stack.

```bash
docker compose up -d
```

The monitoring services are available locally.

- Grafana on `http://localhost:3000`
- VictoriaMetrics on `http://localhost:8428`
- Loki on `http://localhost:3100`

Default Grafana credentials in the sample compose file:

- Username: `admin`
- Password: `jamo`

## Development notes

- The official Screeps season endpoint still uses `https://screeps.com/season/api/...` when the base URL is official and shard is `shardSeason`.
- All other targets, including private servers, use `<SCREEPS_BASE_URL>/api/...`.
- The agent accepts both an array of memory segment strings and the single JSON string returned by some private servers.
- Metrics remain distinguished by shard name only.
- Console logs sent to Loki use labels `{source="screeps_console", server_host="...", username="...", shard="...", message_type="log|result|error"}`.
- For single-shard private deployments, console events that omit `payload.shard` inherit the single configured `SCREEPS_SHARDS` value so Loki streams still remain shard-addressable.

## Security notes

- Do not commit real Screeps tokens to the repository.
- Keep deployment credentials in environment variables or secret stores.
- If you want anonymous pulls from GHCR, change the package visibility in GitHub from private to public after the first publish.
- If workflow pushes fail with package permission errors, verify repository Actions settings allow `GITHUB_TOKEN` read and write permissions.
